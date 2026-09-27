# k3s Security Model — Working Doc

> **Status:** planning, not implemented. Updated 2026-09-27 (replaces the 2026-08-31 CA-based plan).
> Delete or fold into `roles/k3s/About.md` + `../docs` once implemented.
> **Scope:** access to the single-node k3s cluster on `neptuno.rivervps.com`.

---

## Goal

Kubernetes access follows the same two layers as server admin today:

1. **SSH key** (or VPN key) gets you to the box.
2. **A second secret you know** is needed before you can act on the cluster.

The Kubernetes API is never reachable from the public internet. No external identity provider.

**Honest limit:** on a single node, root on the box = full control of the cluster. This model keeps
attackers off the box and makes sure a leaked *credential* is not automatically full cluster control.

---

## Build order

0. Rebase `k3s` on `main` (25 commits behind; `main` has `desktop/dev-k8s`, this branch still has
   `desktop/dev-apps/kubectl`).
1. Admin key root-only (section 1).
2. API not public (section 2).
3. Ansible automation (section 3).
4. Human login (section 4).

---

## 1. Admin key is root-only (break-glass)

**Why:** today the `k3s-admin` group lets an SSH key alone read the full-admin key — sudo is skipped.
Full cluster admin on a single node is the same as root (a pod can mount `/`).

**Break-glass:** `ssh` + `sudo kubectl` on the node — the same two layers as server admin, and the
recovery path if anything below breaks.

Changes in `roles/k3s`:
- `templates/config.yaml.j2`: `write-kubeconfig-mode: "0600"` (was `0640`).
- `templates/k3s.service.j2`: remove `ExecStartPost=/bin/chgrp k3s-admin …`.
- `tasks/main.yaml`: remove the "Create k3s-admin group", "Add users to k3s-admin group" and
  "Set KUBECONFIG for all users via profile.d" tasks (root's `kubectl` finds the file by default).
- On hosts that already ran the old role (neptuno): remove `/etc/profile.d/k3s.sh` and the `k3s-admin`
  group (`state: absent`) — deleting the tasks alone leaves them behind.
- `defaults/main.yaml`: remove `admins`.
- `About.md`: replace the "kubeconfig access control" section, the "kubeconfig 0640 + k3s-admin" table row
  and the "admin users" / "kubeconfig group fix" file-list entries.

Changes in `autobott-inventory/host_vars/neptuno.rivervps.com/k3s.yaml`:
- Remove `admins: [odo]` and its comments (group, `/etc/profile.d/k3s.sh`).
- Fix the path in the header comment: `roles/k3s/server/About.md` → `roles/k3s/About.md`.

---

## 2. API not public

**Current state on neptuno:** the firewall role is **not enabled** (`run_role_firewall` is unset →
default `false`), so if k3s is running there, the API (`6443`) and kubelet (`10250`) are reachable from
the internet today.

- Enable `run_role_firewall` for neptuno. Its default-deny (allows `22`, `80`, `443`) blocks `6443` and
  `10250` from outside.
- Remove the commented `tls_san: neptuno.rivervps.com` suggestion ("permit 6443/tcp") from neptuno's
  `k3s.yaml` — it would put the API on the public internet.
- Humans reach the API through (see open questions):
  - **SSH port forward:** `ssh -L 16443:127.0.0.1:6443 neptuno` — no config change (127.0.0.1 is already
    in k3s's certificate), and/or
  - **WireGuard:** enable the wireguard role for neptuno; add its wg0 address (role default
    `192.168.20.1`) to `k3s.tls_san`; the firewall role only takes port lists → needs a new
    interface-scoped allow (`wg0` → `6443`).
- This network step counts as the **first layer** for human login.

---

## 3. Ansible automation

**In plain words**

- Ansible logs in with its SSH key and uses the sudo password to become root (as today).
- As root, it asks Kubernetes for a **temporary pass (1 hour)** for a **robot account** and keeps it in
  memory only.
- It then switches to an unprivileged Linux user, `kubeops`, and does all work *inside the app's space*
  (namespace) with that pass.
- **Setup work runs as root with the admin key:** installing k3s, creating the robot account, creating
  each app's namespace and giving the robot permission for it. The robot is deliberately not allowed to
  do these, otherwise it could give itself access to everything.
- **Rule of thumb:** root builds the rooms and hands out keys; the robot only works inside the rooms it
  was given.

**Once, in `roles/k3s` (root)**
- Install `acl` — Ansible needs it to switch from one unprivileged user to another (no base role
  installs it today).
- Install the Python `kubernetes` client (≥ 24.2): Debian 13 package `python3-kubernetes` is 30.1 (ok);
  Debian 12's 22.6 is too old.
- Linux user `kubeops`: system user, `nologin` shell, home `/var/lib/kubeops`, no password, no SSH keys,
  not in sudoers.
- Namespace `autobott-system` + ServiceAccount `autobott-deployer`, created with `kubernetes.core.k8s`
  (synchronous) — **not** the manifests dir (applied later in the background → the first app role could
  run before they exist).
- Copy `/var/lib/rancher/k3s/server/tls/server-ca.crt` → `/etc/rancher/k3s/server-ca.crt` (`0644`,
  public certificate).

**Per app: shared task file `roles/k3s/tasks/namespace.yaml` (root, admin kubeconfig)**
- Namespace with label `pod-security.kubernetes.io/enforce: baseline`.
- RoleBinding: ServiceAccount `autobott-system/autobott-deployer` → ClusterRole `admin`, in that namespace.
- RoleBindings for the human `<user>-dev` accounts allowed in this namespace (section 4).
- Mint the pass:
  ```yaml
  - name: Mint short-lived deployer token
    ansible.builtin.command: >-
      /usr/local/bin/k3s kubectl create token autobott-deployer
      -n autobott-system --duration=1h
    register: k3s_deployer_token
    changed_when: false
    no_log: true
  ```

**App role usage**
```yaml
- name: Bootstrap namespace and mint token
  ansible.builtin.include_role:
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

**Rules that make "not root" real** (otherwise namespace admin = root on the node)
1. The robot only gets per-namespace RoleBindings — never a cluster-wide binding.
2. App namespaces enforce Pod Security `baseline` (blocks privileged pods, `hostPath`, host network/PID).
3. The robot cannot create or edit namespaces (it could relabel one to `privileged`).
4. Host data (e.g. media on ZFS) goes through PersistentVolumes created by root; the app only claims them.
5. The robot must not be able to create k3s `HelmChart` resources (k3s's helm-controller installs them
   with full admin). Use the `helm` modules as `kubeops` instead.

**Why it is built this way**
- The token goes in `module_defaults`, not `environment:` — Ansible puts environment variables on the
  `sudo … sh -c` command line, readable by any local user via `ps`. The collection marks `api_key` as
  `no_log`.
- No kubeconfig file for `kubeops` → no live token on disk.
- A fresh token per app role → a long playbook run never hits an expired pass.
- Revoke: delete the ServiceAccount (all its tokens stop working); otherwise they expire after 1h.

**Limit:** the Ansible user can still sudo to root, so this protects against buggy roles and tools
running as root — not against a compromised Ansible controller.

---

## 4. Human login

**In plain words**

- **Layer 1:** SSH port forward or WireGuard gets the laptop to the API (section 2).
- **Daily work:** a **master pass**, locked with your GPG key on the laptop, can do exactly one thing:
  create **8-hour passes for a limited account** (`<user>-dev`, can edit apps in its listed namespaces
  only). `kube-login` asks for the GPG passphrase (KDE popup, remembered for the day) and creates the
  day's pass.
- **Admin work:** full-power passes (`<user>-admin`, 1 hour) can only be created through `ssh` + `sudo`
  — the sudo password is checked by the server.
- **Break-glass:** `ssh` + `sudo kubectl` on the node (section 1).

| Pass | Created with | Power | Lifetime |
|---|---|---|---|
| master pass (`<user>-minter`) | root (Ansible or manual), locked with the user's GPG public key | can only create `<user>-dev` passes | 90d |
| `<user>-dev` | master pass, via `kube-login` | edit in its listed app namespaces | 8h |
| `<user>-admin` | `ssh` + `sudo`, via `kube-login-admin` | everything | 1h |

**Server side (`roles/k3s`, root)**
- Namespace `autobott-users` with ServiceAccounts per user: `<user>-minter`, `<user>-dev`, `<user>-admin`.
- `<user>-minter`: Role in `autobott-users` allowing only this (example for `odo`):
  ```yaml
  rules:
    - apiGroups: [""]
      resources: [serviceaccounts/token]
      resourceNames: [odo-dev]     # may create passes for this account only
      verbs: [create]
  ```
  Naming only `<user>-dev` also means it cannot create passes for itself or for `<user>-admin`.
- `<user>-dev`: RoleBinding to ClusterRole `edit` in each listed app namespace (added by `namespace.yaml`).
- `<user>-admin`: ClusterRoleBinding to `cluster-admin`.

**Laptop side (`desktop/dev-k8s`)**
- Packages: `gnupg`, `pinentry-qt`, `kubectl`.
- `~/.gnupg/gpg-agent.conf`:
  ```
  default-cache-ttl 28800                   # forget 8h after last use
  max-cache-ttl 43200                       # forget after 12h no matter what
  pinentry-program /usr/bin/pinentry-qt     # KDE popup
  ```
  Forget immediately (like `sudo -k`): `gpgconf --kill gpg-agent`.
- Files:
  ```
  ~/.gnupg/                      GPG key (private half locked by the passphrase)
  ~/.kube/neptuno-minter.gpg     master pass, locked to the GPG key
  ~/.kube/config                 cluster entry + contexts neptuno / neptuno-admin + current passes
  ```
- Kubeconfig: cluster `neptuno` → `https://127.0.0.1:16443` (tunnel) or `https://192.168.20.1:6443`
  (WireGuard), with the cluster CA; contexts `neptuno` (user `odo@neptuno`) and `neptuno-admin`
  (user `odo-admin@neptuno`).
- Shell functions (example for `odo`):
  ```sh
  # daily: GPG passphrase → 8h odo-dev pass
  kube-login() {
    minter=$(gpg -qd ~/.kube/neptuno-minter.gpg) || return
    token=$(kubectl --context neptuno --token="$minter" \
            create token odo-dev -n autobott-users --duration=8h) || return
    kubectl config set-credentials odo@neptuno --token="$token"
  }

  # admin: sudo password (checked by the server) → 1h odo-admin pass
  kube-login-admin() {
    read -rsp "sudo password for neptuno: " pw; echo
    token=$(printf '%s\n' "$pw" | ssh neptuno sudo -S -p '' \
            k3s kubectl create token odo-admin -n autobott-users --duration=1h)
    unset pw
    kubectl config set-credentials odo-admin@neptuno --token="$token"
  }
  ```
  The sudo password is read locally and passed to `sudo -S` on purpose: prompting through `ssh -t`
  mixes the prompt text into the captured token.

**Creating the master pass**
- Preferred: Ansible (root on the node) creates the 90-day pass and locks it **on the server** with the
  user's GPG public key (needs `gnupg` on the node), so only the locked file ever leaves the node.
  Delivery to the laptop and renewal are open questions.
- Manual (works today):
  ```sh
  ssh -t neptuno sudo k3s kubectl create token odo-minter -n autobott-users --duration=2160h \
    | gpg -e -r you@example.com -o ~/.kube/neptuno-minter.gpg
  ```
- A pass cannot be revoked on its own: it stays valid until it expires, unless its account is deleted.
  So do not create a new master pass on every Ansible run.

**Caveats**
- All passes travel inside HTTPS to the API server (inside the tunnel or WireGuard); GPG sends nothing,
  and the GPG key and passphrase never leave the laptop.
- Permissions cannot limit how long created passes last — the master pass can request any duration. A
  server-wide maximum exists but would also cut the 90-day master pass. The limit is on power, not time.
- Anyone who can start pods in a namespace can run them as any robot account there, so robot accounts in
  `<user>-dev`'s namespaces must not be stronger than `<user>-dev`. Keep `<user>-dev` out of
  `kube-system`, `autobott-system` and `autobott-users` (there it could act as `<user>-admin`).
- Use `edit`, not `admin` (`admin` can hand out permissions inside the namespace).
- `edit` can read the app's Secrets in those namespaces; use `view` if that is too much.
- Laptop stolen → the thief has locked files and can try to guess the passphrase offline → use a long
  passphrase. Malware running while the passphrase is remembered can create `<user>-dev` passes, not
  admin ones.
- Revoke: delete `<user>-minter` (daily access gone), or `<user>-dev` / `<user>-admin` (all their passes
  stop working).
- **Later:** move the GPG private key onto a YubiKey — commands stay the same; the PIN locks after 3
  wrong tries (no offline guessing).

---

## What the API server accepts after this

1. **Certificates signed by k3s's client CA:** the root-only admin file, and k3s's own internal parts.
2. **ServiceAccount passes:** `autobott-deployer` (1h), `<user>-minter` (90d), `<user>-dev` (8h),
   `<user>-admin` (1h), plus the pass every pod gets automatically.
3. **Proxy certificates** (request-header CA, used by metrics-server): let a trusted proxy act for any user.
4. **The k3s join token** (same port `6443`): lets a machine join; a machine joining as a server receives
   every CA key.

All master keys live in root-only files under `/var/lib/rancher/k3s/server/`. Requests without proof are
rejected; there are no passwords, static token lists or OIDC. Confirm on the node with
`journalctl -u k3s | grep 'Running kube-apiserver'`.

---

## Other items

- Host hardening for neptuno: enable crowdsec / lynis / malwarescan (firewall: section 2); SSH key-only;
  sudo always asks for a password.
- `/var/lib/rancher/k3s/server/` (CA keys, join token `server/token`): if Borg backs it up, protect the
  backup like root. With a single node, nothing should ever join — keep the join token secret.
- App pods that don't talk to Kubernetes: set `automountServiceAccountToken: false` on each app
  namespace's default ServiceAccount.
- Update `roles/k3s/About.md` + `../docs/content/docs/` once implemented; bump `autobot_version` at release.

---

## Checks on vagrant

- Enable k3s on the **Debian 13** box — today `k3s.yaml` exists only for
  `inventory/host_vars/ansible-autobott2-linux-debian-12/`, and Debian 12's Python `kubernetes` is too old.
- Login methods: `journalctl -u k3s | grep 'Running kube-apiserver'` matches the list above.
- With the firewall enabled, pods can still reach the API (UFW vs k3s pod traffic).
- `become_user: kubeops` works with `acl` installed.
- Deployer scope:
  - `kubectl auth can-i --list -n whoami --as=system:serviceaccount:autobott-system:autobott-deployer`
  - `kubectl auth can-i create helmcharts.helm.cattle.io -n whoami --as=system:serviceaccount:autobott-system:autobott-deployer` → `no`
- A 90-day pass is accepted (no maximum pass length set by k3s).
- Master pass scope:
  - `kubectl auth can-i create serviceaccounts/odo-dev --subresource=token -n autobott-users --as=system:serviceaccount:autobott-users:odo-minter` → `yes`
  - the same for `serviceaccounts/odo-admin` and `serviceaccounts/odo-minter` → `no`
- `kubectl auth can-i --list -n whoami --as=system:serviceaccount:autobott-users:odo-dev`; nothing in
  `autobott-users` / `kube-system`.
- `kube-login` and `kube-login-admin` end to end over the SSH tunnel.

---

## Open questions

- Tunnel, WireGuard, or both?
- Should `<user>-dev` also get read-only `view` across the cluster (cannot read Secrets)?
- Master pass renewal: how Ansible knows one is due, and how the locked file gets from the server play to
  the laptop (e.g. via the inventory → `dev-k8s`). Idea to test: tie each master pass to a throwaway
  Secret (`kubectl create token --bound-object-kind=Secret --bound-object-name=…`) so deleting that
  Secret kills just the old pass.
- Inventory layout for users, e.g.:
  ```yaml
  k3s:
    users:
      - name: odo
        gpg_public_key: "{{ lookup('file', 'files/gpg/odo.asc') }}"
        dev_namespaces: [whoami, immich]
  ```
- Where `dev-k8s` installs the `kube-login` functions.

---

## Not chosen

- SSH + sudo for every pass — kept for admin passes only; daily work shouldn't need SSH.
- Long-lived GPG-locked certificate or token with full power — 90 days of full power on the laptop.
- Self-signed JWTs (`--authentication-config`) — needs a Caddy vhost for public keys and a custom plugin;
  can be added later alongside (the API server accepts several login methods).
- OIDC via Authelia — needs `kubelogin`, logins depend on Authelia; can be added later alongside.
- Offline root CA + intermediates (previous plan) — heavy, and no help against root on the box.
- Static token file, token webhook / auth proxy, extra ServiceAccount signing key.
