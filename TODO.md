# AFPI — What is left

Only what is still open. The history (done items, findings and how each one was validated) lives
in git: the full `TODO.md` is in commit `aa885a2` (`git show aa885a2:TODO.md`, in Portuguese).

Legend: 🔴 works wrong today · 🟠 robustness · 🟡 cosmetic / polish

---

## NVIDIA with Secure Boot on `noir`

- [ ] On the next real kernel update: after the reboot, `modinfo -F signer nvidia` on the new
      kernel (`akmods` rebuilds and signs at boot; it should show `noir`'s akmods key) and
      `nvidia-smi` working.

## Package names

- [ ] 🟡 `p7zip` and `p7zip-plugins` in `dnf_packages_common` are only provides of `7zip` and
      `7zip-standalone` on Fedora 44 (found by ALPI's Molecule verify, 2026-10-05): list the real
      names, like AAPI does.

## Molecule tests

- [ ] Install Molecule with the podman driver (pipx, see `CLAUDE.md`) and add a `requirements`
      note for it to the README.
- [ ] Make the plays testable outside `localhost` (Molecule's inventory): the real run keeps
      `inventory.ini`, the scenarios point `converge.yml` at the container.
- [ ] Scenario `default` on `fedora:44` (systemd image): full `site.yml` minus what needs real
      hardware/grub, with `verify.yml` for packages, repos, zsh setup, Flatpak overrides.
- [ ] Scenarios for the detection branches: NVIDIA (fake lspci/`is_nvidia`), Secure Boot on/off
      (fake efivars + `mokutil`, recipes in `CLAUDE.md`), GNOME (Ptyxis) and KDE.
- [ ] Turn the manual recipes in `CLAUDE.md` into scenario fixtures (`prepare.yml`).
