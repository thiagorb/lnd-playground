ARG BITCOIN_VERSION=28.1

FROM bitcoin/bitcoin:${BITCOIN_VERSION} as bitcoin-official

FROM debian:bookworm-slim as bitcoin

ARG BITCOIN_VERSION
COPY --from=bitcoin-official /opt/bitcoin-${BITCOIN_VERSION} /opt/bitcoin
ENV PATH=/opt/bitcoin/bin:$PATH

ARG CONTAINER_UID
ARG CONTAINER_GID
RUN addgroup --gid "$CONTAINER_GID" bitcoin \
    && adduser --disabled-password --ingroup bitcoin --uid "$CONTAINER_UID" bitcoin

COPY --chown=bitcoin:bitcoin ./bitcoin.conf /home/bitcoin/.bitcoin/bitcoin.conf

CMD bitcoind

USER bitcoin
RUN mkdir -p /home/bitcoin/.bitcoin
WORKDIR /home/bitcoin
