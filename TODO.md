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
- [ ] git prune branches
- [ ] kmix vs audio controls for master volume shortcuts

# k3s

## Merge blockers and important (rated 7+, deep review 2026-10-24)

## Follow-ups (rated 3-6)

- [ ] mutually exlusive hosts: desktop, server and k8s
- [ ] [6] Calico: bump the pin and make `k3s.calico.version` real (or drop Calico)
      Calico 3.29 is tested against Kubernetes 1.29-1.32 only and is four minors behind 3.33 (tested
      against 1.35-1.37); the role installs Kubernetes 1.35.1. The knob is a no-op: `calico.yaml.j2`
      hardcodes the `v3.29.3` images and only `CALICO_IPV4POOL_CIDR` is templated (verified by diffing
      against the upstream 3.29.3 manifest: one changed line).
  - Replace the vendored manifest with 3.33.x and template the image tag from the knob, or remove the knob.
  - Re-check the justification: stock k3s already enforces NetworkPolicy (embedded kube-router
    controller), so "NetworkPolicy support" is not a reason for Calico. State the real reason in
    About.md or go back to the k3s default.
- [ ] [5] A namespace admin can publish host ports past UFW
  ClusterRole `admin` lets the robot create NodePort / LoadBalancer Services (checked: `create services` is allowed in a bound namespace) and Services with `spec.externalIPs` set to the node IP (the CVE-2020-8554 pattern). ServiceLB and kube-proxy publish them with iptables before UFW, so an app role can open any port to the internet, outside `servicelb_ports` and the firewall. Traefik's LoadBalancer also allocates NodePorts (30846 / 32389 on the VM), open today.
  - Here: `kube-apiserver-arg: [enable-admission-plugins=DenyServiceExternalIPs]` in `config.yaml.j2`. The ResourceQuota per app namespace (`services.loadbalancers: "0"`, `services.nodeports: "0"`; `admin` cannot edit quotas) is autobott-k8s's part, tracked in its TODO.md. Alternative: a ValidatingAdmissionPolicy denying those Service types outside `kube-system`.
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
- [ ] [4] Docs: no role page for k3s; drop-in and vagrant docs uncommitted in `../docs`
  `../docs/content/docs/roles/` has no k3s page; the `firewall.md` (drop-ins) and `vagrant.md`
  edits sit uncommitted on the docs repo's `main`. Add the page in a new `k8s/` section, like the
  role (what it installs, the UFW side effect, 80/443 exclusivity with Caddy, break-glass access,
  host_vars example, `VER=13-k3s`) and commit the docs.
- [ ] [4] Implicit firewall enablement
  `run_role_k3s: true` overrides `run_role_firewall` through the import vars, so UFW with outbound
  reject lands on hosts that opted out (it already bit nullmailer 587/tcp and NTP 123/udp). Either
  assert `run_role_firewall` with a clear message, or make the side effect prominent in the role
  page and the inventory sample.
- [ ] [3] `kubectl` is managed by both k3s and tools/dev-k8s
  k3s symlinks `/usr/local/bin/kubectl`, dev-k8s downloads to the same path; only a comment in the
  k3s host_vars prevents the two roles from flapping. Skip kubectl in dev-k8s when `run_role_k3s`
  is true, or assert.
