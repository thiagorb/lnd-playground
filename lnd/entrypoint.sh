#!/usr/bin/env bash

perl < /home/lnd/lnd.conf.template > /home/lnd/.lnd/lnd.conf -pe '
    s|\$LND_TLS_EXTRA_DOMAIN|$ENV{LND_TLS_EXTRA_DOMAIN}|g;
    s|\$LND_ALIAS|$ENV{LND_ALIAS}|g;
'

lnd