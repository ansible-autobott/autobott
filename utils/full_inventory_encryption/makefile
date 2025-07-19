SHELL := /bin/bash
# adjust if needed
AUTOBOTT := $(shell realpath ../autobott)

default: help;

##@ Secrets
encrypt: ## uses ansible vault to encrypt the secrets
	@if [ ! -e "$(AUTOBOTT)" ]; then \
		echo "Error: Autobott path '$(AUTOBOTT)' does not exist." >&2; \
		exit 1; \
	fi && \
	. "$(AUTOBOTT)/venv/bin/activate" && \
	./utils/vault.sh encrypt

decrypt: ## uses ansible vault to decrypt the secrets
	@if [ ! -e "$(AUTOBOTT)" ]; then \
		echo "Error: Autobott path '$(AUTOBOTT)' does not exist." >&2; \
		exit 1; \
	fi && \
	. "$(AUTOBOTT)/venv/bin/activate" && \
	./utils/vault.sh decrypt

check: ## make sure that all the host_vars are encrypted
	@./utils/vault.sh check

##@ Help
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

