<!-- todo:guide — managed by todo; this block is rewritten on save. Docs: https://github.com/candy-tools/todo
This file is a todo list managed by "todo", a terminal TODO app:
https://github.com/candy-tools/todo

todo watches this file and reloads it automatically when it changes on disk, so
you — human or agent — can edit it directly in any editor. Keep to this format
so todo can parse what you write:

  # Heading           Headings ("#" to "######") are categories; they nest by
                      heading level.
  - [ ] Open task     A "- [ ]" line is an open task; "- [x]" marks it done.
  - [/] In progress   "- [/]" flags a task in progress, "- [>]" defers it.
  - [x] Done task     Tasks must live under a category heading.
    - [ ] Subtask     Indent by two spaces to nest a subtask under a task.
    Description text  An indented, non-checkbox line is the task's description.

Notes for editors:
- Text above the first heading (this block included) is preserved on save.
- todo rewrites the file into the canonical form above on every change, so any
  other free-form markdown placed between items is not kept.

Prefer the CLI over editing by hand: it writes this file in the exact format
above. `todo add`, `todo done|progress|defer|reopen`, `todo edit`, `todo rm`
and `todo list --json` cover the common actions — run `todo --help`.
-->

# TODO

## ansible-core 2.21 upgrade follow-ups

- [ ] Finish end-to-end Vagrant validation on a **fresh** VM for Debian 13
  (`make vagrant-destroy` + `make vagrant-up`, then `make vagrant-run`). The
  last run reached `ok=788` before the next fix — not yet a clean full pass.
- [ ] Clear remaining ansible-core 2.19 templating fallout as it surfaces:
  - Native types: a whole-value `{{ x | int }}` now stays an `int`; use `| string`
    for strict modules (e.g. `community.general.xml`).
  - Strict undefined: undefined vars in `{% if %}`/conditionals now error
    (dead `run_role_node` guard already removed — watch for more leftovers).
- [x] Add a CI lint gate — `.github/workflows/lint.yml` runs strict
  `make lint`; all roles pass with no baseline.
- [ ] (Optional) If releasing this upgrade, bump `autobot_version` in
  `roles/base/enroll/defaults/main.yaml` before opening the PR.

## Borgmatic repo-init: key export/fetch logic bug

- [ ] Drop the redundant `with_subelements` on the **Export Borg keys (2.x)** and
      **Fetch exported Borg keys** tasks. `init_repo.yaml` already runs once per
      *(profile, destination)* pair — the outer include loops `borgmatic_backups`
      (`item` = profile) and the inner include loops `item.destination`
      (`loop_var: destination`) — so those tasks should use `item.name` (profile) +
      `destination` directly instead of re-iterating all profiles × destinations.
      Current problems:
  - redundant O(N²) exports/fetches;
  - **mismatch** — the key file is named after `backup_item.0.name` (the subelements
    profile) while the repo path/label come from the *outer* `destination`;
  - the **Borg 1.x** export task (no loop) uses `item.0.name`, where `item` is the
    profile dict → `item.0` is undefined; latently broken, skipped on borg 2.x.
- [ ] Deferred because it changes real backup key-export behavior and the current
  vagrant inventory can't exercise it (both sample destinations skip — one has no
  `encryption`, the other `encryption: none`). Add an encrypted ssh destination to
  the test inventory first, then fix + verify.

## linux-kde: KDE menu actions (`add_kde_menu_actions`) are still Plasma 5-only

- [ ] Decide: port it to Plasma 6, or remove the feature.
- [ ] If porting:
  - apt: install `qdbus-qt6` instead of `qdbus` — `qdbus` doesn't exist in trixie,
    so enabling the toggle currently fails at the apt step;
  - `files/menu_actions/kim_*`: call `qdbus6` instead of `qdbus` (the kdialog
    progress-bar D-Bus calls);
  - install `kim_convertandrotate.desktop` to `/usr/share/kio/servicemenus/` rather
    than the legacy `/usr/share/kservices5/ServiceMenus/` (KF6 still reads it, but
    it's deprecated), with `MimeType=image/*;` instead of `image/*` in `ServiceTypes`;
  - verify on the vagrant box — enable `linux_kde.add_kde_menu_actions` in its
    inventory first (it's off there).
- [ ] If removing: drop the menu-action block in `tasks/main.yaml`,
  `files/menu_actions/`, the `add_kde_menu_actions` default, and the "Image
  context-menu actions" section of the docs page.

## desktop

- [ ] Ctrl shif c does not work in dolthing terminal
- [ ] ssh agents needs to work better
- [ ] disable snap on screen edge

# k3s

## Merge blockers and important (rated 7+, deep review 2026-10-24)

- [x] [blocker 8] Drop `K3S_SECURITY_IMPLEMENTATION.md` from the branch before merging
      Working doc at the repo root. It names the production host, the admin
      user, the host's security gaps (API/kubelet exposure, sshd forwarding settings) and a human-login
      design that is not implemented. The repo is public and the file is already on `origin/k3s`
      (commit 830ec6b), so it is public history today. The doc itself says "delete or fold into
      About.md + docs once implemented".
  - Fold the generic parts worth keeping (section 2/4 plan, "what the API server accepts", the vagrant
    checks) into `roles/k3s/About.md` or `../docs`, without host names or user names; delete the file.
  - Local `k3s` is a rewritten copy of `origin/k3s` (same commits, new hashes): pushing needs
    `--force-with-lease`. Decide whether to also rewrite the remote history or accept the leak.
- [x] [blocker 8] Revert a39294d (web stack switched off on the debian-13 VM) or split it into its own PR
  The commit flips caddy, php-fpm, authelia, vhosts, homepage, fe26, radicale, immich, docmost,
  mealie, phpmyadmin, mediawiki and aether to `false` on the main vagrant host. It is unrelated to
  k3s, and the k3s VM does not enable them either, so after the merge no VM exercises the web stack:
  `make vagrant-run` loses most of its coverage (the fresh-VM full pass in the ansible-core section
  above is still open). `make vagrant-test` has no coverage to lose (see the validation item below).
- [x] [important 7] A `k3s.version` bump does not restart k3s
      "Link k3s to /usr/local/bin" has no `notify`; only `config.yaml.j2` and `k3s.service.j2` notify
      `restart k3s`. The server runs from the extracted bundle in
      `/var/lib/rancher/k3s/data/<hash>/bin/k3s` (checked on the VM), so after a bump the old version
      keeps running until a reboot while Ansible reports the upgrade done (and the sample page footer
      shows the new version).
  - Notify `restart k3s` from the link task and `meta: flush_handlers` before "Wait for k3s to be ready".
    The flush also makes config/unit changes reach k3s before the wait, manifest and robot steps
    instead of at the end of the play, and removes the needless second restart on a first run.
  - `k3s_checksums` offers 1.32.3 and 1.35.1: a three-minor jump, which Kubernetes/k3s do not support
    (one minor at a time, datastore migrations). Document it or assert the skew.
  - Assert `k3s_config.version in k3s_checksums` next to the Debian check: today an unknown version
    dies with an opaque Jinja error after the directories were created.
- [ ] [important 7] The namespace bootstrap is duplicated across repos and has already diverged
      `tasks/namespace.yaml`, `k3s_namespace_pod_security` and the "Usage in an app role" section of
      About.md have no consumer in this repo. autobott-k8s ships its own `roles/k8s/tasks/namespace.yaml`
      (parameterised cluster config, `state: absent`, volumes, SSO middleware check, `managed-by` label,
      `restricted` default) and only relies on this role for the robot ServiceAccount, `kubeops` and the
      CA copy. Two copies of the RBAC + Pod Security bootstrap will drift silently (they already do).
  - Decide the owner before merging: delete the copy here and make About.md the contract (robot
    `autobott-system/autobott-deployer`, user `kubeops`, `/etc/rancher/k3s/server-ca.crt`,
    `https://127.0.0.1:6443`, invariants 1-5), pointing to autobott-k8s for the app side.
- [ ] mutually exlusive hosts: desktop, server and k8s

## Follow-ups (rated 3-6)

- [ ] [6] Calico: bump the pin and make `k3s.calico.version` real (or drop Calico)
      Calico 3.29 is tested against Kubernetes 1.29-1.32 only and is four minors behind 3.33 (tested
      against 1.35-1.37); the role installs Kubernetes 1.35.1. The knob is a no-op: `calico.yaml.j2`
      hardcodes the `v3.29.3` images and only `CALICO_IPV4POOL_CIDR` is templated (verified by diffing
      against the upstream 3.29.3 manifest: one changed line).
  - Replace the vendored manifest with 3.33.x and template the image tag from the knob, or remove the knob.
  - Re-check the justification: stock k3s already enforces NetworkPolicy (embedded kube-router
    controller), so "NetworkPolicy support" is not a reason for Calico. State the real reason in
    About.md or go back to the k3s default.
- [ ] [6] `k3s-killall.sh` / `k3s-reset.sh` never stop k3s
      They loop over `/etc/systemd/system/k3s*.service` (the upstream install location), but the role
      installs the unit at `/lib/systemd/system/k3s.service` (`FragmentPath=/usr/lib/systemd/system/k3s.service`
      on the VM, nothing under `/etc`). killall then kills the shims and tears down networking under a
      live server; reset deletes `server/db` and `server/tls` while k3s is running and its
      `systemctl start` is a no-op.
  - Install the unit under `/etc/systemd/system` like upstream, or `systemctl stop k3s` in the scripts.
  - After a reset the cluster has a new CA and no robot account, but `/etc/rancher/k3s/server-ca.crt`
    and the script header say nothing: kubeops deploys fail TLS verification and token minting fails
    until the k3s role is re-run. Re-publish the CA from the script or print that reminder at its end.
- [ ] [5] A namespace admin can publish host ports past UFW
      ClusterRole `admin` lets the robot create NodePort / LoadBalancer Services (checked: `create
      services` is allowed in a bound namespace) and Services with `spec.externalIPs` set to the node
      IP (the CVE-2020-8554 pattern). ServiceLB and kube-proxy publish them with iptables before UFW,
      so an app role can open any port to the internet, outside `servicelb_ports` and the firewall.
      Traefik's LoadBalancer also allocates NodePorts (30846 / 32389 on the VM), open today.
  - Cheapest fix, in whichever namespace.yaml survives: a ResourceQuota per app namespace with
    `services.loadbalancers: "0"` and `services.nodeports: "0"` (`admin` cannot edit quotas), plus
    `kube-apiserver-arg: [enable-admission-plugins=DenyServiceExternalIPs]` in `config.yaml.j2`.
    Alternative: a ValidatingAdmissionPolicy denying those Service types outside `kube-system`.
  - `service.spec.allocateLoadBalancerNodePorts: false` for Traefik through the HelmChartConfig; document.
- [ ] [5] No readiness gate after the Calico / Traefik manifests
      The role only waits for the API (`kubectl get nodes`); Calico and Traefik are applied in the
      background by the manifests dir. On a fresh host, roles that deploy next (autobott-k8s apps with
      `wait: true`) can hit a NotReady node or a missing IngressClass while images pull.
  - `kubectl wait --for=condition=Ready node --all` after the Calico manifest, and
    `rollout status deploy/traefik -n kube-system` before handing over.
  - Write the Calico files and the Traefik HelmChartConfig into the manifests dir before the first
    start: today the node boots without a CNI and Traefik installs twice on a fresh host (defaults
    first, then again when `traefik-config.yaml` appears).
- [ ] [3] `- k3s` sits after the webservices in autobott.yaml
  k3s is infrastructure, but it is the last role of the linux_servers play, and `namespace.yaml`
  only asserts `run_role_k3s`, not that k3s and python3-kubernetes are installed. Any app role in
  this repo placed in the natural webservices slot would run before k3s exists on a fresh host.
  Move it up next to docker / firewall (no consumer here yet, so it is free now).
- [ ] [3] Reserve `autobott-sample` in the namespace bootstrap
  `tasks/main.yaml` deletes `namespace/autobott-sample` on every run while `sample_content` is
  false (the default), but the reserved list in namespace.yaml does not include it: an app using
  that name would be wiped each run. Add it to the list in whichever namespace.yaml survives.
- [ ] [5] Role location: `roles/k3s` is the only role outside a category
  Everything else is `roles/<category>/<role>`. autobott-k8s already refers to "autobott's k3s
  role" and its contract, so moving later costs more. Decide now (`base-services/k3s`, or a new
  `k8s/` category).
- [ ] [4] Docs: no role page for k3s; drop-in and vagrant docs uncommitted in `../docs`
  `../docs/content/docs/roles/` has no k3s page; the `firewall.md` (drop-ins) and `vagrant.md`
  edits sit uncommitted on the docs repo's `main`. Add the page (what it installs, the UFW side
  effect, 80/443 exclusivity with Caddy, break-glass access, host_vars example, `VER=13-k3s`) and
  commit the docs.
- [ ] [4] Implicit firewall enablement
  `run_role_k3s: true` overrides `run_role_firewall` through the import vars, so UFW with outbound
  reject lands on hosts that opted out (it already bit nullmailer 587/tcp and NTP 123/udp). Either
  assert `run_role_firewall` with a clear message, or make the side effect prominent in the role
  page and the inventory sample.
- [ ] [4] Release: bump `autobot_version` before opening the PR
  It is `v0.2.2`, the latest tag; a new role ships as a release (see AGENTS.md "Before Opening a PR").
- [ ] [4] No validation test for k3s
  There is no validation harness at all: `make vagrant-test` runs `test.yaml`, which does not exist
  (never committed), and `roles/validation` is a commented-out stub, so the target fails before it
  runs anything, on every VM. A k3s check (node Ready, Traefik answering on :80, the sample page)
  needs that harness first.
- [ ] [3] Stray inventory file `inventory/host_vars/ansible-autobott2-linux-debian-12/k3s.yaml`
  No such host in `inventory/vagrant.yaml`, the directory does not exist on `main`, and the role
  refuses Debian 12 anyway. Delete it.
- [ ] [3] Legacy cleanup tasks for an unreleased version
  The `k3s-admin` group removal, `/etc/profile.d/k3s.sh` removal and the kubeconfig chown exist for
  one host that ran a pre-release role. Drop them once that host has converged (note the date).
- [ ] [3] `kubectl` is managed by both k3s and tools/dev-k8s
  k3s symlinks `/usr/local/bin/kubectl`, dev-k8s downloads to the same path; only a comment in the
  k3s host_vars prevents the two roles from flapping. Skip kubectl in dev-k8s when `run_role_k3s`
  is true, or assert.
- [ ] [4] Vagrant k3s VM: run Traefik on the host's ports (8083/8446), so `https_redirect` works there
      The VM can't replicate a real host's HTTPS flow. vagrant forwards host 8083 → VM 80 and 8446 → VM 443,
      and Traefik's chart always renders the redirect as `entryPoint.to=:<websecure exposedPort>` (`:443`,
      checked in chart 38 on the VM), so `https_redirect` stays off there. Without it, plain HTTP to an app
      behind autobott-k8s's Authelia gets Authelia's `400` ("insecure scheme 'http'") instead of an upgrade,
      and `https://<app>.k3s.localhost:8083/` gets Traefik's `404` (TLS on the `web` entrypoint, which has no
      TLS routes). Fix: make the VM's Traefik listen on the ports browsers use, so the chart's own redirect
      points to 8446.
  - `defaults/main.yaml`: Traefik port settings, e.g. `http_port: 80` and `https_port: 443`.
  - `traefik-config.yaml.j2`: render them as `ports.web.exposedPort` / `ports.websecure.exposedPort` (still
    `{}` when nothing is overridden). `servicelb_ports` must follow them: derive it, or set it in the VM's
    inventory.
  - Sample inventory, the VM's `k3s.yaml`: ports 8083 / 8446 and `https_redirect: true`.
  - `vagrant/vagrantfile`: forward 8083 → 8083 and 8446 → 8446 (today 8083 → 80 and 8446 → 443).
  - `About.md`: replace "keep it off where clients reach HTTPS on another port". In autobott-k8s only docs
    and comments that say vagrant forwards to the VM's 80/443 change; its Authelia keeps
    `authelia_url: https://auth.k3s.localhost:8446`.
  - Check: `http://sonarr.k3s.localhost:8083/` redirects to `https://sonarr.k3s.localhost:8446/`, which
    redirects to the Authelia portal.
  - Alternatives weighed (2026-10-24): forward host 80/443 → VM 80/443 (no role change, but needs
    `net.ipv4.ip_unprivileged_port_start=80` on the host), or a redirect-port setting rendered as Traefik
    flags (`--entryPoints.web.http.redirections.entryPoint.to=:8446`), bypassing the chart's value.
