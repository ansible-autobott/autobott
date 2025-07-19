# Secrets

To manage your secrets in your inventory ansible has many integrations, here we are going to document two methods
that are based on ansible-vault to encrypt the secrets into the inventory git repository.

if you don't feel conformable with this approach check for ansible alternatives.


## Decryption key
for simplicity, after cloning, you can create a file in the same folder of your inventory called "vault_pass.txt" 
(this is git ignored) with your decryption key; then the make targets from 
Autobott will try to use this file content as key. 

## Inline Secrets

This approach stores every secret as an individually encrypted var, e.g.

```yaml
my_var: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  6637336539353966...
```

While strictly not needed, we still recommend to keep a secrets.yaml in your inventory for every host to put all the
secrets in one place, and then reference it from your host inventory e.g.

```yaml
# host_vars/my_host/secrets.yaml
secrets:
  ans_sudo_pw: !vault |
    $ANSIBLE_VAULT;1.1;AES256
    39373364333438363938626536393437363...
   
  users:
    my user:
      other_pw: !vault |
        $ANSIBLE_VAULT;1.1;AES256
        39373364333438363938626536393437363...

# host_vars/my_host/base.yaml
ansible_become_pass:  "{{ secrets.ans_sudo_pw }}"
```

### Encrypting values

Autobott contains a convenient make utility to encrypt values 

```bash
make encrypt KEY=ans_sudo_pw VALUE="MySecret" INV=/path/to/inventory.yaml
```
output: 
```bash
Encrypting secret with inventory: /path/to/inventory.yaml
Using vault password file at /path/to/vault_pass.txt
Encryption successful
ans_sudo_pw: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          39373364333438363938626536393437363...
```

this can then copied into your inventory

### Decrypting values


Autobott also contains a convenient make utility to decrypt a value

```bash
# note, the toolong expects the ENV var SECRET
# IMPORTANT export using single quotes!
export SECRET='$ANSIBLE_VAULT;1.1;AES256
          64343738356638653038343163633933...'
make decrypt  INV=/path/to/inventory.yaml
```
output:
```bash
Decrypting secret with inventory: /path/to/inventory.yaml
Using vault password file at /path/to/vault_pass.txt
========================
apple
========================
```

## Full inventory 

Full inventory encryption will encrypt all the inventory yaml files in your inventory repository.

The drawback of this approach is that it does not play nicely with git history, since every time you make a change
all the files are encrypted again.

This approach also depends on extra tooling that you will need to add to your inventory (and execute from the 
inventory directory instead of Autobott)


### Setup
1. Make sure you have created a vault_pass.txt with your encryption key.
2. copy from all the files from utils/full_inventory_encryption into your inventory root.
3. Adjust the path of AUTOBOTT in the makefile to point to Autobott install dir.
4. copy the hook to ensure never commit plaintext files: copy utils/pre-commit into .git/hooks/pre-commit


### check current status

Ensure all the files are encrypted, fill exit if it finds one that is not.
```bash
# cd <your inventory>
make check
```
output
```
Checking encrypted files...
 /my/inventory/host_vars/host/base-services.yaml
/my/inventory/host_vars/host/base-services.yaml is NOT encrypted
make: *** [makefile:25: check] Error 1
```


### Encrypting files

```bash
# cd <your inventory>
make encrypt
```
output
```
using encryption password found in: "/my/inventory/host_vars/host/vault_pass.txt" 
encrypting files...
 /my/inventory/host_vars/host/host_vars/host/base-services.yaml
Encryption successful
 /my/inventory/host_vars/host/host_vars/host/base.yaml
...

```

### Decrypting files

```bash
# cd <your inventory>
make decrypt
```
output
```
using encryption password found in: "/my/inventory/host_vars/host/vault_pass.txt" 
decrypting files...
 /my/inventory/host_vars/host/host_vars/host/base-services.yaml
Decryption successful
 /my/inventory/host_vars/host/host_vars/host/base.yaml
...
