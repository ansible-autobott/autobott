# add bash completion for kubectl
# https://kubernetes.io/docs/tasks/tools/included/optional-kubectl-configs-bash-linux/

source <(kubectl completion bash)
# load additional config file
export KUBECONFIG=~/.kube/config.yaml

# change editor
export KUBE_EDITOR="/usr/bin/joe"

