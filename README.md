# AFPI (Advanced Fedora Post-Install) - Ansible Role-Based

[![Project Status: Active](https://img.shields.io/badge/Project%20Status-Active-brightgreen.svg)](#-project-status)

AFPI is a modular and intelligent system for Fedora Workstation post-installation (Validated on Fedora 41-44). It uses an architecture based on **Roles** and environment-aware variables (Jinja2), allowing your desktop customization and hardware optimizations to be applied consistently, making your workstation deployment fully automated and "hardware-aware".

> [!WARNING]
> **Disclaimer:** This project is tailored specifically for my personal environment, preferences, and hardware configuration. If you choose to use it, you must thoroughly review all roles, configurations, and variables, and customize them to fit your own specific requirements and hardware setup. Use it at your own risk.

## 📊 Project Status

*   **Current Version:** 2.7.0
*   **Last Update:** October 3, 2026
*   **Latest Improvement:** Secure Boot ready NVIDIA/VirtualBox setup: one shared akmods signing key enrolled once via MOK, a reboot gate that stops the play when an update needs a restart, and the NVIDIA driver, Vulkan, VA-API and power settings applied in a single run.
*   **Stability:** Production-ready for Fedora 41, 42, 43, and 44.

## 🏗️ Architecture and Roles

The project is organized to isolate responsibilities, ensuring idempotency and ease of maintenance:

*   **`update`**: DNF plugins and optimization, RPM Fusion repositories, a full system upgrade, and a reboot gate (stops the run when the upgrade needs a reboot).
*   **`nvidia`**: GPU detection and Secure Boot-ready driver installation (signed akmods build, initramfs).
*   **`akmods_mok`**: Secure Boot signing key for akmods-built modules (NVIDIA, VirtualBox): generated once, enrolled via `mokutil` only when not already enrolled or pending. Imported by `nvidia` and `apps` before their akmod packages are installed.
*   **`hardware`**: Post-driver GPU setup (NVIDIA Vulkan, VA-API/NVENC and power management; Intel and AMD acceleration), multimedia codecs, and ASUS ROG support.
*   **`common`**: Hostname, Flathub, kernel cleanup, GRUB tuning (timeout, resolution, regenerated automatically when changed), the Antigravity CLI, and **Zero-Config ZSH** setup (Oh-My-Zsh with Kali-like theme and self-managed plugins).
*   **`desktop`**: 
    *   **Universal Cedilla (ç) Fix**: Uses a `~/.XCompose` mapping (System) plus Flatpak overrides. Browsers, Bitwarden and Antigravity run on native Wayland with no extra fix; Zoom is the exception and always runs on XWayland (it hardcodes xcb), where the cedilla also works.
    *   **Terminal**: Konsole and PTYxis profile management.

*   **`apps`**: Complete suite via DNF and Flatpak, featuring GPU automation for Steam, **VirtualBox group management (vboxusers/vboxsf)**, and productivity tools (Brave, VS Code, GitHub CLI).
*   **`ai_tools`**: Integration of the AI ecosystem (Claude Code via the official native installer, Gemini CLI and extensions) and specialized Python libraries via `pipx`.

## 🏷️ Granular Control (Tags)

AFPI features a comprehensive tagging system that allows you to run specific parts of the configuration:

| Category | Primary Tags | Description |
| :--- | :--- | :--- |
| **Maintenance** | `update`, `cleanup`, `grub` | System upgrades, DNF optimization, kernel cleanup, and GRUB tuning. |
| **Hardware** | `nvidia`, `drivers`, `power`, `asus` | GPU drivers, power management, and ASUS-specific tools. |
| **Shell** | `shell`, `zsh`, `omz`, `aliases` | ZSH installation, Oh-My-Zsh theme, and custom aliases. |
| **Git** | `git` | Git identity (from `bootstrap.sh`) and defaults in the user's `~/.gitconfig`. |
| **Desktop** | `desktop`, `fonts`, `cedilla` | Terminal profiles, fonts, and the universal cedilla fix. |
| **Software** | `apps`, `software`, `dnf`, `flatpak` | Application installation via DNF or Flatpak. |
| **AI** | `ai`, `claude`, `gemini`, `extensions`, `python` | Claude Code, Gemini CLI, extensions, and AI-related Python libraries. |

## 🔐 Secrets Management (Ansible Vault)

AFPI uses **Ansible Vault** to protect sensitive information. Since the provided `group_vars/all/secrets.yml` is encrypted, you must create your own if you fork this project.

### Required Variables in `secrets.yml`
| Variable | Description | Example / Usage |
| :--- | :--- | :--- |
| `api_keys` | Block of environment exports for your shell | `export SERVICE_API_KEY="your_value_here"` |

## 🚀 Getting Started

### 1. Bootstrap the System
Prepare the Ansible environment:
```bash
./bootstrap.sh
```
It also asks for this machine's settings and saves them to `host_vars/127.0.0.1.yml`, which is git-ignored and overrides `group_vars/all/all.yml`. The playbook applies them without stopping to ask. Run `./bootstrap.sh` again to change them.

*   **Hostname** (Enter keeps the current one). With no answer saved, the hostname is left untouched.
*   **Git `user.name` and `user.email`** (Enter keeps the saved value or the one already in `~/.gitconfig`; empty skips them). The playbook writes them to your `~/.gitconfig`, together with `init.defaultBranch=main` and `pull.ff=only` (`git_config_defaults` in `all.yml`, tag `git`).

### 2. Run the Playbook
Apply the full configuration (the provided `ansible.cfg` is optimized for faster deployment):
```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass
```

> [!IMPORTANT]
> **Reboot gate:** right after the system upgrade, the `update` role checks `dnf needs-restarting -r` and whether the running kernel is the newest one installed (that check does not depend on the clock, which matters on dual-boot machines whose hardware clock keeps local time). If the upgrade requires a reboot (new kernel or core libraries), the playbook **stops there** with a message: reboot and run the **same command** again. The second run passes the gate and applies the rest of the setup. On a freshly installed machine the first run almost always stops at the gate.
>
> This keeps the akmod-built modules (NVIDIA driver, VirtualBox) compiled for the kernel that is actually running, and lets kernel cleanup remove the old one.

### 3. GitHub CLI login
The playbook installs `gh` but cannot log in for you (it opens the browser and keeps the token in the keyring). At the end of each run it reminds you while you are not logged in. As your user:
```bash
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git
```

### 4. NVIDIA and Secure Boot

There is no special workflow anymore: keep running the same command and reboot whenever it asks.

1. **Run** → stops at the reboot gate after the upgrade. **Reboot.**
2. **Run** → installs the NVIDIA driver, Vulkan, VA-API/NVENC and the power management settings (`/etc/modprobe.d/nvidia.conf`) and, with Secure Boot on, queues the akmods signing key for enrollment. **Reboot**, choose **Enroll MOK** in the blue MokManager screen and type `mok_password` (`group_vars/all/all.yml`). After this reboot the driver is loaded (`nvidia-smi` works) and everything is active: no third run is needed.

Without Secure Boot, step 2 has no MokManager screen, but the reboot is still needed to load the driver. Machines without an NVIDIA GPU that install VirtualBox go through the same MOK enrollment in step 2.

## ⚠️ Troubleshooting: System Freezes

Some laptops (especially those with hybrid graphics or specific ASUS/NVIDIA combinations) may experience a system freeze during the `hardware` role.

1.  **Hard Reboot** the machine (hold power button).
2.  Run the playbook skipping the power management and hardware-specific tags to isolate the issue:
    ```bash
    ansible-playbook site.yml --skip-tags power,asus --ask-vault-pass
    ```
3.  If the playbook finishes successfully with these skips, the conflict is likely in the NVIDIA Deep Power Management settings or the `supergfxd` service.

## 🎬 Manual Step: Widevine DRM in Brave

AFPI installs both `brave-browser` and `brave-origin`, but intentionally leaves Widevine untouched: enabling DRM is a personal choice. Without it, DRM-protected video (streaming services, course platforms) will not play. To enable it in each variant:

1.  Open `brave://settings/extensions` and turn on **Widevine**, then restart the browser.
2.  Open `brave://components` and check that **Widevine Content Decryption Module** shows a version (if it shows `0.0.0.0`, click **Check for update**).

## 🛠️ AFPI Differentiators

### Intelligent Environment Discovery
AFPI doesn't just run blindly. The `env_setup.yml` core task dynamically discovers your machine's profile:
*   **Hardware Detection:** Identifies NVIDIA, Intel, or AMD GPUs and applies specific acceleration packages.
*   **Vendor Awareness:** Specifically detects ASUS ROG/TUF systems to enable `asusctl` and `supergfxctl` tools.
*   **Desktop Agnostic:** Automatically identifies if you are running GNOME or KDE Plasma and applies environment-specific terminal profiles (PTYxis or Konsole) and apps.

### Zero-Config Shell
ZSH configuration has been simplified. The `kali-like-alt` theme manages its own dependencies (syntax highlighting and autosuggestions), reducing playbook complexity and execution time.

### Robust NVIDIA & Secure Boot Automation
The `akmods_mok` role (used by `nvidia` and by the VirtualBox install in `apps`) implements MOK (Machine Owner Key) management entirely via Ansible:
*   **Intelligent Detection:** Detects existing keys, pending enrollments, and kernel status to avoid redundant operations.
*   **Integrated Signing:** Automatically triggers `akmods` and `dracut` to ensure modules are signed and included in the initramfs immediately.
*   **Secure Pipe:** Passes `mok_password` (`group_vars/all/all.yml`) to `mokutil` via stdin, never logged.

### Universal Cedilla (ç) Fix
Uses a `~/.XCompose` mapping (System) plus Flatpak overrides. Browsers, Bitwarden and Antigravity run on native Wayland with no extra fix; Zoom is the exception and always runs on XWayland (it hardcodes xcb), where the cedilla also works.
