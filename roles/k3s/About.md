# K3s Server Role — Architecture & Decisions

## Overview

Single-node k3s server that keeps the k3s defaults, except where this document says otherwise: Calico replaces
Flannel as the CNI, the host firewall is always on, and the admin kubeconfig is readable only by root. The role
installs and maintains the cluster; deploying apps is the job of a separate repo, autobott-k8s, which gets the admin
kubeconfig and sets up its own access with it (see "Handoff to deploy tools").

## Traffic Flow

```
Client → node :80 / :443 (ServiceLB) → Traefik → ClusterIP Services → Pods
```

## Architecture Decisions

### Ingress: the k3s defaults (Traefik + ServiceLB)

- **Traefik** is the ingress controller k3s installs from its bundled Helm chart; the only setting this role can
  override is the optional HTTP → HTTPS redirect (below). Its `LoadBalancer` Service has two entrypoints: `web`
  on port 80 (HTTP) and `websecure` on port 443 (HTTPS).
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

### HTTP → HTTPS redirect (`https_redirect`)

- `k3s.https_redirect: true` makes Traefik answer every request on port 80 with a permanent redirect to the same
  URL on HTTPS (port 443), for the whole cluster. It is set in the `traefik` HelmChartConfig
  (`traefik-config.yaml` in the k3s manifests dir), which k3s merges into the values of its Traefik chart
  (`ports.web.redirections.entryPoint`, which needs Traefik chart 34+: k3s 1.32.3 ships 34.2, 1.35.1 ships 38.0).
- Cluster-wide, not per app: apps need no redirect of their own. An app deployed with namespace `admin` rights (as
  autobott-k8s deploys them) could not ship one anyway: it would need a Traefik `Middleware`, which `admin` cannot
  create (Traefik's chart does not add its resources to the `admin` ClusterRole, `rbac.aggregateTo: []`).
- Off by default: until the sites have real certificates (Let's Encrypt), HTTPS serves Traefik's self-signed
  certificate, so the redirect would send every visitor to a browser warning. Browsers also cache a permanent
  redirect, so turning it off later does not reach visitors who already got it.
- The redirect always points to port 443: keep it off where clients reach HTTPS on another port. The vagrant VM
  forwards 443 to 8446, so `http://<app>.k3s.localhost:8083/` would redirect to an address that does not answer.
- The file is always deployed, with empty values (`{}`) when the redirect is off: k3s does not delete resources
  when their manifest file is removed, so deleting the file would leave the redirect on. Earlier versions of this
  role deployed an empty `traefik-config.yaml`; the same file name replaces it, so two files never manage the same
  object. Other Traefik chart overrides belong in this file too: a chart takes a single HelmChartConfig.

### Calico CNI

- Replaces the default Flannel.
- Provides NetworkPolicy support to restrict pod-to-pod traffic, e.g. only Traefik may reach an app's pods.
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
  manifests are applied to the server that runs the new setup.

### Access model

Acting on the cluster takes the same two steps as admin work on the server: a key that gets you onto the box (SSH,
or a VPN), then a second secret you know. The API is never reachable from the internet, and there is no external
identity provider.

| Who | Credential | Can do | Status |
|-----|------------|--------|--------|
| Admin (break-glass) | `ssh` + `sudo kubectl` on the node | everything | implemented |
| Deploy tools (autobott-k8s) | the admin kubeconfig, as root on the node | everything; autobott-k8s sets up its own least-privilege deploy account with it | implemented |
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
- Other clients (k9s, helm) only look at `KUBECONFIG` or `~/.kube/config`. Interactive root shells (`sudo su`,
  `sudo -i`) export `KUBECONFIG` from `/root/.bashrc.d/10_k3s.bashrc`, which the root `.bashrc` of `base/enroll`
  loads (`autobott_enroll.root_bashrc`, on by default). There is deliberately no `/root/.kube/config`: Ansible
  never reads `.bashrc`, so a `kubernetes.core` task that runs as root without explicit credentials fails instead
  of silently getting cluster admin.

### Handoff to deploy tools (autobott-k8s)

This role installs and maintains the cluster. Deploying apps is the job of autobott-k8s (separate repo,
`../autobott-k8s`), and how it logs in is its own business. All a deploy tool gets from this role:

- **The admin kubeconfig** `/etc/rancher/k3s/k3s.yaml`, root-only, with the API address (`https://127.0.0.1:6443`)
  and the API server's CA in it. autobott-k8s uses it as root to set up its own access (a deploy user, a robot
  account that is admin only inside each app's namespace, a copy of the CA) and to create app namespaces, never to
  deploy apps: see its `roles/k8s/About.md`.
- **kubectl** at `/usr/local/bin/kubectl` (the k3s symlink).
- **The API only from the node:** the firewall keeps `6443` closed (see "Firewall" above), so deploy tools run on
  the node.
- **Ingress:** Traefik with its CRDs, IngressClass `traefik`, on ports 80/443 through ServiceLB, with the optional
  cluster-wide HTTPS redirect.
- **NetworkPolicy**, enforced by Calico, and **Pod Security admission** (built into Kubernetes) for namespaces that
  set a level.
- **No `HelmChart` for namespace admins:** k3s's helm-controller installs `HelmChart` resources with full admin, and
  the `admin` ClusterRole does not include `helm.cattle.io`, so a namespace admin cannot use it. autobott-k8s
  checks this before it hands out a token.
- **After `k3s-reset.sh`** the cluster has a new CA and is empty: run the deploy tool again (autobott-k8s reads the
  new CA and creates its account again).
- Earlier versions of this role also set up the deploy side (the robot account, `kubeops`, a CA copy at
  `/etc/rancher/k3s/server-ca.crt`) and a sample page (namespace `autobott-sample`). autobott-k8s took over the
  account and the user; the role deletes the CA copy and the sample page.

### What the API server accepts

1. **Certificates signed by k3s's client CA:** the root-only admin kubeconfig and k3s's own components.
2. **ServiceAccount tokens:** e.g. the 1h tokens of autobott-k8s's deployer robot, and the token Kubernetes gives each
   pod that mounts one.
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
| Pod Security admission | Namespaces that enforce `baseline` or `restricted` get no privileged pods or host access (autobott-k8s's app namespaces do) |

## Checks on the vagrant VM

Last run 2026-10-18 on `make vagrant-up VER=13-k3s` (a second playbook run changed nothing). The checks of the
deployer robot moved to autobott-k8s's `roles/k8s/About.md`, with the robot.

- `/etc/rancher/k3s/k3s.yaml` is `root:root 0600` after a k3s restart.
- With the firewall on, pods still reach the API: `https://kubernetes.default.svc` answers `401`.
- A ServiceAccount bound to `admin` in a namespace gets `no` for `kubectl auth can-i create helmcharts.helm.cattle.io`
  there.
- No bootstrap tokens exist (`k3s token list`).

## Configuration Reference

| File | Purpose |
|------|---------|
| `defaults/main.yaml` | Role variables: version, CIDRs, DNS, Calico version, ServiceLB ports, HTTPS redirect |
| `templates/config.yaml.j2` | k3s server config |
| `templates/k3s.service.j2` | systemd unit |
| `files/calico-*.yaml` | Calico CNI manifest |
| `templates/traefik-config.yaml.j2` | Traefik chart overrides (HelmChartConfig): HTTP → HTTPS redirect (`https_redirect`) |

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
  and `<user>-admin`. `<user>-dev` gets a RoleBinding to `edit` in each listed app namespace (added by
  autobott-k8s, which owns the app namespaces: who works where is its part), `<user>-admin` a ClusterRoleBinding to
  `cluster-admin`. The master pass can do one thing;
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
- Inventory layout for users, e.g. a `k3s.users` list with `name` and `gpg_public_key` here, and each user's app
  namespaces in autobott-k8s's settings.
- Where `tools/dev-k8s` installs the shell functions.

Not chosen:

- `ssh` + `sudo` for every token: kept for admin tokens only; daily work should not need SSH.
- A long-lived GPG-locked credential with full power: 90 days of cluster admin on a workstation.
- Self-signed JWTs (`--authentication-config`): needs a Caddy vhost for the public keys and a custom plugin. Can be
  added later next to the above: the API server accepts several login methods.
- OIDC through Authelia: needs `kubelogin`, and logins would depend on Authelia. Can also be added later.
- An offline root CA with intermediates (an earlier plan): heavy, and no help against root on the box.
- A static token file, a token webhook or auth proxy, an extra ServiceAccount signing key.
