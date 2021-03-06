#!/usr/bin/dumb-init /bin/sh
# Based on official hashicorp's entrypoint
set -e
#vault-docker-transit_vaulttransit_1


#vaulttransit


#VAULT_ADDR=https://vaulttransit:8200
#VAULT_CACERT=/vault/certs/cert.pem

echo "Waiting.."
sleep 10
echo "Starting.."

initialized=`vault status -format=json | jq '.initialized'`
sealed=`vault status -format=json | jq '.sealed'`


if [ "$initialized" = "false" ]; then
    echo "Initializing"
    initstatus=`vault operator init -key-shares=1 -key-threshold=1 -format=json`
    vault operator init -status
    if [ $? -ne 0 ]; then
        echo "Error Initializing"
        exit -1
    fi
    echo $initstatus | jq '.root_token' -r > /vault/certs/token
    echo $initstatus | jq '.unseal_keys_b64[0]' -r > /vault/certs/key
    chmod 600 /vault/certs/token
    chmod 600 /vault/certs/key
    initialized=`vault status -format=json | jq '.initialized'`
fi

if [ "$initialized" = "true" ] && [ "$sealed" = "true" ]; then
    key=`cat /vault/certs/key`
    vault operator unseal -format=json $key
    sealed=`vault status -format=json | jq '.sealed'`
    if [ "$sealed" = "true" ]; then
        echo "Unseal Failed"
        exit -1
    fi
fi


if [ "$initialized" = "true" ] && [ "$sealed" = "false" ]; then
    export VAULT_TOKEN=`cat /vault/certs/token`
    has_transit=`vault secrets list -format=json | jq '."transit/"'`
    if [ "$has_transit" = "null" ]; then
        echo "Enabling Transit Engine"
        vault secrets enable transit
        vault write -f transit/keys/defaultautounseal
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Transit Engine Already Enabled!"
    fi
    has_default=`vault list -format=json transit/keys | jq '.[] |  select(. =="defaultautounseal")' | wc -l`
    if [ $has_default = 0 ]; then
        echo "Creating Default Key"
        vault write -f transit/keys/defaultautounseal
    else
        echo "Default Key already exist!"
    fi

    has_policy=`vault policy list | grep defaultautounseal | wc -l`
    if [ $has_policy = 0 ]; then
        echo "Creating Policy"
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Polocy Already created!"
    fi

fi