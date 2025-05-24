FROM lightninglabs/lnd:v0.18.4-beta AS lnd-official

FROM debian:bookworm-slim AS lnd

COPY --from=lnd-official /bin/lnd /bin/lnd
COPY --from=lnd-official /bin/lncli /bin/lncli

ARG CONTAINER_GID
ARG CONTAINER_UID
RUN addgroup --gid "$CONTAINER_GID" lnd \
    && adduser --disabled-password --ingroup lnd --uid "$CONTAINER_UID" lnd \
    && printf '#!/usr/bin/env bash\n\n/bin/lncli -n "${LNCLI_NETWORK:-regtest}" "$@"' > /usr/local/bin/lncli \
    && chmod +x /usr/local/bin/lncli \
    && install -d -o lnd -g lnd /home/lnd/.lnd

COPY --chown=lnd:lnd ./lnd.conf.template /home/lnd/lnd.conf.template
COPY --chown=lnd:lnd ./entrypoint.sh /home/lnd/entrypoint.sh

ENTRYPOINT ["/home/lnd/entrypoint.sh"]
CMD ["lnd"]

USER lnd
WORKDIR /home/lnd