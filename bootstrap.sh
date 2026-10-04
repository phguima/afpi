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

# 4. Machine settings: hostname and git identity
# Asked here, not in the playbook, so ansible-playbook never stops for input. The answers go to
# host_vars/127.0.0.1.yml (git-ignored, machine-specific), which overrides group_vars/all.
# The file is read and written with PyYAML (installed with Ansible) so names with quotes survive;
# other keys already in it are kept.
HOST_VARS="host_vars/127.0.0.1.yml"

# Prints the value of key $1 saved in $HOST_VARS (empty when missing)
host_var() {
    [ -f "$HOST_VARS" ] || return 0
    python3 -c 'import sys, yaml; v = (yaml.safe_load(open(sys.argv[1])) or {}).get(sys.argv[2]); print(v if v is not None else "")' \
        "$HOST_VARS" "$1"
}

# ask VAR "Label" default: reads into VAR, Enter keeps the default
ask() {
    local answer
    read -r -p "$(echo -e "${C_BLUE}==>${C_RESET} $2 [$3]: ")" answer
    printf -v "$1" '%s' "${answer:-$3}"
}

new_hostname="" git_name="" git_email=""  # set by ask()
if [ -t 0 ]; then
    current_hostname=$(hostnamectl hostname 2>/dev/null || true)
    current_hostname="${current_hostname:-$HOSTNAME}"
    saved_hostname=$(host_var system_hostname)
    while true; do
        ask new_hostname "Hostname" "${saved_hostname:-$current_hostname}"
        # RFC 1123 label: letters, digits and '-', 1-63 chars, no leading/trailing '-'
        if [[ "$new_hostname" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
            break
        fi
        error "Invalid hostname '${new_hostname}': use letters, digits and '-' (max 63 chars)."
    done

    # Git identity: defaults to what was saved before, then to the current ~/.gitconfig.
    # Leaving both empty means the playbook does not touch user.name/user.email.
    saved_git_name=$(host_var git_user_name)
    saved_git_email=$(host_var git_user_email)
    ask git_name "Git user.name (empty to skip)" "${saved_git_name:-$(git config --global user.name 2>/dev/null || true)}"
    while true; do
        ask git_email "Git user.email (empty to skip)" "${saved_git_email:-$(git config --global user.email 2>/dev/null || true)}"
        if [ -z "$git_email" ] || [[ "$git_email" =~ ^[^[:space:]@]+@[^[:space:]@]+$ ]]; then
            break
        fi
        error "Invalid e-mail '${git_email}'."
    done

    mkdir -p host_vars
    python3 - "$HOST_VARS" "$new_hostname" "$git_name" "$git_email" <<'PY'
import os, sys, yaml
path, hostname, name, email = sys.argv[1:]
data = {}
if os.path.exists(path):
    with open(path) as f:
        data = yaml.safe_load(f) or {}
data.update({"system_hostname": hostname, "git_user_name": name, "git_user_email": email})
with open(path, "w") as f:
    f.write("---\n# Written by bootstrap.sh: settings for this machine only (not tracked by git).\n")
    yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True, default_flow_style=False)
PY
    success "Hostname '${new_hostname}' saved to ${HOST_VARS} (applied by the playbook)."
    if [ -n "$git_name" ] || [ -n "$git_email" ]; then
        success "Git identity '${git_name} <${git_email}>' saved to ${HOST_VARS}."
    else
        warn "No git identity saved: the playbook leaves user.name/user.email as they are."
    fi
else
    warn "No terminal: hostname and git identity not asked. The playbook uses ${HOST_VARS} if it exists."
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
