#!/usr/bin/env bash

set -euo pipefail

print_help() {
  echo "Usage: $0 -a <action> -i <inventory> [-k <key>]"
  echo
  echo "Options:"
  echo "  -a action      Action to perform: encrypt or decrypt"
  echo "  -i inventory   Path to inventory file or directory"
  echo "  -k key        Key name for encryption (required for encrypt)"
  echo "  -h            Show this help message"
  echo
  echo "Note: Secret is passed via environment variable SECRET."
  exit 1
}

validate_secret_prefix() {
  if [[ "$SECRET" == \$ANSIBLE_VAULT* ]]; then
    # Correct prefix, do nothing
    :
  elif [[ "$SECRET" == NSIBLE_VAULT* ]]; then
    echo "Warning: SECRET is missing leading '\$'. Fixing it."
    SECRET="\$A${SECRET}"
  else
    echo "Error: SECRET does not start with '\$ANSIBLE_VAULT' or 'NSIBLE_VAULT'. Cannot decrypt." >&2
    echo "make sure to define secret with single quote SECRET='\$ANSIBLE_VAULT... ' "
    exit 1
  fi
}


# Initialize variables
action=""
inventory=""
key=""

# Parse options
while getopts "a:i:k:h" opt; do
  case "$opt" in
    a) action=$OPTARG ;;
    i) inventory=$OPTARG ;;
    k) key=$OPTARG ;;
    h) print_help ;;
    *) print_help ;;
  esac
done

# Validate mandatory params
if [[ -z "$action" || -z "$inventory" ]]; then
  echo "Error: -a (action) and -i (inventory) are required."
  print_help
fi

if [[ "$action" == "encrypt" && -z "$key" ]]; then
  echo "Error: -k (key) is required for encryption."
  print_help
fi

if [[ -z "${SECRET:-}" ]]; then
  echo "Error: SECRET environment variable is not set."
  exit 1
fi

if [[ ! -e "$inventory" ]]; then
  echo "Error: Inventory path '$inventory' does not exist." >&2
  exit 1
fi

inv_dir="$(dirname "$inventory")"
vault_pass_file="$inv_dir/vault_pass.txt"

case "$action" in
  encrypt)
    echo "Encrypting secret with inventory: $inventory"
    if [[ -f "$vault_pass_file" ]]; then
      echo "Using vault password file at $vault_pass_file"
      ansible-vault encrypt_string "$SECRET" --name "$key" --vault-password-file "$vault_pass_file"
    else
      echo "Vault password file not found. Proceeding without it."
      ansible-vault encrypt_string "$SECRET" --name "$key"
    fi
    ;;
  decrypt)
    validate_secret_prefix
    echo "Decrypting secret with inventory: $inventory"
    if [[ -f "$vault_pass_file" ]]; then
      echo "Using vault password file at $vault_pass_file"
      echo "========================"
      echo -e "$SECRET" |  tr -d ' ' | ansible-vault decrypt --vault-password-file "$vault_pass_file" --output=-  2> >(grep -v "Decryption successful" >&2)
      echo
      echo "========================"
    else
      echo "Vault password file not found. Proceeding without it."
      echo "========================"
      echo -e "$SECRET" |  tr -d ' ' | ansible-vault decrypt --output=-
      echo
      echo "========================"
    fi
    ;;
  *)
    echo "Error: Unknown action '$action'. Supported: encrypt, decrypt."
    print_help
    ;;
esac
