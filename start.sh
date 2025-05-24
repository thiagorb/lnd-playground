#!/usr/bin/env bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

main() {
    cd "$SCRIPT_DIR"

    export CONTAINER_UID=${CONTAINER_UID:-${SUDO_UID:-1000}}
    export CONTAINER_GID=${CONTAINER_GID:-${SUDO_GID:-1000}}

    run_task docker compose up --detach --build --force-recreate bitcoin lnd-alice lnd-bob lnd-charlie \
        && lncli_create_interaction_existing | run_task lncli_create_wallet lnd-alice \
        && lncli_create_interaction_new | run_task lncli_create_wallet lnd-bob \
        && lncli_create_interaction_new | run_task lncli_create_wallet lnd-charlie \
        && run_task wait_for docker compose exec bitcoin bitcoin-cli getrpcinfo \
        && run_task bitcoin_create_wallet \
        && run_task bitcoin_generate_blocks 101 \
        && run_task bitcoin_get_balance \
        && run_task wait_for lncli_connect_to_peer lnd-alice lnd-bob \
        && run_task wait_for lncli_connect_to_peer lnd-bob lnd-charlie \
        && run_task wait_for lncli_connect_to_peer lnd-alice lnd-charlie \
        && run_task bitcoin_send_funds lnd-alice \
        && run_task bitcoin_send_funds lnd-bob \
        && run_task bitcoin_send_funds lnd-charlie \
        && run_task bitcoin_generate_blocks 3 \
        && run_task lncli_create_channel lnd-alice lnd-bob \
        && run_task lncli_create_channel lnd-bob lnd-charlie \
        && run_task bitcoin_generate_blocks 7 \
        && run_task lncli_create_invoice lnd-charlie \
        && run_task lncli_pay_invoice lnd-alice "$(lncli_get_payment_request lnd-charlie)" \
        && run_task thunderhub_init \
        && echo 1>&2 "All tasks completed successfully!" \
        && echo 1>&2 "You can now access ThunderHub at http://localhost:3001" \ 
}

bitcoin_create_wallet() {
    docker compose exec bitcoin bitcoin-cli createwallet test false false
}

bitcoin_generate_blocks() {
    local blocks="$1"
    docker compose exec bitcoin bitcoin-cli -generate "$blocks"
}

bitcoin_get_balance() {
    docker compose exec bitcoin bitcoin-cli getbalance
}

lncli_connect_to_peer() {
    local node="$1"
    local peer="$2"
    local peer_pubkey=$(lncli_get_pubkey "$peer")

    docker compose exec "$node" lncli connect "$peer_pubkey@$peer:9735"
}

lncli_create_wallet() {
    local node="$1"
    script -f /dev/null -E never -q -c "docker compose exec $node lncli create"
}

bitcoin_send_funds() {
    local node="$1"
    local address=$(docker compose exec "$node" lncli newaddress np2wkh | jq -r '.address')

    docker compose exec bitcoin bitcoin-cli -named sendtoaddress address="$address" amount=0.5 fee_rate=25
}

lncli_get_pubkey() {
    local node="$1"
    docker compose exec "$node" lncli getinfo | jq -r '.identity_pubkey'
}

lncli_create_channel() {
    local node="$1"
    local peer="$2"
    local peer_pubkey=$(lncli_get_pubkey "$peer")

    docker compose exec "$node" lncli openchannel "$peer_pubkey" 500000
}

lncli_create_invoice() {
    local node="$1"
    docker compose exec "$node" lncli addinvoice 10000
}

lncli_get_payment_request() {
    local node="$1"
    docker compose exec "$node" lncli listinvoices | jq -r '[.invoices[] | select(.state == "OPEN") | .payment_request][0]'
}

lncli_pay_invoice() {
    local node="$1"
    local payment_request="$2"
    local decoded=$(docker compose exec -T "$node" lncli decodepayreq "$payment_request")
    local payee=$(jq -r '.destination' <<< "$decoded")
    local amount=$(jq -r '.num_satoshis' <<< "$decoded")

    while ! docker compose exec -T "$node" lncli queryroutes --dest "$payee" --amt "$amount" --fee_limit 100; do
        sleep 1
    done

    docker compose exec -T "$node" lncli payinvoice --force "$payment_request" --fee_limit 100
}

lncli_export_backup() {
    local node="$1"
    docker compose exec "$node" lncli exportchanbackup --all
}

lncli_import_backup() {
    local node="$1"
    local backup="$2"
    docker compose exec -T "$node" lncli restorechanbackup --multi_backup "$backup"
}

lncli_backup_files() {
    local node="$1"

    docker compose cp "$node":/home/lnd/.lnd -
}

lncli_start_with_files() {
    local node="$1"
    docker rm -f bitcoin-test-"$node"-from-files < /dev/null \
        && docker compose run -T --name bitcoin-test-"$node"-from-files --detach --entrypoint '' "$node" bash -c 'mkfifo wait && cat < wait && ./entrypoint.sh' < /dev/null \
        && cat | docker exec -i bitcoin-test-"$node"-from-files bash -c 'tar -xvf - && echo done > wait'
}

lncli_create_interaction_new() {
    local password="testtest"

    # Answer the prompt for the password
    echo "$password"

    # Answer the prompt for the password confirmation
    echo "$password"

    # Answer the prompt for cipher seed mnemonic
    echo 'n'

    # Answer the prompt for passphrase
    echo ''
}

lncli_create_interaction_existing() {
    local password="testtest"

    # Answer the prompt for the password
    echo "$password"

    # Answer the prompt for the password confirmation
    echo "$password"

    # Answer the prompt for cipher seed mnemonic
    echo 'y'

    # Answer the prompt for the cipher seed mnemonic
    echo able bubble draw garage kitchen yard flavor similar ozone spawn border cup swarm worry dash biology essay next cross gasp horn ranch act scrap

    # Answer the prompt for passphrase
    echo ''

    # Answer the prompt for optional address look-ahead
    echo ''
}

lncli_wait() {
    local node="$1"
    wait_for docker compose exec "$node" lncli getinfo
}

thunderhub_init() {
    docker compose up --detach --build --force-recreate thunderhub \
        && docker compose exec thunderhub mkdir -p /home/thunderhub/lnd-alice /home/thunderhub/lnd-bob /home/thunderhub/lnd-charlie \
        && docker_compose_copy lnd-alice /home/lnd/.lnd/tls.cert thunderhub /home/thunderhub/lnd-alice/tls.cert \
        && docker_compose_copy lnd-bob /home/lnd/.lnd/tls.cert thunderhub /home/thunderhub/lnd-bob/tls.cert \
        && docker_compose_copy lnd-charlie /home/lnd/.lnd/tls.cert thunderhub /home/thunderhub/lnd-charlie/tls.cert \
        && docker_compose_copy lnd-alice /home/lnd/.lnd/data/chain/bitcoin/regtest/admin.macaroon thunderhub /home/thunderhub/lnd-alice/admin.macaroon \
        && docker_compose_copy lnd-bob /home/lnd/.lnd/data/chain/bitcoin/regtest/admin.macaroon thunderhub /home/thunderhub/lnd-bob/admin.macaroon \
        && docker_compose_copy lnd-charlie /home/lnd/.lnd/data/chain/bitcoin/regtest/admin.macaroon thunderhub /home/thunderhub/lnd-charlie/admin.macaroon \
        && wait_for curl -s http://localhost:3001/login
}

docker_compose_copy() {
    local source="$1"
    local source_file="$2"
    local target="$3"
    local target_file="$4"

    docker compose exec -T "$source" cat "$source_file" | docker compose exec -T "$target" tee "$target_file" >/dev/null
}

wait_for() {
    local start=$(now)

    while ! "$@"; do
        sleep 1

        if [ $(($(now) - $start)) -gt 60000 ]; then
            echo 1>&2 "Timeout waiting for $*"
            return 1
        fi
    done
}

run_task() {
    local start_time=$(now)

    echo 1>&2 -n "Running task: $*... "

    output=$("$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo 1>&2 "failed!"
        echo 1>&2 "$output"
        return 1
    fi

    local end_time=$(now)
    echo 1>&2 "finished in $(($end_time - $start_time)) ms"
}

now() {
    echo $(( ${EPOCHREALTIME/[^0-9]/} / 1000 ))
}

# only run the main function if this script is not sourced
return 2>/dev/null || main
