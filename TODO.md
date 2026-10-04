# AFPI — O que falta

Só o que ainda está aberto. O histórico (itens feitos, achados e como cada um foi validado) fica no
git: o `TODO.md` completo está no commit `aa885a2` (`git show aa885a2:TODO.md`).

Legenda: 🔴 funciona errado hoje · 🟠 robustez · 🟡 cosmético / polimento

---

## NVIDIA com Secure Boot no `noir`

- [ ] Na próxima atualização de kernel de verdade: depois do reboot, `modinfo -F signer nvidia`
      no kernel novo (o `akmods` recompila e assina no boot; deve mostrar a chave akmods do
      `noir`) e `nvidia-smi` funcionando.
