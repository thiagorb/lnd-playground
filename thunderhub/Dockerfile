FROM apotdevin/thunderhub:v0.13.31

ARG CONTAINER_UID
ARG CONTAINER_GID

RUN deluser node \
    && addgroup --gid "$CONTAINER_GID" thunderhub \
    && adduser --disabled-password --ingroup thunderhub --uid "$CONTAINER_UID" thunderhub \
    && install -d -o thunderhub -g thunderhub /home/thunderhub/.cache \
    && ln -s /home/thunderhub/.cache /app/src/client/.next/cache

COPY --chown=thunderhub:thunderhub ./thunderhub.yml /home/thunderhub/thunderhub.yml

ENV ACCOUNT_CONFIG_PATH=/home/thunderhub/thunderhub.yml

USER thunderhub