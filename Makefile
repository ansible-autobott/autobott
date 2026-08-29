SHELL := /bin/bash

default: help;
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# ======================================================================================

##@ Prepare
SOPS_VERSION ?= v3.13.3

check-tools: ## Verify sops & age are installed; offer to install them if missing
	@missing=""; \
	for tool in sops age; do \
		command -v $$tool >/dev/null 2>&1 || missing="$$missing $$tool"; \
	done; \
	if [ -z "$$missing" ]; then \
		echo "Required tools found: sops, age."; \
		exit 0; \
	fi; \
	echo "Missing required tool(s):$$missing"; \
	if [ ! -t 0 ]; then \
		echo "Non-interactive shell; cannot prompt. Install manually:" >&2; \
		echo "  age  -> sudo apt install age" >&2; \
		echo "  sops -> https://github.com/getsops/sops/releases ($(SOPS_VERSION) .deb)" >&2; \
		exit 1; \
	fi; \
	read -r -p "Install the missing tool(s) now? [y/N] " ans; \
	case "$$ans" in \
		[yY]|[yY][eE][sS]) ;; \
		*) echo "Aborted. Install the tool(s) and re-run 'make prepare'."; exit 1 ;; \
	esac; \
	for tool in $$missing; do \
		case "$$tool" in \
			age) \
				echo ">> Installing age via apt ..."; \
				sudo apt-get update && sudo apt-get install -y age || exit 1; \
				;; \
			sops) \
				ver="$(SOPS_VERSION)"; arch=$$(dpkg --print-architecture); \
				deb="sops_$${ver#v}_$${arch}.deb"; \
				url="https://github.com/getsops/sops/releases/download/$${ver}/$${deb}"; \
				echo ">> Installing sops $${ver} ($${arch}) from GitHub releases ..."; \
				tmp=$$(mktemp -d); \
				if command -v curl >/dev/null 2>&1; then \
					curl -fLo "$$tmp/$$deb" "$$url"; \
				elif command -v wget >/dev/null 2>&1; then \
					wget -qO "$$tmp/$$deb" "$$url"; \
				else \
					echo "Error: need curl or wget to download sops." >&2; rm -rf "$$tmp"; exit 1; \
				fi && sudo apt-get install -y "$$tmp/$$deb" || { rm -rf "$$tmp"; echo "Error: sops install failed." >&2; exit 1; }; \
				rm -rf "$$tmp"; \
				;; \
		esac; \
	done; \
	for tool in sops age; do \
		command -v $$tool >/dev/null 2>&1 || { echo "Error: $$tool still not found after install." >&2; exit 1; }; \
	done; \
	echo "All required tools installed."

prepare: check-tools ## Prepare the ansible environment for local executions
	@python3 -m venv ./venv
	@source venv/bin/activate && pip install -r ./requirements.txt
	@source venv/bin/activate && ansible-galaxy collection install community.sops
	@echo
	@echo "Don't forget to activate the Venv with 'source venv/bin/activate'"


INV ?= inventory/vagrant.yaml
VER ?= 12


##@ Run
enroll: ## run the enroll tag on a specific host; vars: INV, HOST, ANSIBLE_PASS (optional), ANSIBLE_USER
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
	if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	HOST_VAL="-l $(HOST)" && \
	EXTRA_VARS="ansible_user=$$ANSIBLE_USER" && \
	if [ -n "$$ANSIBLE_PASS" ]; then \
		EXTRA_VARS="$$EXTRA_VARS ansible_ssh_pass=$$ANSIBLE_PASS ansible_become_pass=$$ANSIBLE_PASS"; \
	fi && \
	ansible-playbook -i $(INV) -u $(ANSIBLE_USER) -t enroll $$HOST_VAL \
	  --extra-vars "$$EXTRA_VARS" \
	  --become autobott.yaml

run: ## run playbook, env Vars: INV=inventory_path, HOST=<host>, TAG=<tag>
	@if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	echo "Running with inventory: $(INV)" && \
 	. ./venv/bin/activate && \
	TAG_VAL=$$( [ -n "$$TAG" ] && echo "-t $$TAG" || echo "" ) && 	\
	HOST_VAL=$$( [ -n "$(HOST)" ] && echo "-l $(HOST)" || echo "" ) && \
	echo "Using tag: $$TAG_VAL" && \
	echo "Using host: $$HOST_VAL" && \
	ansible-playbook -i $(INV) $$TAG_VAL $$HOST_VAL autobott.yaml

run-verbose: ## run playbook, env Vars: INV=inventory_path, HOST=<host>, TAG=<tag>
	@if [ -z "$(INV)" ]; then \
		echo "Error: Missing required parameter 'INV'" >&2; \
		exit 1; \
	fi && \
	echo "Running with inventory: $(INV)" && \
 	. ./venv/bin/activate && \
	TAG_VAL=$$( [ -n "$$TAG" ] && echo "-t $$TAG" || echo "" ) && 	\
	HOST_VAL=$$( [ -n "$(HOST)" ] && echo "-l $(HOST)" || echo "" ) && \
	echo "Using tag: $$TAG_VAL" && \
	echo "Using host: $$HOST_VAL" && \
	ansible-playbook -vvv -i $(INV) $$TAG_VAL $$HOST_VAL autobott.yaml


##@ Secrets

# The age private key sops uses lives in the inventory's own directory, as
# <inventory-dir>/sops_key. INV may be the inventory DIRECTORY (key goes inside
# it) or an inventory FILE (key goes in the file's directory). Or set
# SOPS_AGE_KEY_FILE=<path> to point directly at a key file.
sops_key_dir := $(if $(wildcard $(INV)/.),$(abspath $(INV))/,$(dir $(abspath $(INV))))
export SOPS_AGE_KEY_FILE ?= $(sops_key_dir)sops_key

age-key: check-tools ## create the age key for an EXTERNAL inventory (<inv-dir>/sops_key); requires INV (not the in-repo sample), never overwrites
	@if [ ! -e "$(INV)" ]; then \
		echo "Error: inventory '$(INV)' not found — pass INV=<inventory_path>." >&2; exit 1; \
	fi
	@if [ -n "$(filter $(ROOT_DIR)/%,$(abspath $(INV)))" ]; then \
		echo "Error: refusing to create a key for an in-repo inventory." >&2; \
		echo "       age-key is for external inventories: INV=<path outside this repo>." >&2; \
		echo "       The bundled inventory/sops_key is committed as an example." >&2; \
		exit 1; \
	fi
	@if [ -f "$(SOPS_AGE_KEY_FILE)" ]; then \
		echo "Error: key already exists at $(SOPS_AGE_KEY_FILE) — refusing to overwrite." >&2; exit 1; \
	fi
	@echo "Creating age key at $(SOPS_AGE_KEY_FILE) ..."
	@mkdir -p "$(dir $(SOPS_AGE_KEY_FILE))"
	@age-keygen -o "$(SOPS_AGE_KEY_FILE)"
	@chmod 600 "$(SOPS_AGE_KEY_FILE)"
	@echo "Done. Add this public key to your .sops.yaml recipients:"
	@grep 'public key:' "$(SOPS_AGE_KEY_FILE)"

seal-secrets: ## first-time encrypt a plaintext secrets.sops.yaml in place (migration); vars: INV=inventory_path, HOST=hostname
	@if [ ! -e "$(INV)" ]; then echo "Error: inventory '$(INV)' not found (pass INV=<inventory_path>)" >&2; exit 1; fi
	@if [ -z "$(HOST)" ]; then echo "Error: Missing required parameter 'HOST'" >&2; exit 1; fi
	cd $(sops_key_dir) && sops -e -i host_vars/$(HOST)/secrets.sops.yaml

edit-secrets: ## edit a host's sops secrets in your editor; vars: INV=inventory_path, HOST=hostname
	@if [ ! -e "$(INV)" ]; then echo "Error: inventory '$(INV)' not found (pass INV=<inventory_path>)" >&2; exit 1; fi
	@if [ -z "$(HOST)" ]; then echo "Error: Missing required parameter 'HOST'" >&2; exit 1; fi
	@if [ ! -f "$(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" ]; then echo "Error: sops file not found: $(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" >&2; exit 1; fi
	@if ! sops filestatus "$(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" 2>/dev/null | grep -q '"encrypted":true'; then echo "Error: $(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml is not sops-encrypted — seal it first: make seal-secrets INV=$(INV) HOST=$(HOST)" >&2; exit 1; fi
	cd $(sops_key_dir) && sops host_vars/$(HOST)/secrets.sops.yaml

edit-secrets-kate: ## edit a host's sops secrets in Kate (blocking GUI editor); vars: INV=inventory_path, HOST=hostname
	@if [ ! -e "$(INV)" ]; then echo "Error: inventory '$(INV)' not found (pass INV=<inventory_path>)" >&2; exit 1; fi
	@if [ -z "$(HOST)" ]; then echo "Error: Missing required parameter 'HOST'" >&2; exit 1; fi
	@if [ ! -f "$(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" ]; then echo "Error: sops file not found: $(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" >&2; exit 1; fi
	@if ! sops filestatus "$(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml" 2>/dev/null | grep -q '"encrypted":true'; then echo "Error: $(sops_key_dir)host_vars/$(HOST)/secrets.sops.yaml is not sops-encrypted — seal it first: make seal-secrets INV=$(INV) HOST=$(HOST)" >&2; exit 1; fi
	cd $(sops_key_dir) && EDITOR='kate -b' sops host_vars/$(HOST)/secrets.sops.yaml

view-secrets: ## decrypt & print a host's sops secrets; vars: INV=inventory_path, HOST=hostname
	@if [ ! -e "$(INV)" ]; then echo "Error: inventory '$(INV)' not found (pass INV=<inventory_path>)" >&2; exit 1; fi
	@if [ -z "$(HOST)" ]; then echo "Error: Missing required parameter 'HOST'" >&2; exit 1; fi
	cd $(sops_key_dir) && sops -d host_vars/$(HOST)/secrets.sops.yaml

rekey: ## re-encrypt all sops secrets after editing .sops.yaml recipients; vars: INV=inventory_path
	@if [ ! -e "$(INV)" ]; then echo "Error: inventory '$(INV)' not found (pass INV=<inventory_path>)" >&2; exit 1; fi
	cd $(sops_key_dir) && find host_vars -name 'secrets.sops.yaml' -exec sops updatekeys -y {} \;


##@ Vagrant

vagrant-base: ## Bake the base images for all debian versions (only needed once)
	@cd vagrant/bake-base/ && ./bake-base-box.sh 12
	@cd vagrant/bake-base/ && ./bake-base-box.sh 13

# fix included ssh key permissions
fix-ssh-key-perm:
	@stat $(ROOT_DIR)/vagrant/autobott-key > /dev/null
	@echo "changing permissions of key: $(ROOT_DIR)/vagrant/autobott-key"
	@chmod 600  $(ROOT_DIR)/vagrant/autobott-key

vagrant-up: fix-ssh-key-perm ## start the vagrant environment and bootstrap provisioning, vars: VER=<12|13> (default 12)
	@source ./venv/bin/activate && cd vagrant && vagrant up ansible-autobott2-linux-debian-$(VER)

vagrant-run: ## run playbook on vagrant, vars: TAG=<tag> (default all), VER=<12|13> (default 12)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@mkdir -p logs
	@. ./venv/bin/activate && \
	if [ -n "$$TAG" ]; then \
		TAG_VAL="-t $$TAG"; \
	else \
		TAG_VAL=""; \
	fi && \
	TIMESTAMP="$$(date +%Y%m%d-%H%M%S)" && \
	RAW_LOG="/tmp/ansible-vagrant-$$TIMESTAMP.log" && \
	LOG_FILE="logs/vagrant-changed-$$TIMESTAMP.log" && \
	echo "Using tag: $$TAG_VAL" && \
	echo "Using debian version: $(VER)" && \
	echo "Logging to: $$LOG_FILE" && \
	ANSIBLE_FORCE_COLOR=1 ansible-playbook autobott.yaml \
		-i inventory/vagrant.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER) \
		$$TAG_VAL 2>&1 | tee >(sed 's/\x1b\[[0-9;]*m//g' | awk '/^TASK \[/{task=$$0; in_dep=0; next} /\[DEPRECATION WARNING\]/{print task; in_dep=1; print; next} in_dep && /^(ok:|changed:|skipping:|failed:|PLAY )/{in_dep=0} in_dep{print; next} /^changed:/{print task; print}' > "$$LOG_FILE"); \
	wait

vagrant-run-verbose: ## run playbook on vagrant in verbose mode, vars: TAG=<tag>, VER=<12|13> (default 12)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	if [ -n "$$TAG" ]; then \
		TAG_VAL="-t $$TAG"; \
	else \
		TAG_VAL=""; \
	fi && \
	echo "Using tag: $$TAG_VAL" && \
	echo "Using debian version: $(VER)" && \
	ansible-playbook autobott.yaml -vvv \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER) \
		$$TAG_VAL

vagrant-run-short: ## run short playbook on vagrant: only run tags that generally require updates or config changes, vars: VER=<12|13> (default 12)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook autobott.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER) \
		-t linux-upgrade

vagrant-test: ## run validation tests, vars: VER=<12|13> (default 12)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook test.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER)

vagrant-destroy: ## Delete all vagrant VMs
	@cd vagrant && vagrant destroy -f

vagrant-ssh-renew: fix-ssh-key-perm ## remove and re-add previous vagrant ssh entries to known hosts
	@ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "[127.0.0.1]:2222" || true
	#@ssh-keygen -f "$(HOME)/.ssh/known_hosts" -R "[127.0.0.1]:2200" || true
	@ssh ans@127.0.0.1 -p 2222 || true
	#@ssh ans@127.0.0.1 -p 2200 || true

vagrant-snapshot-save: ## take a snapshot of the vagrant state
	@cd vagrant && \
	vagrant snapshot save ansible-autobott2-linux-debian-13 automated-snapshot --force

vagrant-snapshot-restore: ## restore to snapshot of the vagrant state
	@cd vagrant && \
	vagrant snapshot restore ansible-autobott2-linux-debian-13 automated-snapshot


##@ Release

.PHONY: check-git-clean
check-git-clean: # check if git repo is clean
	@git diff --quiet

.PHONY: check-branch
check-branch:
	@current_branch=$$(git symbolic-ref --short HEAD) && \
	if [ "$$current_branch" != "main" ]; then \
		echo "Error: You are on branch '$$current_branch'. Please switch to 'main'."; \
		exit 1; \
	fi

check-autobott-version:
	@[ "${version}" ] || ( echo ">> version is not set, usage: make tag version=\"v1.2.3\" "; exit 1 )
	@AUTOBOT_VERSION=$$(grep -E '^autobot_version:' ./roles/base/enroll/defaults/main.yaml | awk '{print $$2}') && \
	if [ "$$AUTOBOT_VERSION" != "$(version)" ]; then \
		echo "Error: autobot_version ($$AUTOBOT_VERSION) does not match the release version ($(version))"; \
		exit 1; \
	else \
		echo "autobot_version ($$AUTOBOT_VERSION) matches release version ($(version))"; \
	fi

.PHONY: tag
tag: check-branch check-git-clean check-autobott-version ## tag a release and push it; the release workflow then publishes it on GitHub. Usage: make tag version="v1.2.3"
	@[ "${version}" ] || ( echo ">> version is not set, usage: make tag version=\"v1.2.3\" "; exit 1 )
	@git tag -d $(version) || true
	@git tag -a $(version) -m "Release version: $(version)"
	@git push --delete origin $(version) || true
	@git push origin $(version) || true

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
