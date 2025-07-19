#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
ROOTDIR=`realpath "$DIR/.."`

# Check that the correct action was provided
ACTION="$1"

if [ "$ACTION" != "encrypt" ] && [ "$ACTION" != "decrypt" ] && [ "$ACTION" != "check" ]; then
  echo "the only accepted actions are encrypt, decrypt or check. exiting..."
  exit 1
fi


## Check if all files in host_vars are encrypted
if [ "$ACTION" == "check" ]; then
  echo "Checking encrypted files..."

  shopt -s globstar
  for d in $ROOTDIR/host_vars/**/*.{yaml,sh,txt}
  do
    if [ -f "$d" ]; then
      echo " $d"
      line=$(head -n 1 "$d")

      if [ "$line" != '$ANSIBLE_VAULT;1.1;AES256' ]; then
          echo "$d is NOT encrypted"
          exit 1
      fi
    fi
  done
  #  all good
  echo "all files are encrypted"
  exit 0
fi



echo ""
PASS_FILE="$ROOTDIR/vault_pass.txt"

if [ ! -f "$PASS_FILE" ]
then
    echo "File \"$PASS_FILE\" does not exists,"
    echo "consider creating the file with the encryption password"
    echo "provide encryption password for dev now:"
    read -sr ENCRYPT_PW
    echo

    if [ -z "$ENCRYPT_PW" ]
    then
      echo "no password provided, exiting"
      exit 1
    fi
    echo "$ENCRYPT_PW" > "$ROOTDIR/tmp_vault_pass"
    PASS_FILE="$ROOTDIR/tmp_vault_pass"
    TO_DELETE="$PASS_FILE"
else
    echo "using encryption password found in: \"$PASS_FILE\" "
fi

if [ "$ACTION" == "encrypt" ]; then
  echo "encrypting files..."
  shopt -s globstar
  for d in $ROOTDIR/host_vars/**/*.{yaml,sh,txt}
  do
    if [ -f "$d" ]; then
      echo " $d"
#        echo "ansible-vault encrypt \"$d\" --vault-password-file=\"$PASS_FILE\""
      ( ansible-vault encrypt "$d" --vault-password-file="$PASS_FILE" )
    fi
  done

elif [ "$ACTION" == "decrypt" ]; then
  echo "decrypting files..."
  shopt -s globstar
  for d in $ROOTDIR/host_vars/**/*.{yaml,sh,txt}
  do
    if [ -f "$d" ]; then
      echo " $d"
#        echo "ansible-vault decrypt \"$d\" --vault-password-file=\"$PASS_FILE\""
      ( ansible-vault decrypt "$d" --vault-password-file="$PASS_FILE" )
    fi
  done
fi

# make sure the tmp pass file is deleted
rm -f "$TO_DELETE"











