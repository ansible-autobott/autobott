# K3s Server Role — Architecture & Decisions

## Overview

Single-node k3s server that keeps the k3s defaults, except where this document says otherwise: Calico replaces
Flannel as the CNI, the host firewall is always on, the admin kubeconfig is readable only by root, and Ansible
deploys apps through a robot account that is admin only inside each app's namespace.

## Traffic Flow

```
Client → node :80 / :443 (ServiceLB) → Traefik → ClusterIP Services → Pods
```

## Architecture Decisions

### Ingress: the k3s defaults (Traefik + ServiceLB)

- **Traefik** is the ingress controller k3s installs from its bundled Helm chart; this role does not override it.
  Its `LoadBalancer` Service has two entrypoints: `web` on port 80 (HTTP) and `websecure` on port 443 (HTTPS).
- **HTTPS** uses Traefik's self-signed default certificate unless an Ingress references a TLS secret. There is no
  HTTP → HTTPS redirect by default.
- **ServiceLB** (formerly Klipper LB) is the load balancer built into k3s. For every `LoadBalancer` Service it
  runs `svclb-*` pods that take the Service ports as hostPorts on the node, and the node IP becomes the Service's
  external IP. Traefik is one such Service; any other `LoadBalancer` Service is published on the node the same way.
- hostPorts are iptables redirects, not listening sockets: a host process already listening on the same port does
  not make k3s fail, the redirect silently takes its traffic. So before installing anything, the role lists the
  host's listening TCP ports and fails if a program uses one of `k3s.servicelb_ports` (80/443 by default; add the
  ports of any other `LoadBalancer` Service). It checks the host, not other roles' settings, so it catches any
  program. k3s itself never listens on these ports, so re-runs pass.

### Calico CNI

- Replaces the default Flannel.
- Provides NetworkPolicy support to restrict pod-to-pod traffic, e.g. only Traefik may reach an app's pods (see the
  sample content).
- Flannel backend is set to `none` and default network policy is disabled in k3s config to let Calico handle everything.

### Applications: ClusterIP Services behind an Ingress

- Web apps use a ClusterIP Service and an Ingress; Traefik routes requests by hostname/path. No NodePort or
  hostPort on application pods.
- Multiple replicas work naturally since there's no hostPort conflict on application pods.

### Firewall (UFW) is always on

- The k3s role imports `security/firewall` with `run_role_firewall: true`, so enabling k3s turns the firewall on
  even if the host does not enable it. The API (`6443`), kubelet (`10250`) and Calico BGP (`179`) are not
  reachable from outside: the firewall rejects all inbound traffic except the allowed ports.
- **Not filtered:** ports that k3s publishes with iptables redirects (ServiceLB's 80/443, NodePorts) are reachable
  from outside whatever the firewall allows. kube-proxy rewrites them to a pod address on arrival (`KUBE-SERVICES`
  in `nat PREROUTING`) and accepts them in `KUBE-FORWARD`, which runs before UFW's forward chains; they never reach
  UFW's inbound allowlist. Restricting them takes Kubernetes-side tools, not UFW: `loadBalancerSourceRanges` on a
  `LoadBalancer` Service, or Calico host endpoint policies (`preDNAT`) for NodePorts.
- k3s registers its rules as a drop-in file (`/etc/ufw/autobott.d/k3s.json`). The firewall role applies every
  drop-in, so the rules survive the UFW reset it does whenever its own config changes.
- Rules (found by running without them and reading the UFW block log):
  - **host → pods** (`allow out to <cluster_cidr>`): the firewall rejects outgoing traffic by default, which
    breaks kubelet probes and API server → pod calls (metrics-server, webhooks).
  - **pods → anywhere** (`route allow from <cluster_cidr>`): on hosts that also run Docker, the ufw-docker rules
    drop forwarded traffic to private addresses, which includes pod → pod (e.g. CoreDNS) and CoreDNS → a private
    upstream resolver.
- Not needed: pods → host (e.g. the API) is accepted by Calico before UFW sees it
  (`FELIX_DEFAULTENDPOINTTOHOSTACTION=ACCEPT`), and service IPs are already rewritten to pod IPs when UFW checks
  the packet.
- **Limit:** Calico accepts forwarded pod traffic at the end of the `FORWARD` chain, so the firewall's outbound
  port allowlist does not apply to pods — pods can reach any port on the internet. Restricting pod egress needs
  Calico network policies.

### Sample content (landing page)

- `k3s.sample_content: true` deploys a sample app that shows the stack working: nginx in the
  `autobott-sample` namespace serving a static page from the ConfigMap `sample-content`, behind a
  ClusterIP Service and an Ingress.
- The Ingress has no host and Traefik router priority `1`, so it answers every request that no other
  Ingress matches — it is the landing page for the main domain until something else claims it, and no
  domain needs to be configured.
- It follows the rules above: ClusterIP only, a NetworkPolicy that lets only Traefik reach the pod, Pod
  Security `restricted` on the namespace, non-root nginx (`nginxinc/nginx-unprivileged`) with a read-only
  root filesystem and no ServiceAccount token.
- Deployed through the k3s manifests dir (`sample-content.yaml`). k3s does not delete resources when a
  manifest file is removed, so setting the flag back to `false` deletes the file, its `AddOn` and the
  namespace.

### Admin kubeconfig is root-only (break-glass)

- `write-kubeconfig-mode: 0600`: only root can read `/etc/rancher/k3s/k3s.yaml`, the full-admin credential. On a
  single node, cluster admin is the same as root (a pod can mount `/`), so it takes the same two steps as root:
  SSH key + sudo password. `ssh` + `sudo kubectl` on the node is the break-glass path; root's `kubectl` finds the
  file without `KUBECONFIG`.
- Earlier versions of this role let a `k3s-admin` group read the file, which skipped sudo. The role now deletes
  that group and `/etc/profile.d/k3s.sh`, and resets the file to `root:root`: k3s keeps the owner and group of an
  existing kubeconfig when it rewrites it on start.

### App deployment: the deployer robot account

Ansible never deploys apps with the admin kubeconfig:

- **Root builds the rooms and hands out keys** (`tasks/namespace.yaml`, admin kubeconfig): creates the app's
  namespace, binds the robot account `autobott-system/autobott-deployer` to the ClusterRole `admin` *in that
  namespace only*, and mints a 1h token for it (`kubectl create token`), kept in memory only.
- **The robot works inside the rooms it was given:** the app role switches to the unprivileged Linux user
  `kubeops` (system user, no password, no SSH keys, no sudo, `nologin`) and deploys with the token. `kubeops`
  verifies the API server with the public copy of the server CA, `/etc/rancher/k3s/server-ca.crt`.
- The role creates the robot account itself: namespace `autobott-system` (Pod Security `restricted`) and the
  ServiceAccount, synchronously with `kubernetes.core.k8s`. Not through the manifests dir: k3s applies that in the
  background, so the first app role could run before the account exists.
- Packages: `python3-kubernetes` for the `kubernetes.core` modules (Debian 13+: bookworm's 22.6 is older than the
  required 24.2, so the role fails early there) and `acl`, which Ansible needs to switch from its login user to
  another unprivileged user.

Usage in an app role (the `namespace.yaml` header has the inputs):

```yaml
- name: Bootstrap the k3s namespace and mint a deployer token
  ansible.builtin.import_role:
    name: k3s
    tasks_from: namespace.yaml
  vars:
    k3s_namespace: whoami

- name: Deploy as kubeops
  become_user: kubeops
  module_defaults:
    group/kubernetes.core.k8s:          # add the same under group/kubernetes.core.helm for charts
      host: https://127.0.0.1:6443
      ca_cert: /etc/rancher/k3s/server-ca.crt
      api_key: "{{ k3s_deployer_token.stdout }}"
  block:
    - name: App resources
      kubernetes.core.k8s:
        namespace: whoami
        template: whoami.yaml.j2
        wait: true
```

What keeps the robot from being root on the node (namespace admin alone would be):

1. Only per-namespace RoleBindings, never a cluster-wide one. It cannot create or relabel namespaces, so it cannot
   switch one to `privileged`.
2. App namespaces enforce Pod Security `baseline` (or `restricted`): no privileged pods, `hostPath` volumes, host
   network/PID. `namespace.yaml` refuses `privileged`, and refuses system namespaces (`default`, `kube-*`,
   `autobott-system`, `autobott-users`), where namespace admin would mean cluster admin.
3. It cannot create k3s `HelmChart` resources (k3s's helm-controller installs them with full admin): the `admin`
   ClusterRole does not include `helm.cattle.io`. Charts go through the `kubernetes.core.helm` modules as
   `kubeops` instead.
4. Host data (e.g. media on ZFS) goes through PersistentVolumes created by root; the app only claims them.
5. Pods in app namespaces get no API token unless they ask for one: `namespace.yaml` sets
   `automountServiceAccountToken: false` on the namespace's `default` ServiceAccount.

Why it is built this way:

- The token goes in `module_defaults`, not `environment:`: Ansible puts environment variables on the
  `sudo … sh -c` command line, readable by any local user with `ps`. `kubernetes.core` marks `api_key` as
  `no_log`, and the mint task is `no_log`.
- No kubeconfig file for `kubeops`, so no live token on disk.
- A fresh token per app role, so a long playbook run never hits an expired one.
- Revoke: delete the ServiceAccount (all its tokens stop working); otherwise they expire after 1h.
- **Limit:** the Ansible user can still sudo to root, so this protects against buggy roles and tools running as
  root, not against a compromised Ansible controller.

## Network Security Summary

| Layer | What it protects |
|-------|-----------------|
| UFW (always on) | API, kubelet and BGP not reachable from outside |
| Traefik Ingress rules | Routes only matching hostname/path, not a generic proxy |
| Calico NetworkPolicies | Pod-to-pod isolation, e.g. only Traefik reaches app pods |
| ClusterIP services | No ports bound on the host for application pods |
| Admin kubeconfig 0600 (root) | Full cluster admin takes SSH key + sudo, like root |
| Deployer robot + Pod Security | Ansible's app work is limited to each app's namespace, no host access |

## Configuration Reference

| File | Purpose |
|------|---------|
| `defaults/main.yaml` | Role variables: CIDRs, DNS, Calico version, app namespace Pod Security level |
| `tasks/namespace.yaml` | Shared by app roles: app namespace, robot access to it, 1h deployer token |
| `templates/config.yaml.j2` | k3s server config |
| `templates/k3s.service.j2` | systemd unit |
| `files/calico-*.yaml` | Calico CNI manifest |
| `templates/sample-content.yaml.j2` | Sample landing page manifest (`sample_content`) |
| `templates/sample-index.html.j2` | Sample landing page HTML (goes into the ConfigMap) |
