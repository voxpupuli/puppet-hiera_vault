# hiera_vault: a vault data provider function (backend) for Hiera 5

### Description

This is a back end function for Hiera 5 that allows lookup to be sourced from Hashicorp's Vault or its open-source fork OpenBao.

[Vault](https://developer.hashicorp.com/vault) and [OpenBao](https://openbao.org/) secure, store, and tightly control access to tokens, passwords, certificates, API keys, and other secrets in modern computing. Vault/OpenBao handle leasing, key revocation, key rolling, and auditing. Vault/OpenBao present a unified API to access multiple backends: HSMs, AWS IAM, SQL databases, raw key/value, and more.

For an example repo of it in action, check out the [hashicorp/webinar-vault-hiera-puppet](https://github.com/hashicorp/webinar-vault-hiera-puppet) repo and webinar ['How to Use HashiCorp Vault with Hiera 5 for Secret Management with Puppet'](https://www.hashicorp.com/resources/hashicorp-vault-with-puppet-hiera-5-for-secret-management)

### Compatibility

- This module is only compatible with Puppet 7.0.0 and newer, Hiera 5 (ships with Puppet 4.9+) and Vault KV engine version 2 (Vault 0.10+)

### Requirements

The `vault` and `debouncer` gems must be installed and loadable from Puppet

```
# /opt/puppetlabs/puppet/bin/gem install --user-install vault
# /opt/puppetlabs/puppet/bin/gem install --user-install debouncer
# puppetserver gem install vault
# puppetserver gem install debouncer
```

### Installation

The data provider is available by installing the `petems/hiera_vault` module into your environment:

This will avaliable on the forge, and installable with the module command:

```
# puppet module install petems/hiera_vault
```

You can also download the module directly:

```shell
git clone https://github.com/voxpupuli/puppet-hiera_vault /etc/puppetlabs/code/environments/production/modules/hiera_vault
```

Or add it to your Puppetfile

```ruby
mod 'hiera_vault',
  :git => 'https://github.com/voxpupuli/puppet-hiera_vault'
```

### Hiera Configuration

See [The official Puppet documentation](https://www.puppet.com/docs/puppet/7/hiera_intro) for more details on configuring Hiera 5.

The following is an example Hiera 5 hiera.yaml configuration for use with hiera-vault

```yaml
---
version: 5

hierarchy:
  - name: "Hiera-vault lookup"
    lookup_key: hiera_vault
    options:
      confine_to_keys:
        - "^vault_.*"
        - "^.*_password$"
        - "^password.*"
      ssl_verify: false
      address: https://vault.foobar.com:8200
      token: <insert-your-vault-token-here>
      default_field: value
      mounts:
        some_secret:
          - %{::trusted.certname}
          - common
        another_secret:
          - %{::trusted.certname}
          - common
```

The following Hiera 5 options must be set for each level of the hierarchy.

| Option       | Description
|--------------|---
| `name`       | A human readable name for the lookup
| `lookup_key` | This option must be set to `hiera_vault`

The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

| Parameter                | Description
|--------------------------|------------
| `address`                | The address of the Vault server or Vault Agent, also read as `ENV["VAULT_ADDR"]`. Note: Not currently compatible with unix domain sockets - you must use `http://` or `https://`
| `token`                  | The token to authenticate with Vault, also read as `ENV["VAULT_TOKEN"]` or a full path to the file with the token (eg. `/etc/vault_token.txt`). When bootstrapping, you can set this token as `IGNORE-VAULT` and the backend will be stubbed, which can be useful when bootstrapping.
| `cache_for`              | How long to cache a given key in seconds. If not present the response will never be cached.
| `confine_to_keys`        | Only use this backend if the key matches one of the regexes in the array, to avoid constantly reaching out to Vault for every parameter lookup
| `continue_if_not_found`  | Allow hiera to look beyond vault if the value is not found (default: `false`)
| `strip_from_keys`        | Patterns to strip from keys before lookup
| `default_field`          | The default field within data to return. If not present, the lookup will be the full contents of the secret data.
| `default_field_behavior` | setting to `ignore` or undefined will **always** return the value of the `default_field`-named key from the object retrieved from Vault, even if other keys exist. If set to `only`, it **returns a single string if there's one and only one field named after `default_field` in Vault**, otherwise it returns a Hash of all found keys and values.
| `default_field_parse`    | setting to `string` or undefined will parse the default field as string, `json` will parse it as JSON data
| `mounts`                 | The list of mounts you want to do lookups against. This is treated as the backend hiearchy for lookup. It is recomended you use [Trusted Facts](https://puppet.com/docs/puppet/5.3/lang_facts_and_builtin_vars.html#trusted-facts) within the hierachy to ensure lookups are restricted to the correct hierachy points. See [Mounts](#mounts).
| `ssl_verify`             | Specify whether to verify SSL certificates (default: `true`)
| `ssl_pem_file`           | [vault-ruby's client](https://github.com/hashicorp/vault-ruby) configuration of the TLS PEM file
| `ssl_ca_cert`            | [vault-ruby's client](https://github.com/hashicorp/vault-ruby) configuration of the certificate authority
| `ssl_ca_path`            | [vault-ruby's client](https://github.com/hashicorp/vault-ruby) CA path
| `ssl_ciphers`            | [vault-ruby's client](https://github.com/hashicorp/vault-ruby) configuration of TLS ciphers
| `strict_mode`            | When enabled, the lookup function fails in case of http errors when looking up a secret.
| `v1_lookup`              | whether to lookup within kv v1 hierarchy (default: `true`) - disable if you only use kv v2 :) See [Less lookups](#less-lookups).
| `v2_guess_mount`         | whether to try to guess mount for KV v2 (default: `true`) - add `data` after your mount and disable this option to minimize amount of misses. See [Less lookups](#less-lookups).

#### Example use of `confine_to_keys`

```yaml
confine_to_keys:
  - "application.*"
  - "apache::.*"
```

#### Example use of `strip_from_keys`
```yaml
strip_from_keys:
  - "vault:"
```

#### Example use of `default_field_behavior` set to `only`

`hiera.yaml` for Vault KV2, without guess mounting. Default value named `value`.

```yaml
# (...)
hierarchy:
- lookup_key: hiera_vault
  name: Search for hiera data in Vault
  options:
    v2_guess_mount: false
    v1_lookup: false
    confine_to_keys:
    - ^vault_.*
    default_field: value
    default_field_behavior: only
    ssl_verify: false
    # Token is loaded from the environment variable
    address: https://vault.foobar.com:8200
    mounts:
      secrets/data:
      - puppet/common
      - certificates
    ssl_verify: false
    strip_from_keys:
    - ^vault_
version: 5
# (...)
```

Now, assuming Vault contains two objects:
- http://vault.foobar.com:8200/secrets/data/puppet/common/simple_string with keys
  - `value` (e.g. a simple string value)
- http://vault.foobar.com:8200/secrets/data/certificates/certificate_domain.net with keys
  - `tls.crt` (e.g. the public part of a x509 certifiate)
  - `tls.key` (e.g. the certifiate private key)
  - `value` (any arbitrary string)

Then in the hiera data file for the role, e.g. `default.yaml`, we add the following three lookups.
The data of the object with a single key named `value` are returned as a string.
The multi-key object is returned as a Hash, and all fields, including `value`, must be accessed by explicitly using the key.
Note that the certificate lookups also demonstrate access to the object keys requiring escaping because of the dots.

```yaml
profile::vault_test::simple_string: "%{lookup('vault_simple_string')}"
profile::vault_test::certificate_public: "%{lookup('\"vault_certificate_domain.net\".\"tls.crt\"')}"
profile::vault_test::certificate_private: "%{lookup('\"vault_certificate_domain.net\".\"tls.key\"')}"
profile::vault_test::certificate_default_value: "%{lookup('\"vault_certificate_domain.net\".value')}"
```

### Debugging

```
puppet lookup vault_notify --explain --compile --node=node1.vm
Searching for "vault_notify"
  Global Data Provider (hiera configuration version 3)
    Using configuration "/etc/puppetlabs/code/hiera.yaml"
    Hierarchy entry "yaml"
      Path "/etc/puppetlabs/code/environments/production/hieradata/node1.yaml"
        Original path: "%{::hostname}"
        No such key: "vault_notify"
      Path "/etc/puppetlabs/code/environments/production/hieradata/common.yaml"
        Original path: "common"
        Path not found
  Environment Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/code/environments/production/hiera.yaml"
    Hierarchy entry "Hiera-vault lookup"
      Found key: "vault_notify" value: "hello123"
```

### Vault Configuration

#### Mounts

It is recomended to have a specific mount for your Puppet secrets, to avoid conflicts with an existing secrets backend.

From the command line:

```
vault secrets enable -version=2 -path=some_secret kv
```

We will then configure this in our hiera config:

```yaml
mounts:
  some_secret:
    - %{::trusted.certname}
    - common
```

Then when a hiera call is made with lookup on a machine with the certname of `foo.example.com`:

```
$cool_key = lookup({"name" => "cool_key", "default_value" => "No Vault Secret Found"})
```

Secrets will then be looked up with the following paths:

- http://vault.foobar.com:8200/some_secret/foo.example.com/cool_key (for v1)
- http://vault.foobar.com:8200/some_secret/foo.example.com/data/cool_key (for v2)
- http://vault.foobar.com:8200/some_secret/data/foo.example.com/cool_key (for v2)
- http://vault.foobar.com:8200/some_secret/common/cool_key (for v1)
- http://vault.foobar.com:8200/some_secret/common/data/cool_key (for v2)
- http://vault.foobar.com:8200/some_secret/data/common/cool_key (for v2)

#### Less lookups

It is possible to use `cache_for` to indicate how long to cache a given key to lessen the number of requests sent to Vault.

You can use `v1_lookup` and `v2_guess_mount` to minimize misses in above lookups.

Changing above configuration to

```yaml
v2_guess_mount: false
v1_lookup: false
mounts:
  some_secret/data:
    - %{::trusted.certname}
    - common
```

would result in following lookups:

- http://vault.foobar.com:8200/some_secret/data/foo.example.com/cool_key (for v2)
- http://vault.foobar.com:8200/some_secret/data/common/cool_key (for v2)

#### Multiple keys in trusted certname

Often you want to whitelist multiple paths for each host (e.g. due to host having multiple roles). In this case simply add keys delimited with comma to trusted field. For example:

```yaml
mounts:
  secret:
    - "%{trusted.extensions.pp_role}"
```

and host configured with

```yaml
---
extension_requests:
  pp_role: api,ssl
```

would result in lookups in:

- http://vault.foobar.com:8200/secret/api/cool_key (for v1)
- http://vault.foobar.com:8200/secret/api/data/cool_key (for v2)
- http://vault.foobar.com:8200/secret/data/api/cool_key (for v2)
- http://vault.foobar.com:8200/secret/ssl/cool_key (for v1)
- http://vault.foobar.com:8200/secret/ssl/data/cool_key (for v2)
- http://vault.foobar.com:8200/secret/data/ssl/cool_key (for v2)

#### More verbose paths in Hiera

Often implicit path extension makes it hard to understand which exact paths are used for given host - as you need to inspect both Hiera and trusted field for each host.

With above configuration and lookup `$cool_key = lookup({"name" => "cool_key"})` you cannot be sure whether `api/cool_key` or `ssl/cool_key` will be used (whichever happens to be first in lookup list).

To alleviate this problem you can use full paths in Hiera, provided `v2_guess_mount: false` configuration is active. For example with:

```yaml
v2_guess_mount: false
v1_lookup: false
mounts:
  secret/data:
    - "%{trusted.extensions.pp_role}"
```

You can use `$cool_key = lookup({"name" => "ssl/cool_key"})` to ensure `http://vault.foobar.com:8200/secret/data/ssl/cool_key` will be used.

And make yourself a favor and avoid `lookup` directly ;) Use

```yaml
profile::ssl_role::key: "%{alias('vault_storage::ssl/params.key')}"
```

to inject value from `key` inside `http://vault.foobar.com:8200/secret/data/ssl/params`.

### Author

- Original - David Alden <dave@alden.name>
- Transfered and maintained by Peter Souter
