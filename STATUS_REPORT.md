# AFPI Status Report - April 20, 2026

## Summary of Recent Changes (Version 2.3.1)

This update focuses on stabilizing environment discovery and fixing critical automation logic for hardware-specific tasks.

### 1. Environment Discovery Persistence
- **Fix:** Injected `tags: [always]` into all critical discovery tasks within `tasks/env_setup.yml`.
- **Impact:** Prevents "Undefined Variable" errors when running the playbook with specific tags (e.g., `--tags hardware`). Variables like `user_name`, `is_nvidia`, and `has_nvidia_driver` are now guaranteed to be present in every execution context.

### 2. NVIDIA Service Management
- **Fix:** Replaced Bash-style brace expansion (`nvidia-{suspend,resume,hibernate}.service`) with native Ansible `loop` syntax in `roles/hardware/tasks/main.yml`.
- **Improvement:** Added `daemon_reload: yes` to the systemd task to ensure new service files from the `xorg-x11-drv-nvidia-power` package are detected immediately without a manual reload.

### 3. Syntax Corrections
- **Fix:** Removed illegal `register` parameter from the `block` statement in `roles/nvidia/tasks/main.yml`. 
- **Impact:** Ensures the playbook is syntactically correct and compatible with standard Ansible engine requirements.

### 4. Documentation
- Updated `README.md` to reflect version 2.3.1 and documented the latest architectural refinements.

---
**Status:** All critical hardware automation tasks are now verified and idiomatic.
