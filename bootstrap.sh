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

# 3. Check for project structure
if [ ! -f "group_vars/all/all.yml" ]; then
    error "Structure 'group_vars/all/all.yml' not found. Please ensure you are in the root of the afpi project."
    exit 1
fi

# 4. Hostname
# Asked here, not in the playbook, so ansible-playbook never stops for input. The answer goes to
# host_vars/127.0.0.1.yml (git-ignored, machine-specific), which overrides group_vars/all.
HOST_VARS="host_vars/127.0.0.1.yml"
current_hostname=$(hostnamectl hostname 2>/dev/null || true)
current_hostname="${current_hostname:-$HOSTNAME}"
if [ -f "$HOST_VARS" ]; then
    saved_hostname=$(sed -n 's/^system_hostname: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$HOST_VARS")
fi
default_hostname="${saved_hostname:-$current_hostname}"

if [ -t 0 ]; then
    while true; do
        read -r -p "$(echo -e "${C_BLUE}==>${C_RESET} Hostname [${default_hostname}]: ")" new_hostname
        new_hostname="${new_hostname:-$default_hostname}"
        # RFC 1123 label: letters, digits and '-', 1-63 chars, no leading/trailing '-'
        if [[ "$new_hostname" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
            break
        fi
        error "Invalid hostname '${new_hostname}': use letters, digits and '-' (max 63 chars)."
    done
    mkdir -p host_vars
    cat > "$HOST_VARS" <<EOF
---
# Written by bootstrap.sh: settings for this machine only (not tracked by git).
system_hostname: "${new_hostname}"
EOF
    success "Hostname '${new_hostname}' saved to ${HOST_VARS} (applied by the playbook)."
else
    warn "No terminal: hostname not asked. The playbook keeps it as is unless ${HOST_VARS} sets it."
fi

# 5. Vault Check
if [ -f "group_vars/all/secrets.yml" ]; then
    if ! grep -q "\$ANSIBLE_VAULT" "group_vars/all/secrets.yml"; then
        warn "Note: 'group_vars/all/secrets.yml' is NOT encrypted. Consider running:"
        echo -e "      ${C_YELLOW}ansible-vault encrypt group_vars/all/secrets.yml${C_RESET}"
    fi
fi

# 6. Final Instructions
echo ""
prompt "Bootstrap complete! You can now run the AFPI playbook using:"
echo -e "${C_GREEN}ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass${C_RESET}"
echo ""
warn "Required flags:"
echo -e "  -K               : Prompts for your sudo password."
echo -e "  --ask-vault-pass : Prompts for your Ansible Vault password (if secrets are encrypted)."
echo ""
warn "Note: Some tasks (like NVIDIA driver install) require a system reboot to complete."
