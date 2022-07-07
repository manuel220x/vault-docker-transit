## Overview

Simple compose file that prepares a vault server that can be use to auto-unseal other vaults


## Usage

Just clone the repo, cd into the folder and run:

```
docker compose build

docker compose up -d

# Wait a few seconds

docker compose logs -f initializer

```

Now depending on the use case you need to grab the cert and token shown in the output and use them accordingly. Some examples


#### 1. Locally for validation purposes
```
export VAULT_ADDR=https://127.0.0.1:8201
export VAULT_CACERT=/tmp/vault/certs/cert.pem
export VAULT_TOKEN=s.b4b90sp0PNd4rssXvbFFK08j  #This was taken from the output of the initializer

vault write transit/encrypt/defaultautounseal plaintext=$(base64 <<< "my secret data")
```

#### 2. To initialize another vault running in the host

Add the below seal section to your vault config:
```
seal "transit" {
  address            = "https://127.0.0.1:8201"
  disable_renewal    = "false"
  key_name           = "defaultautounseal"
  mount_path         = "transit/"
  tls_ca_cert        = "/tmp/vault/certs/cert.pem"
  tls_skip_verify    = "false"
  
}
```


## More Details

This is what happens behind the scenes:

1. Spin up a container `vaulttransit` with vault
    - Creates self signed cert and enables TLS
    - Exposes `8201` port
    - mounts `/tmp/vault/certs` folder from host to store certs
2. Spin a container called `initializer` that will initialize and prepare vault to be used by other vault servers to auto-unseal.
    - Initializes vault with just 1 key share
    - Token and Unseal Key are saved to: `/vault/certs/token` and `/vault/certs/key` respectively
    - Enables transit engine (default mount path `transit/`)
    - Creates transit key: `defaultautounseal`
    - Creates a policy that can only encrypt and decrypt data using the ge key above
    - Creates a token with the policy
    - Prints the content of the Cert to stdout (you can check it with `docker logs initializer`)
    - Prints the token to stdout (you can check it with `docker logs initializer`)
    - saves the generated tokens into file `/vault/transit_tokens` inside the container

## How to get details required to connect to this server

The VAULT_ADDR can be:

1. From the host:
 - `https://127.0.0.1:8201`
 - `https://localhost:8201`
2. From another container on the same network:
 - `https://vaulttransit:8200`

Then, the cert and token can be retrieved with any of these options:

> Option 1: Self signed cert can be found under `/tmp/vault/certs` on the host or from the output of the container named `initializer`

> Option 2: Self signed cert and token can be found by looking at the output of the initializer container `docker logs initializer`