#!/bin/bash
set -e
# Ansible-managed cron job for Borgmatic profile: {{ item.name }}

# Run borgmatic with specific config
/usr/local/bin/borgmatic --config "/etc/borgmatic.d/{{ item.name }}.yaml" --verbosity 1 > /dev/null
