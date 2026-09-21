---
name: upgrade-packages
description: Bump pinned upstream package versions across roles to their latest release and refresh the download hashes. Use when the user wants to update pinned dependencies / checksums in the Ansible roles ("upgrade packages", "bump versions", "update checksums").
argument-hint: "[role ...]  (optional: limit to one or more role names, e.g. authelia prometheus; default = all)"
---

# Upgrade pinned package versions

Walk the roles that pin an upstream artifact to a specific version, bump each to its
latest upstream release, and — for the roles that verify a download hash — fetch the new
artifact and refresh the checksum.

Run **automatically**: apply every available upgrade without pausing for confirmation.
The result is meant to be reviewed as a **PR diff**, so correctness of the edits matters
more than interactivity. Do **not** commit or push (see [Finish](#finish)).

`$ARGUMENTS` — if given, restrict to the named role(s) (match on the role directory name,
e.g. `authelia`, `prometheus`, `etnafinance`). If empty, process every role below.

## Preflight

1. **Branch guard.** Run `git status`. If on `main`/`master`, stop and ask the user for a
   branch — this repo forbids committing to main. Otherwise continue (edits only; no commit).
2. **Tools.** Requires `gh` (public GitHub API — works even though `gh auth` points at the
   corp host), `curl`, `sha256sum`, `sha1sum`, `sha512sum` (maven), and `jq`. Network access
   is required.
3. Work from the repo root (`git rev-parse --show-toplevel`).

## How pinning works here (the Authelia pattern)

Most roles follow the shape in `roles/web-base/authelia`:

- `roles/<cat>/<role>/defaults/main.yaml` has a scalar `version:` under the
  `<role>_defaults:` dict, **and** a top-level `<role>_checksums:` map of
  `"<version>": "<hash>"`.
- `roles/<cat>/<role>/tasks/main.yaml` downloads the artifact with `ansible.builtin.get_url`
  and verifies it via `checksum: "<algo>:{{ <role>_checksums[..version] }}"`.

So an upgrade is: **bump `version:` → download the new artifact → compute its hash →
append a new `"<version>": "<hash>"` entry to the checksums map.**

## The other pattern: per-tool version catalogs (the dev-* roles)

The `roles/desktop/dev-*` roles (dev-generic, dev-go, dev-java, dev-k8s, dev-node) do
**not** follow the Authelia shape. Each tool in the role has its own pair of top-level vars
in `defaults/main.yaml`:

- `<tool>_default_version` — the scalar version installed when the tool is selected without
  an explicit pin. **This is the field you bump.**
- `<tool>_versions:` — a **map** `"<version>": "<hash>"` (the checksum lookup), *or* for
  a couple of tools a plain **allow-list** of version strings with no hash.

The task verifies via `checksum: "<algo>:{{ <tool>_versions[<tool>_version] }}"`. So an
upgrade here is: **bump `<tool>_default_version` → download the new artifact → append a new
`"<version>": "<hash>"` entry to `<tool>_versions` (keep the old entries — the catalog is an
allow-list, existing pins stay valid).** For the allow-list tools, just prepend the new
version string; there is no hash. See [Tier 1b](#tier-1b--per-tool-version-catalogs-desktopdev-roles).

## Per-role procedure

For each in-scope role:

1. **Current version** — read the `version:` value from `defaults/main.yaml` (exact string,
   note quoting).
2. **Latest version** — query upstream (see the [reference table](#tier-1--auto-bump--refresh-hash)
   for the exact command + how to transform the upstream tag into the string this role stores).
3. **Compare.** If latest == current → record "up to date", skip. Only ever move forward.
4. **Refresh the hash (Tier 1 only)** — build the real artifact URL by taking the role's own
   `get_url` `url:` and substituting the new version (the table lists the resolved template as
   `V` = new stored version). Then:
   ```bash
   f=$(mktemp)
   curl -fSL "<artifact-url-for-new-version>" -o "$f"
   sha256sum "$f" | awk '{print $1}'   # or sha1sum for stash
   ```
   If the download 404s, the filename/tag convention changed upstream — **do not guess**;
   record the role as "failed: URL changed" and move on.
5. **Edit `defaults/main.yaml`** with the Edit tool:
   - Set `version:` to the new value, **preserving the role's quoting** (some quote it,
     some don't — match what's there).
   - **Append** `  "<new-version>": "<hash>"` to the `<role>_checksums:` map. Keep existing
     entries (history is intentionally retained — aether/etnafinance/stash keep several).
     Match the existing indent (2 spaces) and the `"key": "value"` quoting.
6. Record the result for the summary.

### Editing rules (apply to every edit)

- **Preserve style**: quoting of the `version:` value and the checksum entries must match the
  surrounding lines.
- **Append, don't replace**: add the new checksum entry after the existing ones.
- **Clean hashes only**: a sha256 is exactly 64 hex chars, a sha1 exactly 40. Emit only the
  hash — no trailing characters. (Some existing entries in the repo have stray trailing dots,
  e.g. grafana `12.0.2`, etnafiance `0.9.3` — a latent bug; do not copy that pattern, and if
  you touch such a role you may fix the malformed current entry.)
- **Version-string format** = whatever makes the role's `url:` template resolve to the real
  tag. If the template is `.../download/v{{version}}/...` store **without** the leading `v`;
  if it's `.../download/{{version}}/...` store the tag **as-is**. The table encodes this.

## Tier 1 — auto-bump + refresh hash

All follow the Authelia pattern. Checksum algo is **sha256 unless noted**. `V` = the new
stored version (after the tag transform).

| Role (dir) | version key | checksum map var | algo | latest command | tag → stored | artifact URL (with `V`) |
|---|---|---|---|---|---|---|
| web-base/authelia | `authelia_defaults.version` | `authelia_checksums` | sha256 | `gh api repos/authelia/authelia/releases/latest --jq .tag_name` | strip `v` | `https://github.com/authelia/authelia/releases/download/vV/authelia-vV-linux-amd64.tar.gz` |
| base-services/borg | `borg_defaults.version` | `borg_checksums` | sha256 | `gh api repos/borgbackup/borg/releases/latest --jq .tag_name` | as-is (no `v`) | `https://github.com/borgbackup/borg/releases/download/V/borg-linux-glibc236` |
| monitoring/alertmanager | `alertmanager_defaults.version` | `alertmanager_checksums` | sha256 | `gh api repos/prometheus/alertmanager/releases/latest --jq .tag_name` | strip `v` | `https://github.com/prometheus/alertmanager/releases/download/vV/alertmanager-V.linux-amd64.tar.gz` |
| monitoring/grafana | `grafana_defaults.version` | `grafana_checksums` | sha256 | `gh api repos/grafana/grafana/releases/latest --jq .tag_name` | strip `v` | `https://dl.grafana.com/oss/release/grafana-V.linux-amd64.tar.gz` |
| monitoring/node_exporter | `node_exporter_defaults.version` | `node_exporter_checksums` | sha256 | `gh api repos/prometheus/node_exporter/releases/latest --jq .tag_name` | strip `v` | `https://github.com/prometheus/node_exporter/releases/download/vV/node_exporter-V.linux-amd64.tar.gz` |
| monitoring/prometheus | `prometheus_defaults.version` | `prometheus_checksums` | sha256 | `gh api repos/prometheus/prometheus/releases/latest --jq .tag_name` | strip `v` | `https://github.com/prometheus/prometheus/releases/download/vV/prometheus-V.linux-amd64.tar.gz` |
| servarr/kavita | `kavita_defaults.version` | `kavita_checksums` | sha256 | `gh api repos/Kareadita/Kavita/releases/latest --jq .tag_name` | strip `v` | `https://github.com/Kareadita/Kavita/releases/download/vV/kavita-linux-x64.tar.gz` |
| servarr/stash | `stash_defaults.version` | `stash_checksums` | **sha1** | `gh api repos/stashapp/stash/releases/latest --jq .tag_name` | strip `v` | `https://github.com/stashapp/stash/releases/download/vV/stash-linux` |
| servarr/xbvr | `xbvr_defaults.version` | `xbvr_checksums` | sha256 | `gh api repos/xbapps/xbvr/releases/latest --jq .tag_name` | as-is (no `v`) | `https://github.com/xbapps/xbvr/releases/download/V/xbvr_V_linux_x86_64.tar.gz` |
| webservices/aether | `aether_defaults.version` | `aether_checksums` | sha256 | `gh api repos/andresbott/aether/releases/latest --jq .tag_name` | strip `v` | `https://github.com/andresbott/aether/releases/download/vV/aether_V_linux_amd64_v3.deb` |
| webservices/dashi | `dashi_defaults.version` | `dashi_checksums` | sha256 | `gh api repos/andresbott/dashi/releases/latest --jq .tag_name` | strip `v` | `https://github.com/andresbott/dashi/releases/download/vV/dashi_Linux_x86_64_v3.zip` |
| webservices/etnafinance | `etnafiance_defaults.version` ⚠ | `etnafiance_checksums` ⚠ | sha256 | `gh api repos/andresbott/etna-finance/releases/latest --jq .tag_name` | strip `v` | `https://github.com/andresbott/etna-finance/releases/download/vV/etna-finance_Linux_x86_64_v3.zip` |
| webservices/fe26 | `fe26_defaults.version` | `fe26_checksums` | sha256 | `gh api repos/AndresBott/Fe26/releases/latest --jq .tag_name` | as-is (no `v`) | `https://github.com/AndresBott/Fe26/releases/download/V/fe26-linux-amd64` |
| webservices/phpmyadmin | `phpmyadmin_defaults.version` | `phpmyadmin_checksums` | sha256 | `gh api repos/phpmyadmin/phpmyadmin/releases/latest --jq .tag_name` | `RELEASE_5_2_3` → `5.2.3` (drop `RELEASE_`, `_`→`.`) | `https://files.phpmyadmin.net/phpMyAdmin/V/phpMyAdmin-V-all-languages.zip` |

> ⚠ **etnafinance uses a misspelled variable prefix** (`etnafiance_`) throughout its role.
> The role dir is `etnafinance` but the vars are `etnafiance_defaults` / `etnafiance_checksums`
> / `etnafiance_config`. Edit the misspelled names — do not "correct" them here.

**mediawiki (report-only).** `roles/webservices/mediawiki` is also a checksums-map role
(`mediawiki_defaults.version`, `mediawiki_checksums`, sha256, tarball at
`https://releases.wikimedia.org/mediawiki/<MAJOR.MINOR>/mediawiki-V.tar.gz`), **but do not
auto-bump it.** A MediaWiki bump also needs matching `mediawiki_mobile_frontend_file` and
`mediawiki_minerva_skin_file` entries plus the corresponding extension/skin tarballs
committed into the role's `files/` (the download links from ExtensionDistributor expire and
the filenames embed a snapshot hash). It is also LTS-pinned (1.43 is an LTS line). Report
current vs. latest and leave it for a human.

### Worked example (authelia)

```bash
cur=4.39.4
tag=$(gh api repos/authelia/authelia/releases/latest --jq .tag_name)   # e.g. v4.39.22
new=${tag#v}                                                            # 4.39.22
f=$(mktemp)
curl -fSL "https://github.com/authelia/authelia/releases/download/v${new}/authelia-v${new}-linux-amd64.tar.gz" -o "$f"
sha256sum "$f" | awk '{print $1}'                                       # -> the new hash
```
Then edit `roles/web-base/authelia/defaults/main.yaml`: set `version: 4.39.22` and append
`  "4.39.22": "<hash>"` to `authelia_checksums:`.

## Tier 1b — per-tool version catalogs (desktop/dev-* roles)

The [per-tool catalog pattern](#the-other-pattern-per-tool-version-catalogs-the-dev--roles):
bump `<tool>_default_version`, append `"<V>": "<hash>"` to `<tool>_versions`. Algo is
**sha256 unless noted**. `V` = the new stored version (after the tag transform).

| Role (dir) | version key | catalog var | algo | latest command | tag → stored | artifact URL (with `V`) |
|---|---|---|---|---|---|---|
| desktop/dev-generic | `vault_default_version` | `vault_versions` | sha256 | `curl -s https://api.releases.hashicorp.com/v1/releases/vault/latest \| jq -r .version` | as-is (no `v`) | `https://releases.hashicorp.com/vault/V/vault_V_linux_amd64.zip` |
| desktop/dev-generic | `herdr_default_version` | `herdr_versions` | sha256 | `gh api repos/herdrdev/herdr/releases/latest --jq .tag_name` | strip `v` | `https://github.com/herdrdev/herdr/releases/download/vV/herdr-linux-x86_64` |
| desktop/dev-go | `goreleaser_default_version` | `goreleaser_versions` | sha256 | `gh api repos/goreleaser/goreleaser/releases/latest --jq .tag_name` | strip `v` | `https://github.com/goreleaser/goreleaser/releases/download/vV/goreleaser_V_amd64.deb` |
| desktop/dev-go | `nfpm_default_version` | `nfpm_versions` | sha256 | `gh api repos/goreleaser/nfpm/releases/latest --jq .tag_name` | strip `v` | `https://github.com/goreleaser/nfpm/releases/download/vV/nfpm_V_amd64.deb` |
| desktop/dev-go | `golangci_lint_default_version` | `golangci_lint_versions` | sha256 | `gh api repos/golangci/golangci-lint/releases/latest --jq .tag_name` | strip `v` | `https://github.com/golangci/golangci-lint/releases/download/vV/golangci-lint-V-linux-amd64.deb` |
| desktop/dev-java | `jenv_default_version` | `jenv_versions` | sha256 | `gh api repos/jenv/jenv/releases/latest --jq .tag_name` | as-is (no `v`) | `https://github.com/jenv/jenv/archive/refs/tags/V.tar.gz` |
| desktop/dev-java | `maven_default_version` | `maven_versions` | **sha512** | see maven note below | as-is (no `v`) | `https://archive.apache.org/dist/maven/maven-3/V/binaries/apache-maven-V-bin.tar.gz` |
| desktop/dev-k8s | `kubectl_default_version` | `kubectl_versions` | sha256 | `curl -sL https://dl.k8s.io/release/stable.txt` | as-is (**with** `v`) | binary: `https://dl.k8s.io/release/V/bin/linux/amd64/kubectl` — hash from sidecar: `curl -sL https://dl.k8s.io/release/V/bin/linux/amd64/kubectl.sha256` (no download needed). NB: the legacy `storage.googleapis.com/kubernetes-release/...` host no longer serves new releases — use `dl.k8s.io`. |
| desktop/dev-k8s | `kubelogin_default_version` | `kubelogin_versions` | sha256 | `gh api repos/Azure/kubelogin/releases/latest --jq .tag_name` | as-is (**with** `v`) | `https://github.com/Azure/kubelogin/releases/download/V/kubelogin-linux-amd64.zip` |
| desktop/dev-k8s | `k9s_default_version` | `k9s_versions` | sha256 | `gh api repos/derailed/k9s/releases/latest --jq .tag_name` | as-is (**with** `v`) | `https://github.com/derailed/k9s/releases/download/V/k9s_Linux_amd64.tar.gz` |
| desktop/dev-node | `nvm_default_version` | `nvm_versions` | sha256 | `gh api repos/nvm-sh/nvm/releases/latest --jq .tag_name` | strip `v` | `https://raw.githubusercontent.com/nvm-sh/nvm/vV/install.sh` |

Special cases inside the dev-* roles:

- **golang (dev-go), allow-list, no hash.** `golang_default_version` + `golang_versions` is a
  plain YAML **list** of version strings (Go is fetched via godeb from Google, so there is no
  sha we control). Bump `golang_default_version` and **prepend** the new version to the
  `golang_versions` list. Latest: `curl -s 'https://go.dev/VERSION?m=text' | head -1` → strip
  the `go` prefix (`go1.27.1` → `1.27.1`). The separate `golang_godeb_sha256` is a fixed
  installer pin — leave it.
- **maven (dev-java), maven-3 line only.** `maven_base_url` pins the `maven-3` line, so only
  ever bump within 3.x — **do not** jump to Maven 4 (a different line/base_url). Latest 3.x:
  `curl -s https://repo1.maven.org/maven2/org/apache/maven/apache-maven/maven-metadata.xml | grep -oE '<version>3[^<]*</version>' | grep -vE 'alpha|beta|rc' | tail -1`.
  sha512 via the sidecar: `curl -s <artifact-url>.sha512`.
- **vault (dev-generic), non-GitHub + major jumps.** The HashiCorp releases API can return a
  new **major** version (e.g. 1.x → 2.x). Confirm it's GA first —
  `curl -s https://api.releases.hashicorp.com/v1/releases/vault/<V> | jq .is_prerelease`
  must be `false` — and **flag any major jump** in the summary as needing review.
- **kubectl/kubelogin/k9s** store the tag **with** its leading `v` (the URL template uses
  `{{ version }}` directly, not `v{{ version }}`).

## Tier 2 — version-only (bump version, no hash to verify)

These pin a version but do not verify a checksum. Bump the version (and, where noted, add the
matching download-URL map entry). No hashing needed.

- **desktop/gui-apps/defaults/main.yaml** (freecad) — `freecad_defaults.version` + `freecad_versions:` (version → URL
  map). Latest: `gh api repos/FreeCAD/FreeCAD/releases/latest --jq .tag_name`. The AppImage
  asset name is not templatable (embeds a py/conda suffix), so find it:
  `gh release view <tag> -R FreeCAD/FreeCAD --json assets --jq '.assets[].browser_download_url'`
  and pick the Linux x86_64 `.AppImage`. Add a `"<version>": "<url>"` entry to
  `freecad_versions` and bump `version`.
- **desktop/gui-apps/defaults/main.yaml** (prusa-slicer) — `prusa_slicer_defaults.version` + `prusa_slicer_versions:`
  map. Latest: `gh api repos/prusa3d/PrusaSlicer/releases/latest --jq .tag_name` → tag is
  `version_2.x.y`, stored version drops the `version_` prefix. Asset URL via
  `gh release view <tag> -R prusa3d/PrusaSlicer --json assets` → pick the
  `*linux-x64-GTK3-*.AppImage`. Add to `prusa_slicer_versions` + bump `version`.
- **base/smartd** (nanoSmart) — `smartd_defaults.nanoSmart.version` (stored **with** `v`).
  Latest: `gh api repos/ansible-autobott/nanoSmart/releases/latest --jq .tag_name`. URL is
  templated from the version — just bump the field.

> **Note:** kubectl/kubelogin/k9s now live in `desktop/dev-k8s` (per-tool catalogs, hashed) —
> see [Tier 1b](#tier-1b--per-tool-version-catalogs-desktopdev-roles), not here. They were
> moved out of `cli-apps` when the desktop apps were split into the `dev-*` roles.

## Tier 3 — special-case

- **web-base/caddy** — built from source. Bump both:
  - `caddy_defaults.caddy_version` (stored **with** `v`) ←
    `gh api repos/caddyserver/caddy/releases/latest --jq .tag_name`.
  - `caddy_defaults.go_version` (bare, no `go` prefix) ←
    `curl -fsSL 'https://go.dev/VERSION?m=text' | head -1` (e.g. `go1.27.1`) with the `go`
    stripped → `1.27.1`.
- **desktop/linux-desktop (Hack Nerd Font)** — pinned in
  `roles/desktop/linux-desktop/defaults/main.yaml` as top-level `nerd_font_version` (shared
  Nerd Fonts release tag, **with** `v`) + `nerd_font_hack_sha256` (per-font); also not seen
  by the `_checksums:` grep. Latest:
  `gh api repos/ryanoasis/nerd-fonts/releases/latest --jq .tag_name`. Hash the per-font asset:
  `curl -fSL https://github.com/ryanoasis/nerd-fonts/releases/download/V/Hack.tar.xz -o "$f"; sha256sum "$f"`.
  Bump `nerd_font_version` and update the hash.
- **games/minecraft (report-only)** — `minecraft_defaults.version` + `jar_url` (the URL embeds
  an object hash). Latest release + jar come from Mojang's manifest; a server bump is a
  deliberate world/mod-compat decision and the `overviewer` block's `texture_url` tracks the
  MC minor. Report the latest release only:
  `curl -s https://launchermeta.mojang.com/mc/game/version_manifest_v2.json | jq -r .latest.release`.
- **desktop/gui-apps/defaults/main.yaml** (pcsx2, report-only) — `pcsx2_defaults.version` (`v1.6.0`, legacy stable).
  Upstream moved to date-tagged nightly `v2.x` builds with a different asset name; do not
  auto-bump. Report only.
- **security/lynis**, **desktop/vbox-guest** — not pinned (lynis pulls `master.tar.gz`;
  vbox-guest derives the version at runtime). Nothing to do.

## Finish

1. Run `make lint` and confirm it passes; if it flags a file you edited, fix it.
2. **Do not commit or push.** Leave the working tree dirty for the user to review and open the
   PR. (Suggest a branch name like `chore/upgrade-packages` if they're still on `main`.)
3. Print a summary table so it can seed the PR body:

   | Role | Old → New | Hash | Status |
   |---|---|---|---|
   | authelia | 4.39.4 → 4.39.22 | sha256 updated | upgraded |
   | prometheus | 3.4.2 → 3.14.0 | sha256 updated | upgraded |
   | fe26 | 1.0.9 → 1.0.9 | — | up to date |
   | mediawiki | 1.43.0 → 1.44.1 | — | report-only (needs extensions) |
   | pcsx2 | v1.6.0 → v2.x | — | report-only (asset changed) |

   Group by outcome: **upgraded**, **up to date**, **report-only**, **failed** (with the reason,
   e.g. "URL 404 — filename convention changed").

## Discovery cross-check (catch new roles)

The tables are a snapshot. Before finishing, confirm no pinned role was missed — cover
**both** patterns (the Authelia `_checksums:` map *and* the dev-* `_versions:` /
`_default_version` catalogs):

```bash
grep -rlE '_checksums?:'                 roles/*/*/defaults/main.yaml   # Tier 1 (Authelia pattern)
grep -rlE '_versions:|_default_version:' roles/*/*/defaults/main.yaml   # Tier 1b (per-tool catalogs)
```
If a role turns up that isn't in the tables above, derive its handling from its own files —
`checksum: "<algo>:..."` in `tasks/main.yaml` gives the algorithm, the `get_url` `url:` gives
the source and URL template — process it the same way, and flag it in the summary as
**newly discovered — verify**.
