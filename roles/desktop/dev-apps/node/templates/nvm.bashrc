# This enables nvm in the current shell and add nvm autocompletion
# if emtpy then the ansible "variable linux_desktop_node_nvm" is false
{% if run_role_node %}

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

{%  endif %}