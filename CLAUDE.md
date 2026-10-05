# AFPI — instructions for Claude

AFPI (Ansible Fedora Post-Install): an Ansible playbook that sets up a Fedora (41–44) workstation
after installation. Repo `phguima/afpi`, single branch `main`. The target is the user's personal
machine (hostname `noir`: ASUS TUF Gaming F15, hybrid Intel + NVIDIA RTX 3050 (Ampere), Fedora 44,
**Secure Boot always on**: the user's decision, never turn it off or suggest turning it off; **dual
boot with Windows**, plus the `thevoid` disk). Talk to the user in English; all docs are in English.

**AAPI** (`phguima/aapi`, at `../aapi` in the original workspace) is this project's port to
AlmaLinux 10 (work machine). Several architecture improvements started there and are being brought
here. When porting something from AAPI, adapt what is EL10-specific (dnf4, EPEL/CRB, package names).

**ALPI** (`phguima/alpi`, at `../alpi`) is the planned successor that unifies AFPI and AAPI (design
stage since 2026-10-05). Changes made here until parity must also be ported there: note them in
ALPI's `TODO.md`.

## Work status

`TODO.md` holds **only what is left**. **Read it before starting.** The history (done items,
findings such as the reboot gate with the RTC in local time and the dGPU woken up by the Plasma GPU
widget, and how each item was validated) was removed from it on 2026-10-04 and lives in git:
`git show aa885a2:TODO.md` (in Portuguese). When an item is done, remove it from `TODO.md` and
record the validation in the commit message; a new task goes into `TODO.md` until it is done.

## Structure

- `site.yml`: single play on `localhost` with `become: yes`. `pre_tasks` imports
  `tasks/env_setup.yml` (facts: user, GPU, DE, `is_secure_boot`, distro assert). Role order:
  `update` → `nvidia` → `hardware` → `common` → `apps` → `desktop` → `ai_tools`. The
  `Regenerate GRUB` handler lives in `site.yml` itself.
- `roles/akmods_mok`: akmods signing key + MOK enrollment (only with Secure Boot). It is not in
  `site.yml`: `nvidia` and `apps` import it (`import_role`) before the akmod packages (NVIDIA
  driver, VirtualBox from RPM Fusion). Idempotent: importing it twice does nothing.
- `roles/update` ends with a **reboot gate**: `dnf needs-restarting -r` → rc 1, **or** a running
  kernel different from the newest `kernel-core`, ends the play asking for a reboot
  (`meta: end_host`). On a new machine the first run almost always stops there. The kernel
  comparison exists because `needs-restarting` uses systemd's boot time, which is wrong with the
  RTC in local time (dual boot with Windows): on `noir` it returned rc 0 right after a new kernel
  was installed. Do not add a task that forces the RTC to UTC: in dual boot that breaks the Windows
  clock.
- `group_vars/all/all.yml`: all variables, including `mok_password`. `system_hostname` and the git
  identity (`git_user_name`, `git_user_email`) are empty (= leave as is): `bootstrap.sh` asks for
  them and saves them to `host_vars/127.0.0.1.yml` (in `.gitignore`, per machine), which wins over
  `group_vars`. Nothing personal hard-coded in the repo: **other people use AFPI too**. Nothing in
  the playbook asks for input during the run: questions go into `bootstrap.sh`.
- No vault since 2026-10-04: `api_keys` is `""` in `all.yml` (empty = no API lines in `.zshrc`).
  Whoever wants keys creates an optional vault at `group_vars/all/secrets.yml` (in `.gitignore`,
  never committed; see the README). If it exists, Claude does not have the password: do not try to
  open it. Files in `group_vars/all/` load in alphabetical order, so the vault wins over `all.yml`.
- Real run (only the user, on their machine):
  `ansible-playbook -i inventory.ini site.yml -K` (`./bootstrap.sh` first, the first time;
  `--ask-vault-pass` only with the optional vault).

## Conventions

- Commits in English, Conventional Commits with scope: `feat(update): …`, `fix(nvidia): …`,
  `docs(todo): …`, `chore(git): …`.
- Task names as `Area | Action` (`MOK | Request enrollment`); comments in English, explaining the
  *why* (see the existing ones).
- Reads (`command`/`shell` that only query) get `changed_when: false` and, when the facts must hold
  under `--check`, `check_mode: false`.
- Secrets passed to commands go through `stdin:` with `no_log: true`, never through `echo` on the
  command line.

## Git

- Start with `git fetch` + `git pull --ff-only`: the user also commits from other machines (a push
  was already rejected because of that). Check again before every push.
- Commit and push **only when the user asks**. If the remote moved, look at what came in
  (`git log HEAD..origin/main`) before rebasing.

## Tests — Molecule (mandatory)

- **Every change or new feature ships with tests in the same commit**: new Molecule scenarios or
  updates to the existing ones (and pytest unit tests for Python code such as filter plugins).
  When behavior changes, update the scenarios that cover it. A change without tests is not done.
- Driver: podman (`molecule-plugins[podman]`), installed with pipx on the host:
  `pipx install molecule && pipx inject molecule 'molecule-plugins[podman]' ansible-core`.
  The Molecule controller runs on the host, but every playbook run targets the scenario's
  container, never the host: plays get their hosts from Molecule's inventory, not `localhost`.
- Layout: `molecule/<scenario>/` (`molecule.yml`, `converge.yml`, `verify.yml`), one scenario per
  distro/profile or role as needed. Use systemd-enabled images (`command: /sbin/init`) where
  services are involved. `verify.yml` asserts the outcome (packages, files, settings), not only
  that the run did not fail.
- Run: `molecule test -s <scenario>` (create → converge → idempotence → verify → destroy). The
  idempotence step replaces the manual "run twice". Hardware-only checks (Secure Boot/MOK, real
  reboot) stay in the user's VM.
- Until Molecule is set up (see `TODO.md`), keep using the manual podman recipes below.

## Tests — NEVER on the host

Tests run **only in a container (podman) or in the user's VM**, never on the user's machine, not
even read-only playbooks, not even `--check`. Reading host files or querying rpm is fine; running
the playbook or parts of it is not.

Recipes that worked (image `registry.fedoraproject.org/fedora:44`):

- Base: `podman run --rm -v <repo>:/afpi:ro,z -v <scratch>:/t:ro,z fedora:44 sh -c 'dnf install -y -q ansible-core pciutils; …'`.
  For `community.general` modules (e.g. `copr`), also run
  `ansible-galaxy collection install community.general`, **without `-q`**: with `-q` a failure goes
  unnoticed and the error shows up later, in another task.
- Use `:z` (shared SELinux label), not `:Z`, when the same directory is mounted in several
  containers. With `:Z` each one takes the label from the previous one and you get "Permission
  denied". To avoid relabeling host files at all, use `--security-opt label=disable` instead.
- A test playbook outside the repo does not load `group_vars/`: pass `-e @/afpi/group_vars/all/all.yml`.
  To run the real `site.yml`: copy the repo into the container, delete `secrets.yml` and use
  `ANSIBLE_BECOME_ASK_PASS=False ansible-playbook site.yml --tags <tag> -e ansible_become=false`.
- Roles by name (`import_role: name: akmods_mok`) outside `site.yml`: `ANSIBLE_ROLES_PATH=/afpi/roles`.
- Booleans via `-e` must be JSON (`-e '{"is_nvidia": true}'`). `-e is_nvidia=true` becomes a string
  and ansible-core 2.20 rejects it in a conditional.
- Fake Secure Boot: mount a directory with `efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c`
  (bytes `06 00 00 00 01` = on, `… 00` = off) **over `/sys/firmware`** with
  `--security-opt unmask=/sys/firmware -v <dir>:/sys/firmware:ro,z`. Mounting a single file inside
  sysfs does not work. Without the mount, the container has no efivars (= legacy BIOS).
- Fake `mokutil` in `/usr/local/bin` that logs the calls and simulates the states
  (`not enrolled` rc 0 / `is already enrolled` / `is already in the enrollment request` rc 1).
  `kmodgenca` can be the real one (package `akmods`).
- `dnf` wrapper in `/usr/local/bin` to force the rc of `dnf needs-restarting`. It does not affect
  the `ansible.builtin.dnf` module, which uses libdnf5. In the container the real
  `needs-restarting` returns rc 1 after an upgrade (it uses the host's boot time).
- NVIDIA driver in the container: `-e '{"is_nvidia": true, "nvidia_driver_packages": ["kmodtool"]}'`
  to avoid downloading ~1 GB. The module does not load in the container anyway.
- `grub2-mkconfig` does not work in a container (it does not probe the disk): use a fake one that
  logs the `-o`.
- GNOME-only tasks (Ptyxis): long-running container (`podman run -d … sleep infinity` + `podman exec`)
  with `sudo dbus-daemon dconf ptyxis`, a regular user with `NOPASSWD`, `Defaults env_keep +=
  "DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR"` (plays the role of `pam_systemd` on the real host) and
  a `dbus-daemon --session --address=unix:path=/run/user/1000/bus --fork` for that user. The
  playbook runs **as the user**, with `XDG_CURRENT_DESKTOP=GNOME` and `ANSIBLE_BECOME_ASK_PASS=False`
  (`env_setup` uses `SUDO_USER`). When running `podman exec … sh -c` with `--fork`, use `</dev/null`
  and redirect the output, or the exec never returns. `ansible-galaxy` as that user hung: install
  as root with `-p /usr/share/ansible/collections`.
- The full `site.yml` does **not** run in a plain container: no systemd (services, `hostname`), no
  `/etc/default/grub` (to test the API block, `-e 'api_keys="# fake"'`). The full `--check` is only
  done in the VM.
- Run twice to check idempotency (`changed=0` on the 2nd) and test `--check`.
- zsh: write `${VAR}:ro`, not `$VAR:ro` (zsh reads `:r` as a modifier).
- When done, remove the containers (`podman rm -f`).

What depends on hardware (real MokManager enrollment, modules loading, a real reboot) is tested by
the user in two VMs with Secure Boot, one GNOME and one KDE (checklist in section 5 of the
historical `TODO.md`, `git show aa885a2:TODO.md`). Leave in `TODO.md` what is still to be checked
there.

## Fedora specifics

- `dnf` is dnf5. `dnf needs-restarting` comes from `dnf5-plugins` (`dnf-plugins-core` is dnf4).
  Command options go **after** the subcommand: `dnf list kernel --showduplicates`, not
  `dnf --showduplicates list kernel` (dnf4 syntax).
  `community.general.dnf_config_manager` uses dnf4 syntax (`--set-disabled`): here, use
  `dnf config-manager setopt <repo>.enabled=0`.
- `mokutil` comes with every UEFI install (a dependency of `shim-x64`).
- `/etc/grub2-efi.cfg` is only a symlink to `/boot/grub2/grub.cfg` (the real file, on UEFI and BIOS).
- `kmodgenca --force` creates a new key pair on every run and resets the symlinks
  `/etc/pki/akmods/{certs/public_key.der,private/private_key.priv}`. Never use `--force`.
