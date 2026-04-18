# AFPI (Advanced Fedora Post-Install) - Ansible Role-Based

AFPI is a modular and intelligent system for Fedora Workstation post-installation. It uses an architecture based on **Roles** and **Dynamic Templates**, allowing your desktop customization and hardware optimizations to be applied consistently, making your workstation deployment fully automated and "hardware-aware".

## 🏗️ Architecture and Roles

The project is organized to isolate responsibilities, ensuring idempotency and ease of maintenance:

*   **`common`**: System optimizations (DNF, RPM Fusion), kernel cleanup, and **Zero-Config ZSH** setup (Oh-My-Zsh with Kali-like theme and self-managed plugins).
*   **`hardware`**: Driver detection and installation (Signed NVIDIA for Secure Boot, Intel, AMD), multimedia codecs, and ASUS ROG support.
*   **`desktop`**: 
    *   **Real Plasma Layout**: Full automation of the KDE layout via Jinja2 templates, preserving widget positions, panels, and transparency settings.
    *   **Intelligent Detection**: Automatically identifies Disk UUIDs, GPUs, and Battery IDs so monitoring widgets work without manual intervention.
    *   **Visual**: Unified management of wallpapers (Desktop/SDDM) and terminal profiles (Konsole/PTYxis).
*   **`apps`**: Complete suite via DNF and Flatpak, featuring GPU automation for Steam and productivity tools (Brave, VS Code).
*   **`ai_tools`**: Integration of the AI ecosystem (Gemini CLI and extensions) and specialized Python libraries via `pipx`.

## 🔐 Secrets Management (Ansible Vault)

AFPI uses **Ansible Vault** to protect sensitive information such as API tokens and passwords.

### Encrypt for the first time
```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

### Edit existing secrets
Do not open the file directly. Use the command below to edit in plain text (Ansible will re-encrypt upon saving):
```bash
ansible-vault edit group_vars/all/secrets.yml
```

### Permanently decrypt
```bash
ansible-vault decrypt group_vars/all/secrets.yml
```

### Encrypt Profile Picture (Total Privacy)
To avoid uploading your personal photo to the repository, you can store it encrypted in the Vault:
1. Generate the string: `base64 -w 0 path/to/photo.jpg > string.txt`
2. Add to `secrets.yml`: `user_profile_picture_base64: "CONTENT_FROM_STRING.TXT"`
3. AFPI will detect the variable and create the `.face.icon` file dynamically.

### Run the Playbook with Secrets
Whenever there are encrypted files, add `--ask-vault-pass`:
```bash
ansible-playbook -i inventory.ini site.yml --ask-vault-pass -K
```

## 🚀 Getting Started

### 1. Bootstrap the System
Prepare the Ansible environment:
```bash
./bootstrap.sh
```

### 3. Run the Playbook
Apply the full configuration:
```bash
ansible-playbook -i inventory.ini site.yml --ask-vault-pass -K
```

## 🛠️ AFPI Differentiators

### Hardware-Aware Configuration
AFPI interacts with the actual hardware. If you switch machines, it will detect the new Disk UUID and the new battery sensors, adjusting Plasma configuration files dynamically before applying them.

### Zero-Config Shell
ZSH configuration has been simplified. The `kali-like-alt` theme manages its own dependencies (syntax highlighting and autosuggestions), reducing playbook complexity and execution time.

### Universal Cedilla (ç) Fix
Fine-tuned in three layers (System, Flatpak, and Ozone/X11) to ensure the cedilla works perfectly across all applications, including browsers and communication tools.
