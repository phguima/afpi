# AFPI (Advanced Fedora Post-Install) - Ansible Role-Based

[![Project Status: Active](https://img.shields.io/badge/Project%20Status-Active-brightgreen.svg)](#-project-status)

AFPI is a modular and intelligent system for Fedora Workstation post-installation (Validated on Fedora 41-43). It uses an architecture based on **Roles** and **Dynamic Templates**, allowing your desktop customization and hardware optimizations to be applied consistently, making your workstation deployment fully automated and "hardware-aware".

## 📊 Project Status

*   **Current Version:** 2.2.3
*   **Last Update:** April 20, 2026
*   **Latest Improvement:** Refined NVIDIA installation workflow into a reliable 3-step process (Update -> Driver -> Full Config) ensuring kernel compatibility and Secure Boot stability.
*   **Stability:** Production-ready for Fedora 41, 42, and 43.

## 🏗️ Architecture and Roles

The project is organized to isolate responsibilities, ensuring idempotency and ease of maintenance:

*   **`common`**: System optimizations (DNF, RPM Fusion), kernel cleanup, and **Zero-Config ZSH** setup (Oh-My-Zsh with Kali-like theme and self-managed plugins).
*   **`hardware`**: Driver detection and installation (Signed NVIDIA for Secure Boot, Intel, AMD), multimedia codecs, and ASUS ROG support.
*   **`desktop`**: 
    *   **Universal Cedilla (ç) Fix**: Fine-tuned in three layers (System, Flatpak, and Ozone/X11) to ensure the cedilla works perfectly across all applications.
    *   **Visual**: Unified management of wallpapers (Desktop/SDDM), profile pictures, and terminal profiles (Konsole/PTYxis).

*   **`apps`**: Complete suite via DNF and Flatpak, featuring GPU automation for Steam, **VirtualBox group management (vboxusers/vboxsf)**, and productivity tools (Brave, VS Code).
*   **`ai_tools`**: Integration of the AI ecosystem (Gemini CLI and extensions) and specialized Python libraries via `pipx`.

## 🔐 Secrets Management (Ansible Vault)

AFPI uses **Ansible Vault** to protect sensitive information. Since the provided `group_vars/all/secrets.yml` is encrypted, you must create your own if you fork this project.

### Required Variables in `secrets.yml`
The following variables must be defined in your secrets file:

| Variable | Description | Example / Usage |
| :--- | :--- | :--- |
| `api_keys` | Block of environment exports for your shell | `export SERVICE_API_KEY="your_value_here"` |
| `mok_password` | Password for NVIDIA MOK enrollment | Used to sign drivers for Secure Boot |
| `user_profile_picture_base64` | Base64 string of your profile photo | Optional (see instructions below) |

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

### 2. Install NVIDIA Drivers (Optional)
If you have an NVIDIA GPU and want proprietary drivers with Secure Boot support, run the standalone script:
```bash
sudo ./nvidia.sh
```
Follow the on-screen instructions for MOK enrollment.

### 3. Run the Playbook
Apply the full configuration (the provided `ansible.cfg` is optimized for faster deployment):
```bash
ansible-playbook site.yml --ask-vault-pass
```

> [!IMPORTANT]
> **NVIDIA Users:** To ensure compatibility of proprietary drivers with the latest kernel and Secure Boot signing, follow this specific 3-step workflow:
> 1. **Update System:** `ansible-playbook site.yml --tags update --ask-vault-pass`
> 2. **Reboot** to load the new kernel.
> 3. **Install NVIDIA:** `ansible-playbook site.yml --tags nvidia --ask-vault-pass`
> 4. **Reboot** to enroll the MOK key (if Secure Boot is enabled).
> 5. **Finish Setup:** `ansible-playbook site.yml --skip-tags update,nvidia --ask-vault-pass`
>
> **Control Tips (Tags):**
> - To skip system update if already done: `--skip-tags update`
> - To skip NVIDIA driver installation: `--skip-tags nvidia`



## 🛠️ AFPI Differentiators

### Zero-Config Shell
ZSH configuration has been simplified. The `kali-like-alt` theme manages its own dependencies (syntax highlighting and autosuggestions), reducing playbook complexity and execution time.

### Automated Resilience
The system handles common installation failures automatically, such as external repository synchronization (ProtonVPN) and hardware-specific configurations. It implements a **Double-Guard** logic (repository validation + intelligent retries) to mitigate mirror instabilities during deployment.

### Robust NVIDIA & Secure Boot Automation
The standalone `nvidia.sh` script features an advanced MOK (Machine Owner Key) management system:
*   **Intelligent Detection:** Detects existing keys, pending enrollments, and kernel status to avoid redundant operations.
*   **Forced Signing:** Automatically triggers `akmods` and `dracut` to ensure modules are signed and included in the initramfs immediately.
*   **Secure Pipe:** Uses high-reliability password injection for `mokutil` to ensure smooth enrollment during the first reboot.

### Universal Cedilla (ç) Fix
Fine-tuned in three layers (System, Flatpak, and Ozone/X11) to ensure the cedilla works perfectly across all applications, including browsers and communication tools.
