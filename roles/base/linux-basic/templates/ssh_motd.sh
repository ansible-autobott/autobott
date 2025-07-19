#!/bin/bash

# ANSI colors
YELLOW="\033[1;33m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
RESET="\033[0m"

# System Info
HOSTNAME=$(hostname)
IP=$(hostname -I | awk '{print $1}')
UPTIME=$(uptime -p)
OS=$(lsb_release -ds)
KERNEL=$(uname -r)
USERS=$(who | wc -l)
DISK=$(df -h / | awk 'NR==2 {print $5 " used of " $2}')

# Info block
echo -e "${GREEN}Welcome to ${HOSTNAME} (${IP})${RESET}"
echo -e "${GREEN}This machine is managed by Autobott${RESET}"
echo -e "${CYAN}OS:     ${OS}"
echo -e "Kernel: ${KERNEL}"
echo -e "Uptime: ${UPTIME}"
echo -e "Users:  ${USERS} logged in"
echo -e "Disk:   ${DISK}${RESET}"
echo ""