# AFPI — What is left

Only what is still open. The history (done items, findings and how each one was validated) lives
in git: the full `TODO.md` is in commit `aa885a2` (`git show aa885a2:TODO.md`, in Portuguese).

Legend: 🔴 works wrong today · 🟠 robustness · 🟡 cosmetic / polish

---

## NVIDIA with Secure Boot on `noir`

- [ ] On the next real kernel update: after the reboot, `modinfo -F signer nvidia` on the new
      kernel (`akmods` rebuilds and signs at boot; it should show `noir`'s akmods key) and
      `nvidia-smi` working.
