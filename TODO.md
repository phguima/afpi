# AFPI — O que falta

Só o que ainda está aberto. O histórico (itens feitos, achados e como cada um foi validado) fica no
git: o `TODO.md` completo está no commit `aa885a2` (`git show aa885a2:TODO.md`).

Legenda: 🔴 funciona errado hoje · 🟠 robustez · 🟡 cosmético / polimento

---

## NVIDIA com Secure Boot no `noir`

- [ ] Na próxima atualização de kernel de verdade: depois do reboot, `modinfo -F signer nvidia`
      no kernel novo (o `akmods` recompila e assina no boot; deve mostrar a chave akmods do
      `noir`) e `nvidia-smi` funcionando.

## Vault removido

- [ ] No `noir`: apagar o vault local (`rm group_vars/all/secrets.yml`, agora ignorado pelo git; com
      ele cifrado o playbook pediria a senha) e rodar com `--tags setup` → o `.zshrc` fica sem o
      `GITHUB_MCP_PAT`. Revogar o token no GitHub se ele não for mais usado.
