# TODO

## ansible-core 2.21 upgrade follow-ups

Tracking work remaining after the ansible 11 → 14 (ansible-core 2.18 → 2.21) bump.

- [ ] Finish end-to-end Vagrant validation on a **fresh** VM for Debian 13
      (`make vagrant-destroy` + `make vagrant-up`, then `make vagrant-run`). The
      last run reached `ok=788` before the next fix — not yet a clean full pass.
- [ ] Clear remaining ansible-core 2.19 templating fallout as it surfaces:
  - Native types: a whole-value `{{ x | int }}` now stays an `int`; use `| string`
    for strict modules (e.g. `community.general.xml`).
  - Strict undefined: undefined vars in `{% if %}`/conditionals now error
    (dead `run_role_node` guard already removed — watch for more leftovers).
- [ ] (Optional) Add a CI lint gate — `.github/workflows/release.yml` runs no
      `ansible-lint`. The tree currently meets only the `min` profile
      (~1033 strict findings, mostly `fqcn`); consider a lint workflow + cleanup.
- [ ] (Optional) If releasing this upgrade, bump `autobot_version` in
      `roles/base/enroll/defaults/main.yaml` before opening the PR.

## Borgmatic repo-init: key export/fetch logic bug

Found while silencing the `item`-collision warning in
`roles/base-services/borgmatic/tasks/init_repo.yaml` (the warning is fixed — a
`loop_var: backup_item` was added; this underlying logic bug is **not** fixed).

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
