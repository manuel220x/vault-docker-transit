#!/usr/bin/dumb-init /bin/sh
# Based on official hashicorp's entrypoint
set -e

# Prevent core dumps
ulimit -c 0


# VAULT_CONFIG_DIR isn't exposed as a volume but you can compose additional
# config files in there if you use this image as a base, or use
# VAULT_LOCAL_CONFIG below.
VAULT_CONFIG_DIR=/vault/config

# Look for Vault subcommands.
if [ "$1" = 'server' ]; then
    shift
    set -- vault server \
        -config="$VAULT_CONFIG_DIR"
elif [ "$1" = 'version' ]; then
    # This needs a special case because there's no help output.
    set -- vault "$1"
elif vault --help "$1" 2>&1 | grep -q "vault $1"; then
    # We can't use the return code to check for the existence of a subcommand, so
    # we have to use grep to look for a pattern in the help output.
    set -- vault "$1"
fi
# Generat Cert

if [ ! -f /vault/certs/cert.pem ]; then
openssl req -x509 -newkey rsa:2048 -keyout /vault/certs/key.pem \
    -out /vault/certs/cert.pem -days 365 -nodes \
    -subj "/C=US/ST=California/L=San Jose/O=DoU/OU=DevOps/CN=localhost" \
    -addext "subjectAltName = DNS:vaulttransit"
chown vault:vault /vault/certs/cert.pem
chown vault:vault /vault/certs/key.pem
fi

# If we are running Vault, make sure it executes as the proper user.
if [ "$1" = 'vault' ]; then
    # If the config dir is bind mounted then chown it
    if [ "$(stat -c %u /vault/config)" != "$(id -u vault)" ]; then
        chown -R vault:vault /vault/config || echo "Could not chown /vault/config (may not have appropriate permissions)"
    fi

    # If the logs dir is bind mounted then chown it
    if [ "$(stat -c %u /vault/logs)" != "$(id -u vault)" ]; then
        chown -R vault:vault /vault/logs
    fi

    # If the file dir is bind mounted then chown it
    if [ "$(stat -c %u /vault/file)" != "$(id -u vault)" ]; then
        chown -R vault:vault /vault/file
    fi

    if [ -z "$SKIP_SETCAP" ]; then
        # Allow mlock to avoid swapping Vault memory to disk
        setcap cap_ipc_lock=+ep $(readlink -f $(which vault))

        # In the case vault has been started in a container without IPC_LOCK privileges
        if ! vault -version 1>/dev/null 2>/dev/null; then
            >&2 echo "Couldn't start vault with IPC_LOCK. Disabling IPC_LOCK, please use --privileged or --cap-add IPC_LOCK"
            setcap cap_ipc_lock=-ep $(readlink -f $(which vault))
        fi
    fi
    if [ "$(id -u)" = '0' ]; then
        set -- su-exec vault "$@"
    fi
fi

exec "$@"
