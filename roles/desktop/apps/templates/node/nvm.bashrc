# This enables nvm in the current shell and adds nvm autocompletion.
# This file is written only when 'node' is selected in apps_config
# (the uninstall path removes it otherwise).

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
