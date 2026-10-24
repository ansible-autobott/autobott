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
- Keep it that way: do not add the host's public name to `k3s.tls_san` or open `6443`. People are meant to reach
  the API through an SSH tunnel or WireGuard (planned, see the end of this document).
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
- **Side effect on the host's own traffic:** outgoing traffic is rejected except DNS, HTTP and HTTPS
  (`firewall_required`), also on hosts that never enabled the firewall themselves. Host services that use other
  ports stop working until the host's `firewall` settings allow them, e.g. `allowed_outbound_tcp: [587]` for
  nullmailer (SMTP submission) and `allowed_outbound_udp: [123]` for NTP.

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

### Upgrades (`k3s.version`)

- Changing `k3s.version` downloads that release's binary, points the `/usr/local/bin/k3s` link at it and restarts
  k3s. The server runs from its own unpacked copy under `/var/lib/rancher/k3s/data/`, so without the restart the old
  version would keep running until the next reboot. Pods keep running while k3s restarts; the API is down briefly.
- The role compares `k3s.version` with the version the server runs (`kubectl version`), not with the link: if a run
  fails after switching the link but before the restart, the next run still restarts k3s.
- One minor version at a time: Kubernetes does not support skipping a minor version, and going back a minor version
  needs a restore of a datastore backup taken on it ([k3s docs](https://docs.k3s.io/upgrades/roll-back)). The role
  fails before changing anything when `k3s.version` would do either: add a release of each minor version in between
  to `k3s_checksums` and run the role once per step.
- Version, config and unit changes restart k3s right after the unit task, not at the end of the play, so the
  manifests and the robot account are applied to the server that runs the new setup.

### Access model

Acting on the cluster takes the same two steps as admin work on the server: a key that gets you onto the box (SSH,
or a VPN), then a second secret you know. The API is never reachable from the internet, and there is no external
identity provider.

| Who | Credential | Can do | Status |
|-----|------------|--------|--------|
| Admin (break-glass) | `ssh` + `sudo kubectl` on the node | everything | implemented |
| Ansible app roles | 1h token of the deployer robot, used as `kubeops` | `admin` inside each app's namespace | implemented |
| People, daily work | 8h `<user>-dev` token, minted with a GPG-locked master pass | `edit` in their listed app namespaces | planned |
| People, admin work | 1h `<user>-admin` token, minted over `ssh` + `sudo` | everything | planned |

**Limit:** on a single node, root on the box is full control of the cluster. The model keeps attackers off the box
and makes sure a leaked credential is not automatically full cluster control. The planned rows are described in
"Planned (not implemented): API access for people" at the end.

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

### What the API server accepts

1. **Certificates signed by k3s's client CA:** the root-only admin kubeconfig and k3s's own components.
2. **ServiceAccount tokens:** the deployer robot's (1h), and the token Kubernetes gives each pod that mounts one
   (off by default in app namespaces).
3. **Proxy certificates** (request-header CA, used for metrics-server): a trusted proxy can act as any user.
4. **The k3s join token**, on the same port (`6443`): lets a machine join the cluster, and a machine that joins as
   a server receives every CA key. On a single node nothing should ever join.
5. **Bootstrap tokens** (`--enable-bootstrap-token-auth=true`): Secrets of type `bootstrap.kubernetes.io/token` in
   `kube-system` that `k3s token create` makes for joining agents. None exist unless someone creates one
   (`k3s token list`).

Requests without credentials are rejected (`--anonymous-auth=false`); there are no passwords, static token files
or OIDC. `journalctl -u k3s | grep 'Running kube-apiserver'` shows the flags. Every signing key and the join token
(`server/token`) live in root-only files under `/var/lib/rancher/k3s/server/`: protect a backup of that directory
like root.

## Network Security Summary

| Layer | What it protects |
|-------|-----------------|
| UFW (always on) | API, kubelet and BGP not reachable from outside |
| Traefik Ingress rules | Routes only matching hostname/path, not a generic proxy |
| Calico NetworkPolicies | Pod-to-pod isolation, e.g. only Traefik reaches app pods |
| ClusterIP services | No ports bound on the host for application pods |
| Admin kubeconfig 0600 (root) | Full cluster admin takes SSH key + sudo, like root |
| Deployer robot + Pod Security | Ansible's app work is limited to each app's namespace, no host access |

## Checks on the vagrant VM

Last run 2026-10-18 on `make vagrant-up VER=13-k3s`, with a throwaway app deployed through `namespace.yaml` as
`kubeops` (a second playbook run changed nothing):

- `/etc/rancher/k3s/k3s.yaml` is `root:root 0600` after a k3s restart; `kubeops` is locked, `nologin`, no sudo.
- The deployer token lives 1h (`exp - iat = 3600`) and never appears in the Ansible output.
- With the firewall on, pods still reach the API: `https://kubernetes.default.svc` answers `401`.
- `kubectl auth can-i … --as=system:serviceaccount:autobott-system:autobott-deployer`:
  - `--list -n <app>`: the namespace `admin` set, including `serviceaccounts/token` inside the namespace;
  - `no` for `create helmcharts.helm.cattle.io -n <app>`, tokens in `autobott-system`, anything in `kube-system`,
    `patch namespaces`, `create clusterrolebindings` and pods in `autobott-sample`.
- Refused when tried with a real deployer token: creating a namespace, relabelling the app's namespace to
  `privileged`, a `HelmChart`, a pod mounting `hostPath: /`, a privileged `hostPID` pod, a RoleBinding to
  `cluster-admin`, reading `kube-system` Secrets.
- No bootstrap tokens exist (`k3s token list`).

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

## Planned (not implemented): API access for people

Today people only have the break-glass path. This is the design for daily work from a workstation; none of it is in
the role yet.

### Reaching the API

The network step is the first of the two layers (tunnel, WireGuard or both is still open):

- **SSH tunnel:** `ssh -L 16443:127.0.0.1:6443 <host>`, then `https://127.0.0.1:16443` (`127.0.0.1` is already in
  the API server certificate). Blocked today: `base/linux-basic` sets `AllowTcpForwarding no` for everyone, so it
  needs a scoped exception, e.g. `Match User <user>` with `AllowTcpForwarding local` and
  `PermitOpen 127.0.0.1:6443` (forwarding to the API port only).
- **WireGuard:** enable `base-services/wireguard`, add the host's WireGuard address to `k3s.tls_san`, and add an
  inbound `6443/tcp` rule on `wg0` to the k3s firewall drop-in (drop-in rules take `interface`).

### Logging in

| Token | Minted with | Can do | Lifetime |
|-------|-------------|--------|----------|
| master pass (`<user>-minter`) | root (Ansible or by hand), encrypted to the user's GPG key | only mint `<user>-dev` tokens | 90 days |
| `<user>-dev` | the master pass, via `kube-login` | `edit` in the user's listed app namespaces | 8h |
| `<user>-admin` | `ssh` + `sudo`, via `kube-login-admin` | everything (`cluster-admin`) | 1h |

- **Daily:** `kube-login` decrypts the master pass with GPG (passphrase prompt, cached by gpg-agent for the day)
  and mints the day's `<user>-dev` token. **Admin:** `kube-login-admin` mints a `<user>-admin` token through
  `ssh` + `sudo`, so the server checks the sudo password. It reads the password locally and passes it to
  `sudo -S`: prompting through `ssh -t` mixes the prompt text into the captured token.
- **Server side (this role):** namespace `autobott-users` with the ServiceAccounts `<user>-minter`, `<user>-dev`
  and `<user>-admin`. `<user>-dev` gets a RoleBinding to `edit` in each listed app namespace (added by the
  namespace bootstrap), `<user>-admin` a ClusterRoleBinding to `cluster-admin`. The master pass can do one thing;
  naming only `<user>-dev` also stops it from minting tokens for itself or for `<user>-admin`:

  ```yaml
  rules:
    - apiGroups: [""]
      resources: [serviceaccounts/token]
      resourceNames: [<user>-dev]
      verbs: [create]
  ```

- **Workstation side (`tools/dev-k8s`):** `gnupg`, `pinentry-qt` and `kubectl`; gpg-agent forgets the passphrase
  8h after last use and after 12h at most (`default-cache-ttl 28800`, `max-cache-ttl 43200`; forget it now with
  `gpgconf --kill gpg-agent`); the encrypted master pass under `~/.kube/`; a kubeconfig with the cluster CA and a
  daily and an admin context; the two shell functions.
- **Creating the master pass:** preferably Ansible mints it on the node and encrypts it there to the user's GPG
  public key (needs `gnupg` on the node), so only the encrypted file leaves the server. By hand, capture it the way
  `kube-login-admin` does (password to `sudo -S`, no `ssh -t`). Do not mint one on every run (see revocation below).

Caveats:

- Permissions limit power, not lifetime: the master pass can request any duration. A server-wide maximum
  (`--service-account-max-token-expiration`) would also cut the 90-day master pass.
- A token cannot be revoked on its own: deleting its ServiceAccount revokes all of them. A token minted bound to a
  Secret (`kubectl create token --bound-object-kind=Secret --bound-object-name=…`) dies with that Secret (checked
  on vagrant: refused about 10s after the Secret is deleted). One throwaway Secret per master pass revokes just that
  pass, and the Secret's age tells Ansible when a renewal is due.
- Anyone who can start pods in a namespace can run them as any ServiceAccount there, so no ServiceAccount in
  `<user>-dev`'s namespaces may be stronger than `<user>-dev`. Keep `<user>-dev` out of `kube-system`,
  `autobott-system` and `autobott-users` (there it could act as `<user>-admin`).
- `edit`, not `admin`: `admin` can hand out permissions inside the namespace. `edit` can still read the namespace's
  Secrets; use `view` where that is too much.
- Stolen workstation: the thief can try to guess the passphrase offline, so use a long one, or later a YubiKey
  (same commands; the PIN locks after 3 wrong tries). Malware running while the passphrase is cached can mint
  `<user>-dev` tokens, not admin ones.

Already checked on vagrant: k3s sets no maximum token lifetime (a 90-day token is accepted), and the bound-Secret
revocation above. To check once built: the master pass can mint `<user>-dev` tokens and nothing else
(`kubectl auth can-i create serviceaccounts/<name> --subresource=token`), `<user>-dev` can do nothing in
`autobott-users` or `kube-system`, and `kube-login` / `kube-login-admin` work end to end.

Open questions:

- Tunnel, WireGuard, or both?
- Should `<user>-dev` also get read-only `view` across the cluster (`view` cannot read Secrets)?
- Master pass renewal: how Ansible knows one is due (the bound Secret's age) and how the encrypted file reaches the
  workstation (e.g. through the inventory into `tools/dev-k8s`).
- Inventory layout for users, e.g. a `k3s.users` list with `name`, `gpg_public_key` and `dev_namespaces`.
- Where `tools/dev-k8s` installs the shell functions.

Not chosen:

- `ssh` + `sudo` for every token: kept for admin tokens only; daily work should not need SSH.
- A long-lived GPG-locked credential with full power: 90 days of cluster admin on a workstation.
- Self-signed JWTs (`--authentication-config`): needs a Caddy vhost for the public keys and a custom plugin. Can be
  added later next to the above: the API server accepts several login methods.
- OIDC through Authelia: needs `kubelogin`, and logins would depend on Authelia. Can also be added later.
- An offline root CA with intermediates (an earlier plan): heavy, and no help against root on the box.
- A static token file, a token webhook or auth proxy, an extra ServiceAccount signing key.
