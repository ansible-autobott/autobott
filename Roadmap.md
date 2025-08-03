# Roadmap

This is just a simple list of ideas and tasks to do on autobott

## missing roles to migrate
* base/linux-hardware 
* desktop kde
* linux-desktop

## possible future services

* base/postgres
* base/se-linux
* vaultwarden
* gonic / airsonic music server
* excalidraw some type of selfhosted with server storage
* OliveTin
* SMART web ui => https://github.com/AnalogJ/scrutiny

# Braindump

* explore on setting up monit to lert if systemd services are in a failed state
* add a mechanism to prevent running old version
    * store the version on the server
    * autobot will check the version and only run if it is a supported one, e.g. v3 allows to update from v2 but not v1

* validation role:
    * ensure all servarr ports are not publicly available
* grafana
    * add a graph for zfs l2arc cache hit ratio
    * Smart data for disks

* verify docmost backup/restore
* make homepage files templated so that we can add secrets using ansible managed secrets

