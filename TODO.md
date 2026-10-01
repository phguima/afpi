# AFPI — Melhorias trazidas do AAPI

Levantamento feito em 2026-10-01 comparando o AAPI (port para AlmaLinux 10, `tools/aapi`) desde o
fork (`2695e8a`, = AFPI 2.6.0) com o AFPI atual. Só entra o que é arquitetura útil no Fedora; o que é
específico do EL10 (CRB/EPEL, nomes de pacote, Roboto upstream, VirtualBox da Oracle, pin do
`community.general` 11.x, remoção do `@multimedia`) ficou de fora.

Legenda: 🔴 funciona errado hoje · 🟠 robustez · 🟡 cosmético / polimento

---

## 1. Núcleo: Secure Boot, MOK e reboot gate

- [x] 🟠 **Fact `is_secure_boot`** (`tasks/env_setup.yml`) — ler o 5º byte da efivar
      `SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c` com `od -An -tu1 -j4 -N1` (funciona antes do
      `mokutil` estar instalado; BIOS legado → `false`), `check_mode: false`. Base dos itens abaixo.
      Validado (2026-10-01) em container `fedora:44`: sem efivars (→ `false`) e com `/sys/firmware`
      falso valendo `1`/`0` (→ `true`/`false`).
      Falta só a conferência na VM com Secure Boot (`mokutil --sb-state` × fact).
- [x] 🔴 **MOK idempotente no role `nvidia`** — hoje `kmodgenca --force -a` gera **chave nova a cada
      execução** e `mokutil --import` reenfileira sempre (se a chave antiga já estava registrada, os
      módulos passam a ser assinados com uma não registrada). Trocar por:
      - `kmodgenca -a` com `creates: /etc/pki/akmods/certs/public_key.der` (sem `--force`);
      - `mokutil --test-key` antes do import → pula se a saída contém "already";
      - `mokutil --import` com `stdin:` (em vez de `echo -e`) e `no_log: true`;
      - aviso "Enroll MOK no próximo boot" só quando o import mudou algo;
      - bloco todo sob `when: is_secure_boot`.
      Validado (2026-10-01) em container `fedora:44` com o bloco extraído do role, `kmodgenca` real
      (`akmods` 0.6.2), `mokutil` falso e `/sys/firmware` falso: SB=1 → 1ª execução gera 1 chave,
      1 `--import` (senha chega via stdin) e mostra o aviso; 2ª (na fila) e 3ª (registrada) mantêm a
      mesma chave/symlink, sem import nem aviso; `--check` não grava nada; `-vvv` não vaza a senha;
      SB=0 → tudo pulado, nenhuma chave criada. `--syntax-check` do `site.yml` ok.
      O aviso de reboot do driver ficou separado do de MOK (não mostra mais a senha/MOK sem SB).
      Falta: VM com Secure Boot (enroll real no MokManager + `nvidia` carregando — exige GPU NVIDIA
      ou passthrough; sem isso, conferir só geração/enroll da chave).
- [x] 🟠 **Reboot gate** no fim do role `update` — depois do upgrade, `dnf needs-restarting -r`
      (`changed_when: false`, `check_mode: false`, `failed_when: rc not in [0, 1]`); rc 1 → mensagem
      "reinicie e rode o mesmo comando de novo" + `meta: end_host`. Motivo: o akmod da NVIDIA
      (`akmods --kernel $(uname -r)`) e o do VirtualBox compilam para o kernel em execução, e a
      limpeza de kernels não remove o que está rodando. No Fedora o comando vem do **`dnf5-plugins`**
      (garantir instalado; `dnf-plugins-core` é o dnf4). Verificado no Fedora 44: existe, `-r` é
      aceito por compatibilidade, rc 0 quando não precisa reiniciar.
      Validado (2026-10-01) em container `fedora:44` com o role `update` real (repos + upgrade):
      `needs-restarting` real → rc 1 no container (libs atualizadas depois do boot do host) → para
      com o aviso, sem rodar o resto nem os `post_tasks`; 2ª execução `changed=0`. Com wrapper de
      `dnf` forçando o rc: 0 → segue até o fim; 1 → para; 3 → falha no check; `--check` com rc 1 →
      também para (o `--check` mostra que vai precisar de reboot). `dnf5-plugins` já vem na imagem
      base, a instalação explícita é só garantia.

## 2. Assinatura de módulos e segredos

- [x] 🔴 **Enroll da chave akmods compartilhado** — hoje só o role `nvidia` gera/registra a chave;
      numa máquina sem NVIDIA e com Secure Boot ligado, o `akmod-VirtualBox` (RPM Fusion) fica sem
      assinatura válida e o `vboxdrv` não carrega. Mover a geração/enroll (item MOK acima) para um
      task reutilizável (ex.: `tasks/akmods_mok.yml`) chamado por `nvidia` e pela parte de
      VirtualBox do `apps`, com `when: is_secure_boot`.
      Feito como role `akmods_mok` (2026-10-01), importado (`import_role`) pelo `nvidia` (antes do
      driver) e pelo `apps` (antes do "Install DNF packages", só se `VirtualBox` está em
      `dnf_packages_common`; tags `software, dnf, common, virtualbox, secureboot`). O role também
      instala `akmods`/`mokutil`/`openssl`. Validado em container `fedora:44` com os roles reais
      (`mokutil` e `/sys/firmware` falsos; driver NVIDIA trocado por um pacote leve): só VirtualBox
      numa máquina nova → 1 chave + 1 import + aviso; NVIDIA → depois VirtualBox → a 2ª importação
      não faz nada (mesma chave, sem import); chave registrada → nada; SB=0 → tudo pulado nos dois
      caminhos; `--syntax-check` / `--list-tasks` do `site.yml` ok.
- [x] 🟠 **`mok_password` explícito** — hoje é `default('fedora-afpi')` escondido no task. Declarar
      em `group_vars/all/all.yml` (comentário: MokManager usa teclado US, só letras/dígitos/`-`) +
      `assert` quando `is_secure_boot`. O vault continua só com `api_keys`.
      Feito (2026-10-01): `mok_password: "fedora-afpi"` (o mesmo default de antes) em `all.yml` +
      `assert` no `akmods_mok` (validado: senha vazia → falha com a mensagem). README atualizado.
      ⚠️ Os arquivos de `group_vars/all/` carregam em ordem alfabética: se o `secrets.yml` (vault)
      ainda tiver `mok_password`, **ele vence** o `all.yml`. Para concluir a mudança, remover a
      variável do vault (`ansible-vault edit group_vars/all/secrets.yml`), que fica só com `api_keys`.

## 3. GRUB e checagens

- [ ] 🟠 **Handler `Regenerate GRUB`** (`site.yml`) — trocar `-o /etc/grub2-efi.cfg` por
      `-o /boot/grub2/grub.cfg` (o real em UEFI e BIOS; o `/etc/grub2-efi.cfg` é só symlink para ele
      — confirmado no Fedora 44 — e não existe em instalação BIOS).
- [ ] 🟡 **Assert de distro** (`tasks/env_setup.yml`, tag `always`) — `distribution == 'Fedora'` e
      major mínimo (ex.: `>= 43`), para falhar cedo se rodar no lugar errado.

## 4. Idempotência e `--check`

- [ ] 🟡 **Repos de debug com `changed` real** (`roles/common/tasks/kernel_maintenance.yml`) — hoje
      `dnf config-manager setopt "*debug*".enabled=0` roda sempre com `changed_when: false`. Listar os
      repos de debug habilitados e só desabilitar quando houver algum (`setopt <repo>.enabled=0`).
      **Não** usar `community.general.dnf_config_manager` como no AAPI: ele usa a sintaxe do dnf4
      (`--set-disabled`), e o Fedora é dnf5.
- [ ] 🟡 **Ptyxis com `changed` real** (`roles/desktop/tasks/main.yml`) — port direto do AAPI
      (`fe622db`): ler o valor antes/depois de `gsettings set` / `dconf write` e só imprimir `changed`
      se mudou (3 tasks: tamanho/comportamento, cursor/fonte, opacidade).
- [ ] 🟡 **`check_mode: false` nas leituras** — `lspci` (`env_setup`), `repoquery`
      (`kernel_maintenance`), `nvidia-smi` (`nvidia`), `needs-restarting` (`update`), para o
      `--check` ter facts reais.

## 5. Validação

Testes **nunca** rodam no host (`noir`), nem só leitura / `--check`: só em container (podman) ou na VM.

- [ ] Container `fedora:44` (duas execuções, para idempotência) para tudo que não depende de
      hardware: reboot gate (forçar rc 0/1/3), assert de distro, repos de debug, Ptyxis (sessão D-Bus
      do usuário + sudo), `--check`.
- [ ] VM com Secure Boot: geração da chave só uma vez, `mokutil --test-key` pulando
      na 2ª execução, enroll no MokManager, `vboxdrv` e `nvidia` carregando depois do reboot.

---

## Ordem sugerida

1. `is_secure_boot` → MOK idempotente → reboot gate (seção 1)
2. Enroll akmods compartilhado → `mok_password` (seção 2)
3. Handler do GRUB → assert de distro (seção 3)
4. Polimento de idempotência / `--check` (seção 4)
