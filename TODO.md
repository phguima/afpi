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
      `mok_password` removido do vault (2026-10-01, feito pelo usuário): o `secrets.yml` fica só com
      `api_keys`. (Os arquivos de `group_vars/all/` carregam em ordem alfabética, então uma cópia no
      vault venceria o `all.yml`.)

## 3. GRUB e checagens

- [x] 🟠 **Handler `Regenerate GRUB`** (`site.yml`) — trocar `-o /etc/grub2-efi.cfg` por
      `-o /boot/grub2/grub.cfg` (o real em UEFI e BIOS; o `/etc/grub2-efi.cfg` é só symlink para ele
      — confirmado no Fedora 44 — e não existe em instalação BIOS).
      Validado (2026-10-01) em container `fedora:44` com o `site.yml` real (`--tags grub`) e
      `grub2-mkconfig` falso: 1ª execução → handler dispara 1× com `-o /boot/grub2/grub.cfg`;
      2ª → `changed=0`, sem chamada. No container, sem o pacote do GRUB EFI, `/etc/grub2-efi.cfg` nem
      existe: com o caminho antigo, o `grub2-mkconfig` criaria um arquivo comum que o boot não lê.
- [x] 🟡 **Assert de distro** (`tasks/env_setup.yml`, tag `always`) — `distribution == 'Fedora'` e
      major mínimo (ex.: `>= 43`), para falhar cedo se rodar no lugar errado.
      Feito com mínimo **41** (o README diz "Validated on Fedora 41-44"). Validado em containers:
      `fedora:44` e `fedora:41` passam; `fedora:40` e `almalinux:10` falham com
      "AFPI targets Fedora 41 or newer; detected …".

## 4. Idempotência e `--check`

- [x] 🟡 **Repos de debug com `changed` real** (`roles/common/tasks/kernel_maintenance.yml`) — hoje
      `dnf config-manager setopt "*debug*".enabled=0` roda sempre com `changed_when: false`. Listar os
      repos de debug habilitados e só desabilitar quando houver algum (`setopt <repo>.enabled=0`).
      **Não** usar `community.general.dnf_config_manager` como no AAPI: ele usa a sintaxe do dnf4
      (`--set-disabled`), e o Fedora é dnf5.
      Feito (2026-10-02) com `dnf repo list --enabled --json` (ids com `debug`) + um único
      `dnf config-manager setopt <id>.enabled=0 …` só quando a lista não está vazia. Validado em
      container `fedora:44` (`site.yml --tags kernel`) com `fedora-debuginfo`/`updates-debuginfo`
      ligados: 1ª execução `changed` e os dois desligados; 2ª pula a task; `--check` lê a lista real
      (o `setopt` em si aparece como `skipping` no `--check`, como todo `command`).
- [x] 🟡 **Ptyxis com `changed` real** (`roles/desktop/tasks/main.yml`) — port direto do AAPI
      (`fe622db`): ler o valor antes/depois de `gsettings set` / `dconf write` e só imprimir `changed`
      se mudou (3 tasks: tamanho/comportamento, cursor/fonte, opacidade).
      Validado (2026-10-02) em container `fedora:44` com `ptyxis` instalado, usuário comum com D-Bus
      de sessão, `XDG_CURRENT_DESKTOP=GNOME` e o playbook via `sudo` (`--tags ptyxis`, UUID de
      perfil semeado no dconf): 1ª `changed=3`; 2ª `changed=0`; mudando `default-columns` e a
      opacidade à mão, só esses 2 itens voltam (`changed=2`); 4ª `changed=0`. Valores conferidos no
      `dconf dump`. Abrir o Ptyxis de fato fica para um host GNOME.
- [x] 🟡 **`check_mode: false` nas leituras** — `lspci` (`env_setup`), `repoquery`
      (`kernel_maintenance`), `nvidia-smi` (`nvidia`), `needs-restarting` (`update`), para o
      `--check` ter facts reais.
      Feito (2026-10-02): `lspci` e `nvidia-smi` (`env_setup`), `nvidia-smi` (`nvidia`), os 2
      `repoquery` e a lista de repos (`kernel_maintenance`); `needs-restarting` já tinha. Também nas
      duas leituras do `desktop` cujo `stdout` a task seguinte usa (UUID do perfil do Ptyxis e
      arquivo de compose da cedilha): sem isso a task pulada no `--check` deixava o `stdout`
      indefinido. Conferido em container: no `--check` essas leituras rodam (`ok`, não `skipping`).
      O `--check` geral com tudo instalado ficou para as VMs (seção 5, etapa 5): no container a
      execução completa esbarra em limitações dele (sem systemd, `hostnamectl`, `/etc/default/grub`),
      e numa máquina limpa o `--check` falha por desenho (ex.: o template do oh-my-zsh não existe
      porque a instalação foi só simulada).

## 5. Roteiro de testes nas VMs (VirtualBox, Fedora 44 GNOME e KDE + EFI + Secure Boot)

Tudo o que container não cobre. Testes **nunca** no host (`noir`), nem só leitura / `--check`.
Já validado em container (ver cada item acima): `is_secure_boot`, MOK/`akmods_mok`, reboot gate,
handler do GRUB, assert de distro, repos de debug, Ptyxis.

Duas VMs iguais, uma com a edição **Workstation** (GNOME) e outra com a **KDE Plasma**. As etapas
0–5 valem para as duas: marcar o item quando passar nas duas e, se falhar só numa, anotar qual
(`GNOME:` / `KDE:`). As etapas 6 e 7 não dependem do desktop: basta uma VM (a GNOME). A etapa 8
(NVIDIA) é no `noir` reinstalado.

- As VMs não têm GPU NVIDIA: o role `nvidia` e as tasks NVIDIA do `hardware` são pulados. Quem
  exercita o `akmods_mok` aqui é o VirtualBox do RPM Fusion (`akmod-VirtualBox`). O driver NVIDIA é
  testado no `noir` reinstalado (etapa 8).
- **Rodar o playbook de um terminal dentro da sessão gráfica**, não por SSH: o `env_setup` decide
  GNOME/KDE pelo `XDG_CURRENT_DESKTOP` de quem chama, e sem ele todas as tasks de desktop são
  puladas sem erro. Conferir antes: `echo $XDG_CURRENT_DESKTOP` → `GNOME` / `KDE`.

### Etapa 0 — Criar as VMs (no host)
Sintaxe conferida no VBoxManage 7.2.18 do `noir` (`Fedora_64`, `--firmware=efi`, `modifynvram`).
Rodar uma vez para cada VM, trocando `VM` e `ISO` (o nome do ISO depende do download):
```bash
VM=fedora44-afpi-gnome; ISO="$HOME/Downloads/Fedora-Workstation-Live-44-x86_64.iso"
# VM=fedora44-afpi-kde;  ISO="$HOME/Downloads/Fedora-KDE-Desktop-Live-44-x86_64.iso"
DIR="$HOME/VirtualBox VMs/$VM"
VBoxManage createvm --name=$VM --ostype=Fedora_64 --register
VBoxManage modifyvm $VM --memory=8192 --cpus=4 --firmware=efi --graphicscontroller=vmsvga --vram=128 --nic1=nat
VBoxManage createmedium disk --filename="$DIR/$VM.vdi" --size=81920
VBoxManage storagectl $VM --name=SATA --add=sata --controller=IntelAhci
VBoxManage storageattach $VM --storagectl=SATA --port=0 --device=0 --type=hdd --medium="$DIR/$VM.vdi"
VBoxManage storageattach $VM --storagectl=SATA --port=1 --device=0 --type=dvddrive --medium="$ISO"
# Secure Boot: chaves padrão (Microsoft + Oracle PK) e ativação
VBoxManage modifynvram $VM inituefivarstore
VBoxManage modifynvram $VM enrollmssignatures
VBoxManage modifynvram $VM enrollorclpk
VBoxManage modifynvram $VM secureboot --enable
```
(Pela interface: Sistema → Habilitar EFI + Habilitar Secure Boot → "Redefinir chaves para o padrão".)
Disco de 80 GB: Steam, Flatpaks e os repos de terceiros ocupam bem mais que no AAPI. Com 8 GB cada,
rodar as duas VMs ao mesmo tempo pede 16 GB livres no host; dá para fazer uma depois da outra.
- [x] Instalar cada edição com usuário administrador (`wheel`).
- [x] Em cada VM: `mokutil --sb-state` → `SecureBoot enabled`, e
      `od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c`
      → `1`. Anotar `hostname` e `uname -r`.
- [x] Snapshot limpo de cada uma: `VBoxManage snapshot $VM take limpo` (VM desligada).
      Verificado nas VMs (2026-10-02).

### Etapa 1 — Bootstrap
```bash
git clone https://github.com/phguima/afpi && cd afpi && ./bootstrap.sh
```
Copiar o `secrets.yml` (vault) para `group_vars/all/` se o clone não o trouxer.
- [x] `bootstrap.sh` instala o Ansible e o `community.general` sem erro.
- [x] O `bootstrap.sh` pergunta o hostname (seção 7): responder `fedora44-afpi-gnome` /
      `fedora44-afpi-kde`. `cat host_vars/127.0.0.1.yml` mostra o nome; `git status` não lista
      o `host_vars/`. Se o bootstrap já tinha rodado antes da seção 7: `git pull` e rodar de novo.
- [x] Os facts batem com a etapa 0 (só as tasks `always`, sem mudar nada):
      `ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass --tags never -v 2>&1 | grep -E '"is_(secure_boot|gnome|kde)"'`
      → `is_secure_boot: true` nas duas; `is_gnome: true` / `is_kde: false` na GNOME e o
      contrário na KDE.
      Etapa verificada nas VMs (2026-10-02).
- Não rodar `--check` agora: em máquina limpa ele falha por desenho (repos de terceiros e
  oh-my-zsh só simulados, então tasks seguintes não acham o que precisam). Vai para a etapa 5.

### Etapa 2 — 1ª execução: atualizar e reiniciar
```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass 2>&1 | tee run0.log
```
- [x] Depois do upgrade o playbook **para** com "needs a REBOOT before continuing" (sem os outros
      roles, sem o banner final). Se não pedir reboot, segue direto (etapa 3).
- [x] Reiniciar; `uname -r` → kernel mais recente.
      Etapa verificada nas VMs (2026-10-02).

### Etapa 3 — 2ª execução: setup completo, chave akmods e VirtualBox
```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass 2>&1 | tee run1.log
```
- [x] O `update` passa direto e termina com `failed=0` e o banner `AFPI DEPLOYMENT COMPLETED SUCCESSFULLY!`.
- [x] `MOK | Generate akmods signing key pair` e `MOK | Request enrollment` rodam uma vez e aparece
      o aviso "akmods signing key queued for enrollment" (sem NVIDIA, quem importa o
      `akmods_mok` é o `apps`, antes do `Software | Install DNF packages`).
- [x] `sudo mokutil --list-new` lista a chave (subject com o hostname). `sudo ls -l /etc/pki/akmods/certs/`
      → **um** `.der` real + o symlink `public_key.der` apontando para ele.
- [x] Reboot → tela azul do MokManager → **Enroll MOK** → Continue → senha `fedora-afpi` → Reboot.
- [x] `sudo mokutil --test-key /etc/pki/akmods/certs/public_key.der` → "is already enrolled".
- [x] `lsmod | grep vboxdrv` → carregado; `modinfo -F signer vboxdrv` bate com o subject de
      `sudo openssl x509 -inform der -in /etc/pki/akmods/certs/public_key.der -noout -subject`.
      Se não carregou: `sudo journalctl -b -u akmods` e `dmesg | grep -i -E "vbox|key"`.
- [x] `VBoxManage --version` → 7.2.x; usuário nos grupos `vboxusers` e `vboxsf` (`id`, após novo login).
      Etapa verificada nas VMs (2026-10-02). O diretório `/etc/pki/akmods/certs/` não é legível
      por usuário comum: `ls` e `openssl` nele precisam de `sudo` (roteiro corrigido).

### Etapa 4 — Conferência por role

Nas duas VMs:
- [x] **Hostname:** `hostnamectl hostname` → o nome dado no bootstrap (`fedora44-afpi-gnome` /
      `fedora44-afpi-kde`), e o `System | Set System Hostname` deu `changed` no `run1.log`.
- [x] **Repos:** `dnf repo list --enabled` → `rpmfusion-free*`, `rpmfusion-nonfree*`, `brave-browser`,
      `code`, `gh-cli`; `dnf repo list --enabled | grep -i debug` → vazio.
- [x] **Multimídia:** `rpm -q ffmpeg` (e `ffmpeg-free` ausente). A GPU da VM (VMSVGA) não é
      Intel/AMD/NVIDIA: os drivers de vídeo são pulados.
- [x] **Apps:** `rpm -q chromium clamav steam VirtualBox brave-browser brave-origin code gh`;
      `systemctl is-active clamav-freshclam`; `flatpak list --app` com os de `flatpak_apps_common`.
- [x] **Steam:** `~/.local/share/applications/steam.desktop` com o `Exec=env __NV_PRIME_...`.
- [x] **Shell:** `echo $SHELL` → zsh (novo login); tema `kali-like-alt`; `grep -A3 "API" ~/.zshrc`
      com o conteúdo do vault; aliases presentes. Também para o root (`sudo -i`).
- [x] **GRUB:** `grep -E "GRUB_TIMEOUT|GRUB_GFXMODE" /etc/default/grub`;
      `sudo ls -l /boot/grub2/grub.cfg` com data da execução; menu no boot espera 5 s.
- [x] **Fontes:** `fc-list | grep -i -E "fira code|roboto"`.
- [x] **Cedilha** (após logout/login): no editor de texto e no Brave, `'` + `c` → `ç` (e `'` + `C` → `Ç`).
- [x] **AI tools:** `claude --version`; `agy --version`; `pipx list` com markitdown, notebooklm-py, pdf2docx.

Verificado nas VMs (2026-10-02).

Só na GNOME:
- [x] **Pacotes:** `rpm -q flatseal gnome-tweaks`; `flatpak list --app` também com os de
      `flatpak_apps_gnome` (VideoDownloader, ExtensionManager, Fragments).
- [x] **Ptyxis:** abre com 120x35, cursor sublinhado, Fira Code 10, opacidade 0.95
      (`dconf dump /org/gnome/Ptyxis/` mostra os valores).
- [x] Nenhuma task KDE rodou: no `run1.log`, `KDE |`, `Wayland |` e `Zoom |` aparecem como `skipping`.
      Verificado na VM GNOME (2026-10-02).

Só na KDE:
- [x] **Pacotes:** `rpm -q ktorrent plasma-sdk kde-gtk-config`; `flatpak list --app` também com o
      `com.markopejic.downloader`.
- [x] **Konsole:** `~/.local/share/konsole/kali-like-alt.{profile,colorscheme}` existem; no
      `~/.config/konsolerc`: `DefaultProfile=kali-like-alt.profile`, `RememberWindowSize=false`,
      `ExpandTabWidth=true`. Abrir o Konsole: perfil e cores aplicados, abas na largura toda.
- [x] **Overrides Flatpak:** `flatpak override --user --show com.bitwarden.desktop` → sockets
      `wayland;fallback-x11;!x11`, `XDG_CURRENT_DESKTOP=KDE`, `GTK_USE_PORTAL=1`, sem `GTK_IM_MODULE`;
      `flatpak override --user --show us.zoom.Zoom` → socket `wayland`, `XDG_CURRENT_DESKTOP=KDE`,
      `GTK_USE_PORTAL=1`, filesystem `!home`, sem `GTK_IM_MODULE`/`QT_IM_MODULE`.
- [x] **Cedilha nos Flatpaks:** `'` + `c` → `ç` no Bitwarden (Wayland nativo) e no Zoom (XWayland).
- [x] Nenhuma task GNOME rodou: no `run1.log`, `GNOME |` aparece como `skipping` (sem Ptyxis).
      Verificado na VM KDE (2026-10-02).

### Etapa 5 — Idempotência e `--check`
```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass 2>&1 | tee run2.log
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass --check 2>&1 | tee check.log
```
- [x] Não para no reboot gate (nada novo desde o boot).
- [x] `changed=0`. Todas as tasks têm `creates`/`changed_when`/leitura antes e depois (Ptyxis,
      repos de debug), então qualquer `changed` aqui é bug: anotar a task e a VM.
      🔴 Achado na VM (2026-10-02): `ZSH | Add custom aliases to .zshrc` `changed` (root e usuário).
      Causa: o instalador do Antigravity (`agy install`, no passo "Configuring shell environment")
      apaga qualquer `alias antigravity=` do `.zshrc`; ele rodava **depois** do bloco de aliases e
      só na 1ª execução (`creates`), então a 2ª recolocava o alias. Corrigido: alias renomeado para
      `antigravity-ide` (o `agy install` não mexe nele, nem rodando de novo) e a instalação do
      Antigravity movida para antes do bloco. Validado em container `fedora:44` (`--tags shell`):
      `agy install` sozinho apaga `antigravity` e mantém `antigravity-ide`; 1ª execução grava o
      `antigravity-ide` (root e usuário), 2ª `changed=0`. Nas VMs / no `noir`, a 1ª execução depois
      do `git pull` troca a linha uma vez (`changed`), depois `ok`. Repetir esta etapa.
      O AAPI tem o mesmo padrão (alias `antigravity`, Antigravity depois do bloco): levar para lá.
- [x] Nenhum `MOK | Request enrollment` nem aviso de MOK (chave já registrada).
- [x] `--check` com tudo instalado → `failed=0`. Anotar aqui cada task que falhar.
      Etapa verificada nas VMs (2026-10-02), depois da correção do alias: `changed=0` e
      `--check` sem falhas.

### Etapa 6 — Limpeza de kernels, reboot gate e rebuild do `vboxdrv` em outro kernel (só uma VM)
O repo `updates` costuma ter só o kernel mais novo; o anterior vem do `fedora` ou do Koji
(`dnf list kernel --showduplicates`).
- [x] **Teste 1** — instalar um kernel anterior (`sudo dnf install kernel-<ver> kernel-devel-<ver>`),
      continuar no novo e rodar `--tags kernel` → sobra só o novo; repetir → sem mudança.
      🔴 Achado na VM (2026-10-02): `Kernel | Remove old kernels` falhou com "Depsolve Error"
      (`kmod-VirtualBox-<kernel antigo>` requires `kernel-uname-r = <kernel antigo>`). O akmods
      compila um `kmod-VirtualBox-<kernel>` para cada kernel instalado com `kernel-devel`, e o
      módulo `dnf` não remove dependentes sem `allowerasing`. No `noir` o mesmo valeria para o
      `kmod-nvidia-<kernel>`. Corrigido com `allowerasing: true` (remove junto os kmods daquele
      kernel; o em uso e o mais novo nunca entram na lista). Validado em container `fedora:44`
      com os kernels `6.19.10` (antigo) e `7.2.8` (em uso) + um kmod falso que exige
      `kernel-uname-r` do antigo: código anterior → o mesmo depsolve da VM; com o patch → remove
      `kernel-core`, `kernel-modules-core` e o kmod do antigo, 2ª execução pula a task.
      Repetir na VM: `git pull` e `--tags kernel` (o kernel antigo continua lá: o dnf abortou).
      Conferir também `rpm -qa "kmod-VirtualBox*"` → só o do kernel novo.
- [x] **Teste 2 (segurança)** — reinstalar o antigo (com `kernel-devel`), dar boot nele pelo GRUB
      (`uname -r`). O `akmods` compila e **assina** o `vboxdrv` para esse kernel no boot:
      `lsmod | grep vboxdrv` e `modinfo -F signer vboxdrv`. Rodar `--tags kernel` → os **dois**
      continuam instalados (o em uso nunca entra na lista).
- [x] **Teste 3** — com um só kernel: a remoção é pulada.
- [x] Depois de instalar o kernel antigo, uma execução **completa** para no reboot gate (esperado:
      o `needs-restarting -r` conta qualquer kernel instalado depois do boot, mesmo mais antigo).
      Os testes com `--tags kernel` não passam pelo gate, que só roda com a tag `update`.
      Etapa verificada na VM (2026-10-02), depois da correção do `allowerasing`.

### Etapa 7 — Secure Boot desligado (opcional, só uma VM)
- [x] Restaurar o snapshot `limpo`, desligar o Secure Boot
      (`VBoxManage modifynvram $VM secureboot --disable`), rodar o playbook (etapas 2–3):
      `is_secure_boot: false`, nenhuma task de MOK roda, nenhuma chave em `/etc/pki/akmods/certs/` (`sudo ls`)
      gerada pelo playbook, sem aviso de MOK, e o `vboxdrv` carrega sem assinatura.
      Verificado na VM GNOME (2026-10-02).

### Etapa 8 — NVIDIA no `noir` (reinstalação limpa, Secure Boot ligado)

Única forma de testar o caminho NVIDIA: as VMs não têm GPU NVIDIA e o VirtualBox 7 não faz passthrough
de PCI. O `noir` é híbrido (Intel + NVIDIA). Uma reinstalação do zero exercita a instalação do
driver (com o driver já funcionando, o bloco do role `nvidia` é pulado) e, com Secure Boot ligado,
a chave akmods **compartilhada de verdade** entre NVIDIA (role `nvidia`, 1º a importar) e
VirtualBox (role `apps`, 2º), que só foi visto em container. Fazer depois das VMs.

> **Retomar daqui (2026-10-02).** O `noir` é um ASUS TUF Gaming F15, híbrido (Intel + RTX 3050,
> **Ampere**). O usuário vai reinstalar o Fedora do zero e rodar o playbook **com tudo**: driver,
> Vulkan, VA-API/NVENC e o `/etc/modprobe.d/nvidia.conf` (`DynamicPowerManagement=0x02`, S0ix,
> `TemporaryFilePath`), que agora entram já na 2ª execução (ver abaixo). Problema conhecido:
> em instalações anteriores, **com** esse `nvidia.conf`, a dGPU ficava sempre ativa. Sem ele,
> o padrão do driver (`0x03`) já liga o RTD3 em notebooks Ampere, então o arquivo talvez nem seja
> necessário. Plano: conferir o item "dGPU dormindo (RTD3)" e, se a GPU não suspender, ajustar
> **removendo do role** o que atrapalhar (o `nvidia.conf` inteiro ou a linha culpada, testando uma
> por vez; suspeitos também: `supergfxd`, processos presos na GPU). Cada ajuste: mudar no repo,
> testar em container, rodar no `noir`, reiniciar e conferir de novo. Registrar aqui o que for
> descoberto.
>
> **Achado (2026-10-02): reboot gate não parou no `noir`.** A 1ª execução instalou o kernel 7.2.8
> (21:27) com o 7.2.5 rodando (boot às 21:22), e o `dnf needs-restarting -r` respondeu rc 0. Causa:
> o `noir` tem **dual boot com Windows** e o RTC em hora local (`RTC in local TZ: yes`). O systemd
> registrou o boot com horários errados (`UserspaceTimestamp` 18:22, `UnitsLoadStartTimestamp` 22:22),
> e o dnf5 (5.4.6) usa o `UnitsLoadStartTimestamp`, que ficou depois da instalação do kernel. Nas VMs e
> no Dell o RTC é UTC. Correções: (1) no playbook, o gate também compara `uname -r` com o
> `kernel-core` mais novo (validado em container: kernel mais novo instalado + `needs-restarting`
> rc 0 → para; kernel atual = mais novo → passa; sem `kernel-core` → passa); (2) no `noir`, opção A
> escolhida pelo usuário: RTC em UTC nos dois sistemas, no Windows com
> `reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`
> e no Fedora com `sudo timedatectl set-local-rtc 0`. Conferir depois: `timedatectl` → `RTC in
> local TZ: no`, a hora certa no Windows e, no Fedora, `systemctl show -p UnitsLoadStartTimestamp`
> igual ao `uptime -s`. Nada no playbook força o RTC em UTC, porque isso desacertaria o Windows.
>
> **Achado (2026-10-02): a dGPU sempre ativa não era o `nvidia.conf`.** No `noir` reinstalado, com o
> arquivo, `/proc/driver/nvidia/gpus/*/power` dizia `Runtime D3 status: Enabled (fine-grained)` e a
> GPU (`0000:01:00.0`) seguia `active`. Sem o arquivo (`DynamicPowerManagement: 3`, S0ix 0), também
> `active`. Culpado: o `ksystemstats` (sensores do Plasma) mantinha `nvidia-smi dmon -d 2 -s pucm`
> rodando, que consulta a GPU a cada 2 s, porque o widget "Monitor do Sistema" da área de trabalho
> mostrava `gpu/all/usage`. Matando só o `dmon`, a GPU foi para `suspended` em menos de 10 s. O
> `kwin_wayland` aparece no `nvidia-smi` (contexto C+G de 6 MiB, por causa da HDMI ligada à NVIDIA),
> mas **não** impede o RTD3 fine-grained. Ou seja: nenhum widget/monitor pode ler sensores da NVIDIA
> (`gpu/all/*`, `gpu/gpuN/*` da dGPU, `nvtop`, MangoHud etc.) se a GPU deve dormir.

Antes de reinstalar:
- [ ] Backup: `group_vars/all/secrets.yml` + senha do vault, `~/.ssh`, `~/.gnupg`, `~/.claude`,
      `~/wks` (repos com tudo commitado/pushado), perfis de navegador e o que mais for local.
- [ ] **Segundo disco (`thevoid`, LUKS em `/dev/nvme1n1p3`, ver `zsh_aliases`):** no instalador,
      selecionar **só** o disco do sistema. Não formatar nem montar o `nvme1n1`.
      O `noir` também tem **dual boot com Windows**: não apagar as partições dele (nem a EFI
      compartilhada) ao reinstalar.
- [ ] Firmware: ligar o Secure Boot (chaves padrão de fábrica) e deixar a GPU em modo
      **Hybrid**, para a tela seguir pela Intel enquanto o `nvidia` não carrega.
- [ ] Instalar o Fedora 44 com a edição usada no `noir`; `mokutil --sb-state` → `SecureBoot enabled`.
      Com o Windows no disco, o instalador deixa o RTC em hora local: antes do playbook,
      `sudo timedatectl set-local-rtc 0` (e o `RealTimeIsUniversal` no Windows; ver o achado acima).

Execuções (sempre o mesmo comando, de um terminal da sessão gráfica):
- [ ] `./bootstrap.sh` → hostname `noir`.
- [ ] **1ª execução** → para no reboot gate. Reiniciar.
- [ ] **2ª execução**: o role `nvidia` gera a chave (`MOK | Generate akmods signing key pair`),
      faz **um** `MOK | Request enrollment` e mostra o aviso de MOK; instala o driver, espera o
      build do akmods, roda `akmods --force` e `dracut`, e pede reboot. Na mesma execução, o
      `hardware` instala Vulkan e VA-API/NVENC (`nvidia_vulkan_packages`,
      `nvidia_multimedia_packages`) e grava `/etc/modprobe.d/nvidia.conf`. Antes essas três tasks
      dependiam do `has_nvidia_driver` (falso até o reboot) e ficavam para uma 3ª execução, que
      deixou de existir (validado em container em 2026-10-02: com `has_nvidia_driver: false` as três
      rodam; 2ª execução e `--check` com `changed=0`). Se o `noir` for ASUS (`is_asus`): COPR `asus-linux`,
      `asusctl`/`supergfxctl`, `supergfxd` ativo e o autostart do ROG Control Center. Mais adiante,
      a importação do `akmods_mok` pelo `apps` (VirtualBox) **não** gera chave nem import
      (`ok`/`skipping`). Termina com `failed=0`. `sudo ls -l /etc/pki/akmods/certs/` → um `.der` +
      o symlink.
- [ ] Reboot → MokManager → **Enroll MOK** → senha `fedora-afpi` → Reboot.
- [ ] `nvidia-smi` funciona; `modinfo -F signer nvidia` e `modinfo -F signer vboxdrv` → o mesmo
      signer (a chave única); `lsmod | grep -E "^nvidia|vboxdrv"`;
      `sudo mokutil --test-key /etc/pki/akmods/certs/public_key.der` → "already enrolled".
- [ ] PRIME: com `mesa-demos`, `glxinfo -B | grep renderer` → Intel e
      `nvidia-run glxinfo -B | grep renderer` → NVIDIA (alias do `.zshrc`).
- [ ] **dGPU dormindo (RTD3)**: `grep DynamicPowerManagement: /proc/driver/nvidia/params` → `2` (o driver 615 não expõe
      `/sys/module/nvidia/parameters/`)
      (do `nvidia.conf`). Com a GPU ociosa (nada no `nvidia-smi`; o próprio `nvidia-smi` acorda a
      GPU, esperar uns segundos depois dele): `cat /proc/driver/nvidia/gpus/*/power` →
      `Runtime D3 status: Enabled (fine-grained)` e
      `cat /sys/bus/pci/devices/<endereço do lspci>/power/runtime_status` → `suspended`;
      `supergfxctl -g` → `Hybrid`. Suspender e voltar sem travar.
      **Atenção:** em instalações anteriores, com este `nvidia.conf`, a dGPU do `noir` (RTX 3050,
      Ampere) ficava **sempre ativa**. Sem ele vale o padrão do driver (`0x03`), que já liga o RTD3
      em notebooks Ampere. Se ficar `active`: remover o `nvidia.conf` do role (ou isolar a linha
      culpada, testando uma de cada vez) e repetir a conferência.
      No `noir` atual o driver foi instalado antes dessa mudança, sem as três tasks: a próxima
      execução as aplica; depois reiniciar e conferir.
- [ ] Steam: `~/.local/share/applications/steam.desktop` com o `__NV_PRIME_...` e o jogo/launcher
      aparecendo no `nvidia-smi`.
- [ ] **3ª execução**: `changed=0`, sem aviso de MOK nem de reboot; depois `--check` → `failed=0`.
- [ ] Na próxima atualização de kernel de verdade: depois do reboot, `modinfo -F signer nvidia`
      no kernel novo (o `akmods` recompila e assina no boot) e `nvidia-smi` funcionando.
- [x] Decidir se o `noir` fica com Secure Boot ligado ou volta a desligar. Decidido (2026-10-02):
      **sempre ligado**, nunca desativar. O `CLAUDE.md` foi atualizado. Consequência: a chave
      akmods e o enroll do MOK precisam funcionar sempre no `noir`. Ajustes de power management não
      podem passar por desligar o Secure Boot.

## 6. Documentação

- [x] README: explicar o reboot gate. A 1ª execução numa máquina recém-atualizada para depois do
      upgrade: reiniciar e rodar o mesmo comando de novo. Revisar também o fluxo em 5 passos com
      tags da seção "NVIDIA Users", que o gate simplifica (`update` → reboot → resto).
      Feito (2026-10-02): aviso do reboot gate em "Run the Playbook" e nova seção "NVIDIA and
      Secure Boot" (rodar o mesmo comando 3×, com reboot depois do update e depois do driver/MOK; a
      3ª instala Vulkan/VA-API, que dependem do `nvidia-smi` funcionando). Role `update` e o
      bloco de MOK descritos de acordo (o MOK agora é do `akmods_mok`).

---

## 7. Hostname perguntado no `bootstrap.sh`

- [x] 🟠 O `system_hostname: "noir"` fixo no `all.yml` renomeava qualquer máquina (inclusive as VMs
      de teste) para `noir`. Agora o `bootstrap.sh` pergunta o hostname (padrão: o valor já salvo
      ou o hostname atual; Enter mantém), valida (RFC 1123: letras, dígitos e `-`, até 63) e grava
      em `host_vars/127.0.0.1.yml` (no `.gitignore`), que vence o `group_vars/all`. O `all.yml` fica
      com `system_hostname: ""` e a task só roda quando há nome. Perguntar no bootstrap, e não com
      `vars_prompt`, evita que o playbook pare para pedir algo a cada execução (até com `--tags`).
      Sem terminal (`stdin` não é tty), o bootstrap não pergunta e não grava nada.
      Validado (2026-10-02) em container `fedora:44` (`script` para simular o terminal): nome
      inválido (`-bad-`) é recusado e pergunta de novo; nome válido gravado; 2ª execução com Enter
      mantém o salvo; máquina nova com Enter grava o hostname atual; sem tty só avisa;
      `ansible … -m debug -a var=system_hostname` → o nome com o `host_vars`, `""` sem ele; sem
      `host_vars` a task `System | Set System Hostname` é pulada; `git check-ignore` confirma.
      Aplicado de verdade nas VMs (2026-10-02, seção 5, etapas 1 e 4): `hostnamectl hostname` →
      o nome dado no bootstrap.
      No `noir`: rodar o `./bootstrap.sh` uma vez e responder `noir` (ou só Enter, que mantém o atual).

---

## Ordem sugerida

1. ~~`is_secure_boot` → MOK idempotente → reboot gate (seção 1)~~ — feito
2. ~~Enroll akmods compartilhado → `mok_password` (seção 2)~~ — feito
3. ~~Handler do GRUB → assert de distro (seção 3)~~ — feito
4. ~~Polimento de idempotência / `--check` (seção 4)~~ — feito (o `--check` geral ficou para as VMs)
5. ~~README do reboot gate (seção 6)~~ — feito
6. ~~Roteiro nas VMs GNOME e KDE com Secure Boot (seção 5, etapas 0–7)~~ — feito
7. NVIDIA no `noir` reinstalado com Secure Boot (seção 5, etapa 8), depois das VMs
