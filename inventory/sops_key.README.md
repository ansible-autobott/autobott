# sops_key — bundled sample age key (committed on purpose)

`inventory/sops_key` is the age private key sops uses to decrypt this inventory's
`*.sops.yaml` secrets. The Makefile derives its path from the inventory:
`<inventory-dir>/sops_key`.

It is **committed to git deliberately**, because this is the project's bundled
*example* inventory and the key only guards throwaway sample secrets
(e.g. `ans_sudo_pw: banana`).

> ⚠️ In a real inventory `sops_key` is **gitignored** — never commit a real
> private key. See the repo-root `.sops.yaml` for how recipients work.

## Recreating it

From the autobott repo:

```bash
make age-key INV=inventory/vagrant.yaml     # writes inventory/sops_key, prints the public key
```

or directly:

```bash
age-keygen -o inventory/sops_key
```

Then add the printed public key (`age1...`) to the `age:` recipients in the
repo-root `.sops.yaml` and re-encrypt: `make rekey INV=inventory/vagrant.yaml`.
