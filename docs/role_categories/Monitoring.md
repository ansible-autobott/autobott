# Security


> NOTICE: All the configuration items in this list only show the keys we consider you need to setup or decide upon.
> 
> For a full list of configuration options check the defaults.yaml in the role directory

### Monit

Monit is a lightweight monitoring service with self-healing capabilities 


_mandatory configuration:_

```
run_role_monit: True
```

_optional:_

```
monit:
  # configure an smpt server to use for sending the emails
  # if you have a local smtp, e.g. nullmailer you don't need to specify again.
  smtp:
    host: ""
    port: ""
    user: ""
    pass: ""
    
  # email addresses that will get notifications
  alert_targets: []
  
  checks:
    system: True        # main system alerts, cpu/disk/memory
    ssh: True           # monitor and restart sshd
    mariadb: False      # monitor and restart mariadb service
    caddy:              # monitor and restart caddy service
      enabled: False
      port: 80
  # ads extra external host checks, using http requets
  external_hosts:
      # name of the serivice, used for the file
    - name: docmost
      # the url needs to be able to resolve, e.g. for docmost.localhost, you need to add an entry to /etc/hosts
      url: https://docmost.localhost
      # optional, use if non-standard ports are used
      port: 8443
      # allow self signed certs
      selfsigned: true
      
```

