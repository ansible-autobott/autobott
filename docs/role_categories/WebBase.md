# Web based services


> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
>
> For a full list of configuration options check the defaults.yaml in the role directory


### PHP-FPM

Simple PHP-FPM role that installs and configures the PHP FastCGI Process Manager.  
Includes defaults for system user/group, runtime settings, and OPcache configuration.

_mandatory configuration:_

```yaml
run_role_php_fpm: true
```

note: many of the php internals can be tweaked, but the default should work well.


### Caddy

Simple Caddy role that installs and configures the Caddy web server and reverse proxy.

_mandatory configuration:_

```yaml
run_role_caddy: true
```
_optional:_
```
caddy:
  # email used for ACME account registration
  email: "email@example.com"

  # enable Prometheus metrics
  metrics: true
```

### Authelia

Simple Authelia role that installs and configures the Authelia authentication server with support for 2FA, user management, and access control policies.

_mandatory configuration:_

```yaml
run_role_authelia: true
authelia:  
  secrets:
    # must be longer than 20 characters
    storage_encryption_key: "ff10bfa787976e1f8eb6e0686edd34e457b7d9f6765ff10bfa787976e1f8eb6e0686edd34e457b7d9f6765"
    
  # protected site configurations
  sites:
    - name: fe26
      domain: "fe26.localhost"
      auth_url: "https://auth.fe26.localhost:8443"
      policy: "two_factor" # one_factor | two_factor
      groups:
        - team1

  # user definitions
  users:
    - username: alice
      displayname: "Alice Example"
      password: "changeme"
      salt: "BuMcDk78nYRxSvUXLIKeHZ" # exactly 22 chars
      email: "alice@example.com"
      groups:
        - team1
        - tema2
      disabled: false

    - username: tom
      displayname: "Tom Example"
      password: "changeme"
      salt: "BuMcDk78nYRxSvUXLIKeHZ" # exactly 22 chars
      email: "tom@example.com"
      groups:
        - team1
        - tema2
      disabled: true

```
_optional:_
```
authelia:
  # Enable Authelia metrics
  service:
    metrics: false
  # issuer for TOTP tokens
  totp_issuer: "Authelia"

```