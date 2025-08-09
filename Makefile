SHELL := /bin/bash

default: help;
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# ======================================================================================

##@ Prepare
prepare: ## Prepare the ansible environment for local executions
	@python3 -m venv ./venv
	@source venv/bin/activate && pip install -r ./requirements.txt
	@echo
	@echo "Don't forget to activate the Venv with 'source venv/bin/activate'"


INV ?= ../inventory/main.yaml


##@ Run
enroll: ## run the enroll tag on a specific host; vars: INV, HOST, ANSIBLE_PASS, ANSIBLE_USER
	@echo "Running with inventory: $(INV)" && \
	. ./venv/bin/activate && \
	if [ -z "$(HOST)" ]; then \
		echo "Error: HOST variable is required!"; \
		exit 1; \
	fi && \
	if [ -z "$(ANSIBLE_USER)" ]; then \
		echo "Error: ANSIBLE_USER variable is required!"; \
		exit 1; \
	fi && \
	if [ -z "$$ANSIBLE_PASS" ]; then \
		echo "Error: ANSIBLE_PASS environment variable is required!"; \
		exit 1; \
	fi && \
	HOST_VAL="-l $(HOST)" && \
	ansible-playbook -i $(INV) -u $(ANSIBLE_USER) -t enroll $$HOST_VAL \
	  --extra-vars "ansible_user=$$ANSIBLE_USER ansible_ssh_pass=$$ANSIBLE_PASS ansible_become_pass=$$ANSIBLE_PASS" \
	  --become autobott.yaml

run: ## run playbook, env Vars: INV=inventory_path, HOST=<host>, TAG=<tag>
	@if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	INV_DIR=$$(dirname "$(INV)") && \
	VAULT_PASS_FILE="$$INV_DIR/vault_pass.txt" && \
	echo "Running with inventory: $(INV)" && \
 	. ./venv/bin/activate && \
	TAG_VAL=$$( [ -n "$$TAG" ] && echo "-t $$TAG" || echo "" ) && 	\
	HOST_VAL=$$( [ -n "$(HOST)" ] && echo "-l $(HOST)" || echo "" ) && \
	VAULT_OPT=$$( [ -f "$$VAULT_PASS_FILE" ] && echo "--vault-password-file=$$VAULT_PASS_FILE" || echo "" ) && \
	echo "Using tag: $$TAG_VAL" && \
	echo "Using host: $$HOST_VAL" && \
	[ -n "$$VAULT_OPT" ] && echo "Using vault password file at $$VAULT_PASS_FILE" || true && \
	ansible-playbook $$VAULT_OPT -i $(INV) $$TAG_VAL $$HOST_VAL autobott.yaml

##@ Secrets
encrypt: ## encrypt secret for the specific inventory, env Vars: INV=inventory_path, KEY=variableName, VALUE=secret
	@if [ -z "$(KEY)" ]; then \
		echo "Error: Missing required parameter 'KEY'" >&2; \
		exit 1; \
	fi && \
	if [ -z "$(VALUE)" ]; then \
		echo "Error: Missing required parameter 'VALUE'" >&2; \
		exit 1; \
	fi && \
	if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	if [ ! -e "$(INV)" ]; then \
		echo "Error: Inventory path '$(INV)' does not exist." >&2; \
		exit 1; \
	fi && \
	. ./venv/bin/activate && \
	SECRET='$(VALUE)' ./utils/vault.sh -a encrypt -i "$(INV)" -k "$(KEY)"

decrypt: ## decrypt vault string; requires INV=inventory path, SECRET='$ANSIBLE_VAULT;1.1;AES256 ...'
	@if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	if [ ! -e "$(INV)" ]; then \
		echo "Error: Inventory path '$(INV)' does not exist." >&2; \
		exit 1; \
	fi && \
	. ./venv/bin/activate && \
	./utils/vault.sh -a decrypt -i "$(INV)"

##@ Vagrant

vagrant-base: ## Bake the base image for vagrant (only needed once)
	@cd vagrant/bake-base/ && ./bake-base-box.sh

# fix included ssh key permissions
fix-ssh-key-perm:
	@stat $(ROOT_DIR)/vagrant/autobott-key > /dev/null
	@echo "changing permissions of key: $(ROOT_DIR)/vagrant/autobott-key"
	@chmod 600  $(ROOT_DIR)/vagrant/autobott-key

vagrant-up: fix-ssh-key-perm ## start the vagrant environment and bootstrap provisioning
	@source ./venv/bin/activate && cd vagrant && vagrant up

vagrant-run: ## run playbook on vagrant, vars: TAG=<tag> (default all)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	if [ -n "$$TAG" ]; then \
		TAG_VAL="-t $$TAG"; \
	else \
		TAG_VAL=""; \
	fi && \
	echo "Using tag: $$TAG_VAL" && \
	ansible-playbook autobott.yaml \
		-i inventory/vagrant.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		--extra-vars "ansible_ssh_user='ans'" \
		$$TAG_VAL

vagrant-run-verbose: ## run playbook on vagrant in verbose mode, vars: TAG=<tag>, HOST=<host> note: requires enroll
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	if [ -n "$$TAG" ]; then \
		TAG_VAL="-t $$TAG"; \
	else \
		TAG_VAL=""; \
	fi && \
	echo "Using tag: $$TAG_VAL" && \
	ansible-playbook autobott.yaml -vvv \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		$$TAG_VAL

vagrant-run-short: ## run short playbook on vagrant: only run tags that generally require updates or config changes
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook autobott.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" -t linux-upgrade

vagrant-test: ## run validation tests
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook test.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'"

vagrant-destroy: ## Delete all vagrant VMs
	@cd vagrant && vagrant destroy -f

vagrant-ssh-renew: fix-ssh-key-perm ## remove and re-add previous vagrant ssh entries to known hosts
	@ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "[127.0.0.1]:2222" || true
	#@ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "[127.0.0.1]:2200" || true
	@ssh ans@127.0.0.1 -p 2222 || true
	#@ssh ans@127.0.0.1 -p 2200 || true

vagrant-snapshot-save: ## take a snapshot of the vagrant state
	@cd vagrant && \
	vagrant snapshot save ansible-autobott-linux-debian-12 automated-snapshot --force

vagrant-snapshot-restore: ## restore to snapshot of the vagrant state
	@cd vagrant && \
	vagrant snapshot restore ansible-autobott-linux-debian-12 automated-snapshot

##@ Test
lint: ## run ansible lint
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -s -v

lint-fix: ## run ansible lint
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -s -v --fix

##@ Help
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
