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
