# This enables jenv (Java version manager) in the current shell.
# It puts jenv's CLI + shims on PATH and initializes per-shell / per-project
# Java version switching (respects .java-version files).
# This file is written only when 'jenv' is selected in apps_config.

export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
