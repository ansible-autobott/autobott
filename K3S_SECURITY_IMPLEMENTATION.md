# k3s Security Model — Implementation Plan (WORKING DOC)

> **Status:** temporary planning doc — not part of the role. Created 2026-08-31.
> Delete or fold into `roles/k3s/About.md` + `../docs` once implemented.
> **Scope:** hardening cluster/API access for single-node k3s on `neptuno.rivervps.com`.
> **Explicitly out of scope:** OIDC (decided against — cert-based user auth instead).

---

## Goal — the security model

Layered model for a single-node k3s VPS (Authelia + Tailscale available; `odo` is the human user):

| Layer | Baseline |
|---|---|
| Network | API off the public internet — firewall + Tailscale/SSH tunnel |
| Host | key-only SSH, `sudo` w/ password, security roles on (firewall/crowdsec/lynis/malwarescan) |
| Admin cert | `system:masters` kubeconfig root-only, **break-glass** |
| Human auth | **short-lived client certs** (`CN`=user, `O`=group), signed by an on-cluster **intermediate**; YubiKey where possible |
| Automation | ServiceAccount tokens |
| PKI | **offline root CA + on-cluster intermediate** (baseline — it is the revocation lever) |
| Cred at rest | encrypted / hardware-backed (user side) |

### Honest ceiling (design constraint, not a TODO)
On a single co-located node the intermediate signing key + control plane live on the box, so **whoever gets root owns the cluster** — no client-side scheme changes that. The model's real jobs:
1. **Keep attackers off the box** (network isolation + host hardening).
2. **Ensure a *credential* leak ≠ cluster-admin** (break-glass admin + scoped, short-lived identities).

Bringing our own root buys: **root key custody (off-box)**, a **bulk revocation lever** (rotate the intermediate), and a **recovery trust anchor** — not resistance to host compromise.

### PKI clarification (why we keep "the cluster CA")
k3s has several CAs by function: **client-ca** (signs certs that auth *to* the apiserver — our users *and* k3s's own kubelet/controller/scheduler/admin certs), **server-ca** (signs the API serving cert), **request-header-ca** (aggregation), plus the SA signing key. With the custom-CA flow, **each becomes an intermediate signed by our offline root** — the client-CA *is* our intermediate, just re-parented. We don't add a CA beside it; we change its parent.

---

## Operator prerequisites (OUT OF BAND — Ansible never sees these keys)

1. Generate the **offline root CA** (openssl / step-ca / HSM). Root key stays offline forever.
2. Generate the **k3s CA set as intermediates under the root** using k3s's `generate-custom-ca-certs.sh` (offline).
3. Store the resulting **intermediate CA keys + certs** (and the root *cert*) as **SOPS secrets** in the inventory (`make edit-secrets`).
4. **Per user:** users self-generate a keypair (ideally YubiKey/PIV) and produce a **CSR**. Private keys never enter Ansible.

**Best-practice rule captured:** Ansible is a *distributor* for crown-jewel keys (CA keys → operator-provides via SOPS, Ansible deploys), a *generator* only for leaf keys born on the target (k3s does this itself), and **never** generates a user's private key (CSR round-trip: user key local → CSR → sign → return cert only).

---

## Ansible changes (by workstream)

### 1. PKI seeding — custom CA  (`roles/k3s/`)
- New toggle + vars in `defaults/main.yaml`: e.g. `k3s.custom_ca: false` + references to SOPS CA material.
- New tasks **before** "Enable and start k3s server": write the SOPS-provided CA set into `/var/lib/rancher/k3s/server/tls/` (`0600`, root:root) so k3s generates all leaf/component certs under our root.
- **Clobber guard:** `stat` the tls dir; only seed on a fresh install. Existing cluster → use `k3s certificate rotate-ca --path /var/lib/rancher/k3s/server` (separate task/notes).
- ⚠️ Must land **before first `k3s server` start**.

### 2. Break-glass admin kubeconfig  (`roles/k3s/`)
- `templates/config.yaml.j2`: `write-kubeconfig-mode: "0600"` (was `0640`).
- Remove the `k3s-admin` group tasks (create group + add users) from `tasks/main.yaml`.
- Remove `ExecStartPost=/bin/chgrp k3s-admin …` from `templates/k3s.service.j2`.
- Drop the now-unused `admins` default; remove `admins: [odo]` from neptuno's `k3s.yaml` host_var.
- Update `About.md` (kubeconfig = root-only, break-glass).
- **Lowest-risk item — good starting point.**

### 3. Network isolation — firewall + tailscale + inventory
- Enable `run_role_firewall` for neptuno; rule: allow `6443` **only from the Tailscale interface / loopback**, drop on the public NIC.
- Add the **Tailscale hostname/IP to `k3s.tls_san`** (serving cert valid over the tailnet).
- Confirm/enable the Tailscale role for neptuno.
- 🔎 Needs reading the firewall + tailscale role schemas to wire precisely.

### 4. Scoped RBAC for cert users  (`roles/k3s/`)
- New var, e.g. `k3s.rbac_bindings`: list of `{subject, kind: User|Group, role, namespace}`.
- Template `Role`/`RoleBinding`/`ClusterRoleBinding` YAML into `/var/lib/rancher/k3s/server/manifests/` (k3s auto-applies), binding CNs / `O`-groups to `view`/`edit`/`admin` — **never `cluster-admin`**.
- **Signing stays out of Ansible:** users self-generate keys → CSR → `kubectl certificate approve` (or a signing helper). Ansible manages *bindings*, not private keys.
- Short cert lifetimes are mandatory (expiry = revocation); bulk revoke by rotating the intermediate.

### 5. Host hardening — inventory toggles (existing roles)
- Enable `crowdsec` / `lynis` / `malwarescan` / `firewall` for neptuno.
- Ensure SSH key-only and `sudo` requires a password (no NOPASSWD).

### 6. Repo hygiene
- Add new CA secret keys to `.sops.yaml` scope.
- Update `roles/k3s/About.md` + `../docs/content/docs/` with the model.
- Bump `autobot_version` at release.

### (Optional) SA tokens for automation
- Declare ServiceAccounts + RoleBindings via the same manifests mechanism as #4.

---

## Ordering & dependencies
1. **#1 PKI seeding** — before first cluster start (or `rotate-ca` on existing).
2. **#2 kubeconfig** — independent, low-risk (can go first).
3. **#3 network isolation** — anytime.
4. **#4 RBAC** — needs the cluster up.
5. **#5 / #6** — low-risk toggles/docs.

## Open questions / decisions
- Firewall + tailscale exact wiring (read those roles).
- neptuno fresh-install vs existing cluster → seed-before-start vs `rotate-ca`. (Assumed **fresh**.)
- Declare SA tokens for automation via manifests? (optional)
- Confirm the exact k3s custom-CA commands/paths against upstream docs before wiring #1.
