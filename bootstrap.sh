#!/bin/bash

# AFPI (Ansible Fedora Post-Install) Bootstrap Script
# This script prepares the system to run the AFPI roles.

set -e

C_RESET='\033[0m'
C_BLUE='\033[1;34m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'

prompt() {
    echo -e "${C_BLUE}==>${C_RESET} $1"
}

success() {
    echo -e "${C_GREEN}SUCCESS:${C_RESET} $1"
}

warn() {
    echo -e "${C_YELLOW}WARNING:${C_RESET} $1"
}

error() {
    echo -e "${C_RED}ERROR:${C_RESET} $1"
}

# 1. Install Ansible if not present
if ! command -v ansible &> /dev/null; then
    prompt "Installing Ansible..."
    sudo dnf install -y ansible
else
    success "Ansible is already installed."
fi

# 2. Install required Ansible collections
prompt "Installing required Ansible collections..."
ansible-galaxy collection install community.general

# 3. Check for group_vars/all.yml
if [ ! -f "group_vars/all.yml" ]; then
    error "group_vars/all.yml not found. Please ensure you are in the root of the afpi project."
    exit 1
fi

# 4. Instructions
echo ""
prompt "Bootstrap complete! You can now run the AFPI playbook using:"
echo -e "${C_GREEN}ansible-playbook -i inventory.ini site.yml${C_RESET}"
echo ""
warn "Note: Some tasks (like NVIDIA driver install) may require manual confirmation or a system reboot."
