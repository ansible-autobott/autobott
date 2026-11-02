# {{ ansible_managed }}
# AutoBott linux-basic role — system ssh agent (linux_basic.ssh.system_agent).
# Keeps a working agent that is already set (forwarded from another machine, a desktop
# keyring, ...); otherwise points SSH_AUTH_SOCK at the user's system agent, the same
# fallback /etc/ssh/ssh_config.d/90-autobott-ssh-agent.conf gives ssh in every shell.

if [ -n "$SSH_AUTH_SOCK" ]; then
    # exit code 2: nothing listens there (e.g. the forwarding session has ended)
    ssh-add -l >/dev/null 2>&1
    [ $? -eq 2 ] && unset SSH_AUTH_SOCK
fi
if [ -z "$SSH_AUTH_SOCK" ] && [ -S "/run/user/$UID/openssh_agent" ]; then
    export SSH_AUTH_SOCK="/run/user/$UID/openssh_agent"
fi
