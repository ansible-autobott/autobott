SHELL := /bin/bash

default: help;
mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))
ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

# ======================================================================================

##@ Prepare
SOPS_VERSION ?= v3.13.3

# Interpreter used to build ./venv, defaulting to the system python3 (not pinned).
# 'make prepare' recreates the venv whenever it was built for a different Python
# version than the current one (e.g. after an OS upgrade bumps python3). Override
# only for a one-off, e.g. 'make prepare PYTHON=python3.12'.
PYTHON ?= python3

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

prepare: check-tools ## Prepare the ansible environment (recreates ./venv if it's incompatible with the current Python)
	@command -v $(PYTHON) >/dev/null 2>&1 || { \
		echo "Error: '$(PYTHON)' not found; install it or pass PYTHON=..., e.g. 'make prepare PYTHON=python3'." >&2; exit 1; }
	@cur=$$($(PYTHON) -c 'import sys; print("%d.%d" % sys.version_info[:2])'); \
	if [ -f ./venv/pyvenv.cfg ]; then \
		venvver=$$(sed -n 's/^version *= *\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' ./venv/pyvenv.cfg); \
		if [ "$$venvver" != "$$cur" ]; then \
			echo ">> ./venv was built for Python $${venvver:-unknown}, current $(PYTHON) is $$cur; recreating"; \
			rm -rf ./venv; \
		fi; \
	elif [ -d ./venv ]; then \
		echo ">> ./venv is incomplete (no pyvenv.cfg); recreating"; \
		rm -rf ./venv; \
	fi; \
	if [ ! -d ./venv ]; then \
		echo ">> creating ./venv with $(PYTHON) ($$cur)"; \
		$(PYTHON) -m venv ./venv; \
	fi
	@source venv/bin/activate && pip install -r ./requirements.txt
	@source venv/bin/activate && ansible-galaxy collection install community.sops
	@echo
	@echo "Don't forget to activate the Venv with 'source venv/bin/activate'"


INV ?= inventory/vagrant.yaml
VER ?= 13


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

# 'run-local' reads INV/HOST/TAG (and optional EXTRA_ARGS / SOPS_AGE_KEY_FILE) from a
# git-ignored env file so you don't retype them on every 'make run'. Copy
# run-local.env.example -> run-local.env and edit it. Override the file: RUN_LOCAL_FILE=<path>.
# Any of INV/HOST/TAG/EXTRA_ARGS/SOPS_AGE_KEY_FILE passed on the command line
# (e.g. 'make run-local TAG=role_docker') takes precedence over the env file.
RUN_LOCAL_FILE ?= run-local.env

run-local: ## run playbook with INV/HOST/TAG from a git-ignored env file (default: run-local.env)
	@if [ ! -f "$(RUN_LOCAL_FILE)" ]; then \
		echo "Error: '$(RUN_LOCAL_FILE)' not found." >&2; \
		echo "       Create it from the template:  cp run-local.env.example $(RUN_LOCAL_FILE)" >&2; \
		exit 1; \
	fi
	@_INV_CLI="$$INV"; _HOST_CLI="$$HOST"; _TAG_CLI="$$TAG"; _EXTRA_CLI="$$EXTRA_ARGS"; _SOPS_CLI="$(SOPS_AGE_KEY_FILE_CLI)"; \
	unset SOPS_AGE_KEY_FILE; \
	set -a; . "$(CURDIR)/$(RUN_LOCAL_FILE)"; set +a; \
	INV="$${_INV_CLI:-$$INV}"; HOST="$${_HOST_CLI:-$$HOST}"; TAG="$${_TAG_CLI:-$$TAG}"; \
	EXTRA_ARGS="$${_EXTRA_CLI:-$$EXTRA_ARGS}"; SOPS_AGE_KEY_FILE="$${_SOPS_CLI:-$$SOPS_AGE_KEY_FILE}"; \
	if [ -z "$$INV" ]; then \
		echo "Error: 'INV' is not set in $(RUN_LOCAL_FILE)" >&2; \
		exit 1; \
	fi; \
	if [ -z "$$SOPS_AGE_KEY_FILE" ]; then \
		if [ -d "$$INV" ]; then SOPS_AGE_KEY_FILE="$$INV/sops_key"; \
		else SOPS_AGE_KEY_FILE="$$(dirname "$$INV")/sops_key"; fi; \
	fi; \
	export SOPS_AGE_KEY_FILE; \
	echo "Running with inventory: $$INV" && \
	echo "Using sops key:         $$SOPS_AGE_KEY_FILE" && \
	. ./venv/bin/activate && \
	TAG_VAL=$$( [ -n "$$TAG" ] && echo "-t $$TAG" || echo "" ) && \
	HOST_VAL=$$( [ -n "$$HOST" ] && echo "-l $$HOST" || echo "" ) && \
	echo "Using tag:  $$TAG_VAL" && \
	echo "Using host: $$HOST_VAL" && \
	ansible-playbook -i "$$INV" $$TAG_VAL $$HOST_VAL $$EXTRA_ARGS autobott.yaml


##@ Secrets

# The age private key sops uses lives in the inventory's own directory, as
# <inventory-dir>/sops_key. INV may be the inventory DIRECTORY (key goes inside
# it) or an inventory FILE (key goes in the file's directory). Or set
# SOPS_AGE_KEY_FILE=<path> to point directly at a key file.
sops_key_dir := $(if $(wildcard $(INV)/.),$(abspath $(INV))/,$(dir $(abspath $(INV))))
export SOPS_AGE_KEY_FILE ?= $(sops_key_dir)sops_key

# The default export above always sets SOPS_AGE_KEY_FILE (derived from the sample
# INV), so run-local can't tell it apart from a user-supplied key. Capture the
# value ONLY when it actually came from the command line, so a bare 'make
# run-local' derives the key from the env-file INV instead of this default.
SOPS_AGE_KEY_FILE_CLI := $(if $(filter command line,$(origin SOPS_AGE_KEY_FILE)),$(SOPS_AGE_KEY_FILE),)

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
	@cd vagrant/bake-base/ && ./bake-base-box.sh 13
# TODO: Debian 14 (forky) placeholder -- uncomment once its base box exists:
#	@cd vagrant/bake-base/ && ./bake-base-box.sh 14

# fix included ssh key permissions
fix-ssh-key-perm:
	@stat $(ROOT_DIR)/vagrant/autobott-key > /dev/null
	@echo "changing permissions of key: $(ROOT_DIR)/vagrant/autobott-key"
	@chmod 600  $(ROOT_DIR)/vagrant/autobott-key

vagrant-up: fix-ssh-key-perm ## start the vagrant environment and bootstrap provisioning, vars: VER=<13> (default 13)
	@source ./venv/bin/activate && cd vagrant && vagrant up ansible-autobott2-linux-debian-$(VER)

.PHONY: check-vagrant-running
check-vagrant-running: # fail early (with a clear message) if the target VM (VER) isn't running
	@state=$$(VAGRANT_CWD=vagrant vagrant status --machine-readable ansible-autobott2-linux-debian-$(VER) 2>/dev/null | awk -F, '$$3 == "state" { print $$4 }'); \
	if [ "$$state" != "running" ]; then \
		echo "Error: Vagrant VM 'ansible-autobott2-linux-debian-$(VER)' is '$${state:-unknown}', not running." >&2; \
		echo "       Start it first:  make vagrant-up VER=$(VER)" >&2; \
		exit 1; \
	fi

vagrant-run: check-vagrant-running ## run playbook on vagrant, vars: TAG=<tag> (default all), VER=<13> (default 13)
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

vagrant-run-verbose: ## run playbook on vagrant in verbose mode, vars: TAG=<tag>, VER=<13> (default 13)
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

vagrant-run-short: ## run short playbook on vagrant: only run tags that generally require updates or config changes, vars: VER=<13> (default 13)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook autobott.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER) \
		-t linux-upgrade

vagrant-test: ## run validation tests, vars: VER=<13> (default 13)
	@ssh-add ./vagrant/autobott-key # used in sftp connections
	@. ./venv/bin/activate && \
	ansible-playbook test.yaml \
		-i vagrant/.vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory \
		-i inventory/vagrant.yaml \
		--extra-vars "ansible_ssh_user='ans'" \
		-l ansible-autobott2-linux-debian-$(VER)

vagrant-destroy: ## Delete all vagrant VMs
	@cd vagrant && vagrant destroy -f

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
# Known violations are baselined in roles/.ansible-lint-ignore: `lint` (also run
# by CI) reports them as warnings and fails only on new ones. Not strict (-s):
# strict turns the baselined warnings back into failures.
lint: ## run ansible lint; fails only on violations not in the baseline (same as CI)
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -v

lint-all: ## run strict ansible lint ignoring the baseline (full cleanup list)
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -s -v -i /dev/null

lint-fix: ## auto-fix ansible lint violations where possible
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -s -v --fix

lint-baseline: ## regenerate the lint baseline (roles/.ansible-lint-ignore) from the current tree
	@. ./venv/bin/activate && \
	cd roles && \
	ansible-lint -s -q --generate-ignore || true

##@ Help
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
