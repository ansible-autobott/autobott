# Security


> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
> 
> For a full list of configuration options check the defaults.yaml in the role directory


### Lynis audit

Lynis autid (https://cisofy.com/lynis/) will run the audit and generate a report on your host machine.
you can chek it on ./reports/lynis_audit

_mandatory configuration:_

```
run_role_lynis: true
```


### Firewall

Block inbound and outbound traffic, the rules are setup on an allowlist basis, so that we only 
allow what explicitly is needed.

Note: that a minimum required is configured as fallback (can be overwritten at own risk):
* Inbound SSH on 22
* Outbound 53 (DNS), HTTP(S) on 80 and 443

_mandatory configuration:_

```
run_role_firewall: true
```

_optional:_

```
firewall:
  
  # allowed inbound tcp ports
  allow_inbound_tcp:
    - 80    # HTTP
    - 443   # HTTPS
    
  # allowed inbound udp ports
  allow_inbound_udp: 
    - 55555 # wireguards

  allowed_outbound_tcp: []

  allowed_outbound_udp: 
    - 6100:6200 # e.g. transmission
```
