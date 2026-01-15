#!/bin/bash
VAULT_VERSION=1.3.0
curl -sLo /tmp/vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip /tmp/vault.zip -d /usr/local/bin
echo 'Now run: export PATH="/usr/local/bin:$PATH"'
