# AFPI (Advanced Fedora Post-Install) - Ansible Role-Based

AFPI is a modular and intelligent system for Fedora Workstation post-installation. It uses an architecture based on **Roles** and **Dynamic Templates**, allowing your desktop customization and hardware optimizations to be applied consistently, making your workstation deployment fully automated and "hardware-aware".

## 🏗️ Architecture and Roles

The project is organized to isolate responsibilities, ensuring idempotency and ease of maintenance:

*   **`common`**: System optimizations (DNF, RPM Fusion), kernel cleanup, and **Zero-Config ZSH** setup (Oh-My-Zsh with Kali-like theme and self-managed plugins).
*   **`hardware`**: Driver detection and installation (Signed NVIDIA for Secure Boot, Intel, AMD), multimedia codecs, and ASUS ROG support.
*   **`desktop`**: 
    *   **Universal Cedilla (ç) Fix**: Fine-tuned in three layers (System, Flatpak, and Ozone/X11) to ensure the cedilla works perfectly across all applications.
    *   **Visual**: Unified management of wallpapers (Desktop/SDDM), profile pictures, and terminal profiles (Konsole/PTYxis).

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

## 🚀 Getting Started

### 1. Bootstrap the System
Prepare the Ansible environment:
```bash
./bootstrap.sh
```

### 2. Run the Playbook
Apply the full configuration (the provided `ansible.cfg` is optimized for faster deployment):
```bash
ansible-playbook site.yml --ask-vault-pass
```

> [!IMPORTANT]
> **Usuários NVIDIA:** Para garantir a compatibilidade dos drivers proprietários com o kernel mais recente, é altamente recomendado seguir este fluxo:
> 1. Execute apenas a atualização do sistema: `ansible-playbook site.yml --tags common --ask-vault-pass`
> 2. **Reinicie** a máquina para carregar o novo kernel.
> 3. Execute o playbook completo (ou pule a role common se desejar): `ansible-playbook site.yml --ask-vault-pass`
>
> **Dica de Controle (Tags):**
> - Para pular a atualização do sistema se já a fez: `--skip-tags common`
> - Para pular a instalação dos drivers NVIDIA: `--skip-tags nvidia`


## 🛠️ AFPI Differentiators

### Zero-Config Shell
ZSH configuration has been simplified. The `kali-like-alt` theme manages its own dependencies (syntax highlighting and autosuggestions), reducing playbook complexity and execution time.

### Universal Cedilla (ç) Fix
Fine-tuned in three layers (System, Flatpak, and Ozone/X11) to ensure the cedilla works perfectly across all applications, including browsers and communication tools.

