# AFPI — instruções para o Claude

AFPI (Ansible Fedora Post-Install): playbook Ansible que configura uma workstation Fedora (41–44)
depois da instalação. Repo `phguima/afpi`, branch única `main`. A máquina-alvo é a máquina pessoal
do usuário (hostname `noir`: ASUS TUF Gaming F15, híbrido Intel + NVIDIA RTX 3050 (Ampere), Fedora 44,
**Secure Boot sempre ligado**: decisão do usuário, nunca desligar nem sugerir desligar; **dual boot com
Windows**, além do disco `thevoid`). O usuário conversa em português.

O **AAPI** (`phguima/aapi`, em `../aapi` no workspace original) é o port deste projeto para
AlmaLinux 10 (máquina do trabalho). Várias melhorias de arquitetura nasceram lá e estão sendo
trazidas para cá. Ao portar algo do AAPI, adaptar o que é do EL10 (dnf4, EPEL/CRB, nomes de pacote).

## Estado do trabalho

`TODO.md` (em português) tem **só o que falta**. **Ler antes de começar.** O histórico (itens
feitos, achados como o reboot gate com RTC em hora local e a dGPU acordada pelo widget de GPU do
Plasma, e como cada item foi validado) foi tirado dele em 2026-10-04 e fica no git:
`git show aa885a2:TODO.md`. Ao concluir um item, removê-lo do `TODO.md` e registrar a validação na
mensagem do commit; tarefa nova entra no `TODO.md` até ser feita.

## Estrutura

- `site.yml`: play único em `localhost` com `become: yes`. `pre_tasks` importa
  `tasks/env_setup.yml` (facts: usuário, GPU, DE, `is_secure_boot`, assert de distro). Ordem dos
  roles: `update` → `nvidia` → `hardware` → `common` → `apps` → `desktop` → `ai_tools`. O handler
  `Regenerate GRUB` fica no próprio `site.yml`.
- `roles/akmods_mok`: chave de assinatura akmods + enroll MOK (só com Secure Boot). Não está no
  `site.yml`: é importado (`import_role`) pelo `nvidia` e pelo `apps` antes dos pacotes akmod
  (driver NVIDIA, VirtualBox do RPM Fusion). Idempotente: importar duas vezes não faz nada.
- `roles/update` termina com um **reboot gate**: `dnf needs-restarting -r` → rc 1, **ou** kernel em
  execução diferente do `kernel-core` mais novo, encerra o play pedindo reboot (`meta: end_host`).
  Numa máquina nova a 1ª execução quase sempre para ali. A comparação de kernels existe porque o
  `needs-restarting` usa a hora de boot do systemd, errada com o RTC em hora local (dual boot com
  Windows): no `noir` ele deu rc 0 logo depois de instalar um kernel novo. Não criar task que force o
  RTC em UTC: em dual boot, isso desacerta o relógio do Windows.
- `group_vars/all/all.yml`: todas as variáveis, inclusive `mok_password`. O `system_hostname` e a
  identidade do git (`git_user_name`, `git_user_email`) ficam vazios (= não mexe): o `bootstrap.sh`
  pergunta e grava em `host_vars/127.0.0.1.yml` (no `.gitignore`, por máquina), que vence o
  `group_vars`. Nada pessoal fixo no repo: **o AFPI também é usado por outras pessoas**. Nada no
  playbook pede input durante a execução: perguntas vão para o `bootstrap.sh`.
- Sem vault desde 2026-10-04: `api_keys` é `""` no `all.yml` (vazio = sem linhas de API no
  `.zshrc`). Quem quiser chaves cria um vault opcional em `group_vars/all/secrets.yml` (no
  `.gitignore`, nunca commitado; ver o README). Se ele existir, o Claude não tem a senha: não tentar
  abrir. Os arquivos de `group_vars/all/` carregam em ordem alfabética, então o vault vence o `all.yml`.
- Execução real (só o usuário, na máquina dele):
  `ansible-playbook -i inventory.ini site.yml -K` (`./bootstrap.sh` antes, na primeira vez;
  `--ask-vault-pass` só com o vault opcional).

## Convenções

- Commits em inglês, Conventional Commits com escopo: `feat(update): …`, `fix(nvidia): …`,
  `docs(todo): …`, `chore(git): …`.
- Nomes de task no formato `Área | Ação` (`MOK | Request enrollment`), comentários em inglês,
  explicando o *porquê* (ver os existentes).
- Leituras (`command`/`shell` que só consultam) levam `changed_when: false` e, quando os facts
  precisam valer no `--check`, `check_mode: false`.
- Segredos passados a comandos vão por `stdin:` com `no_log: true`, nunca por `echo` na linha de comando.

## Git

- Começar com `git fetch` + `git pull --ff-only`: o usuário também commita de outras máquinas
  (já aconteceu de o push ser rejeitado por isso). Conferir de novo antes de cada push.
- Commit e push **só quando o usuário pedir**. Se o remoto andou, ver o que veio
  (`git log HEAD..origin/main`) antes do rebase.

## Testes — NUNCA no host

Os testes rodam **só em container (podman) ou na VM do usuário**, nunca na máquina do usuário,
nem playbooks só de leitura, nem `--check`. Ler arquivos do host ou consultar o rpm é ok; rodar
o playbook ou partes dele, não.

Receitas que funcionaram (imagem `registry.fedoraproject.org/fedora:44`):

- Base: `podman run --rm -v <repo>:/afpi:ro,z -v <scratch>:/t:ro,z fedora:44 sh -c 'dnf install -y -q ansible-core pciutils; …'`.
  Para módulos `community.general` (ex.: `copr`), rodar também
  `ansible-galaxy collection install community.general`, **sem `-q`**: com `-q` uma falha passa
  despercebida e o erro aparece depois, em outro task.
- Usar `:z` (rótulo SELinux compartilhado), não `:Z`, quando o mesmo diretório é montado em vários
  containers. Com `:Z` cada um toma o rótulo do anterior e dá "Permission denied".
- Playbook de teste fora do repo não carrega o `group_vars/`: passar `-e @/afpi/group_vars/all/all.yml`.
  Para rodar o `site.yml` real: copiar o repo para dentro do container, apagar o `secrets.yml` e usar
  `ANSIBLE_BECOME_ASK_PASS=False ansible-playbook site.yml --tags <tag> -e ansible_become=false`.
- Roles por nome (`import_role: name: akmods_mok`) fora do `site.yml`: `ANSIBLE_ROLES_PATH=/afpi/roles`.
- Booleanos por `-e` precisam ser JSON (`-e '{"is_nvidia": true}'`). `-e is_nvidia=true` vira
  string e o ansible-core 2.20 recusa em condicional.
- Secure Boot falso: montar um diretório com `efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c`
  (bytes `06 00 00 00 01` = ligado, `… 00` = desligado) **por cima de `/sys/firmware`** com
  `--security-opt unmask=/sys/firmware -v <dir>:/sys/firmware:ro,z`. Montar um arquivo dentro do
  sysfs não funciona. Sem a montagem, o container não tem efivars (= BIOS legado).
- `mokutil` falso em `/usr/local/bin` que registra as chamadas e simula os estados
  (`not enrolled` rc 0 / `is already enrolled` / `is already in the enrollment request` rc 1). O
  `kmodgenca` pode ser o real (pacote `akmods`).
- Wrapper de `dnf` em `/usr/local/bin` para forçar o rc do `dnf needs-restarting`. Não afeta o
  módulo `ansible.builtin.dnf`, que usa a libdnf5. No container o `needs-restarting` real devolve
  rc 1 depois de um upgrade (usa o horário de boot do host).
- Driver NVIDIA no container: `-e '{"is_nvidia": true, "nvidia_driver_packages": ["kmodtool"]}'`
  para não baixar ~1 GB. O módulo não carrega no container de qualquer jeito.
- `grub2-mkconfig` não funciona em container (não sonda o disco): usar um falso que registra o `-o`.
- Tasks só do GNOME (Ptyxis): container de longa duração (`podman run -d … sleep infinity` + `podman exec`)
  com `sudo dbus-daemon dconf ptyxis`, um usuário comum com `NOPASSWD`, `Defaults env_keep +=
  "DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR"` (faz o papel do `pam_systemd` no host real) e um
  `dbus-daemon --session --address=unix:path=/run/user/1000/bus --fork` desse usuário. O playbook
  roda **como o usuário**, com `XDG_CURRENT_DESKTOP=GNOME` e `ANSIBLE_BECOME_ASK_PASS=False`
  (o `env_setup` usa o `SUDO_USER`). Ao rodar `podman exec … sh -c` com `--fork`, usar `</dev/null`
  e redirecionar a saída, senão o exec não retorna. O `ansible-galaxy` como esse usuário travou:
  instalar como root com `-p /usr/share/ansible/collections`.
- O `site.yml` completo **não** roda num container comum: sem systemd (serviços, `hostname`), sem
  `/etc/default/grub` (para testar o bloco de API, `-e 'api_keys="# fake"'`). O `--check` geral é só na VM.
- Rodar duas vezes para conferir a idempotência (`changed=0` na 2ª) e testar o `--check`.
- zsh: escrever `${VAR}:ro`, não `$VAR:ro` (o zsh lê `:r` como modificador).
- Ao terminar, remover os containers (`podman rm -f`).

O que depende de hardware (enroll real no MokManager, módulos carregando, reboot de verdade) é
testado pelo usuário em duas VMs com Secure Boot, uma GNOME e outra KDE (roteiro na seção 5 do
`TODO.md` histórico, `git show aa885a2:TODO.md`). Deixar no `TODO.md` o que falta conferir lá.

## Particularidades do Fedora

- `dnf` é o dnf5. O `dnf needs-restarting` vem do `dnf5-plugins` (o `dnf-plugins-core` é o dnf4).
  Opções do comando vão **depois** do subcomando: `dnf list kernel --showduplicates`, não
  `dnf --showduplicates list kernel` (sintaxe do dnf4).
  O `community.general.dnf_config_manager` usa a sintaxe do dnf4 (`--set-disabled`): aqui, usar
  `dnf config-manager setopt <repo>.enabled=0`.
- O `mokutil` vem com qualquer instalação UEFI (dependência do `shim-x64`).
- `/etc/grub2-efi.cfg` é só um symlink para `/boot/grub2/grub.cfg` (o arquivo real, em UEFI e BIOS).
- `kmodgenca --force` cria um par de chaves novo a cada execução e repõe os symlinks
  `/etc/pki/akmods/{certs/public_key.der,private/private_key.priv}`. Nunca usar `--force`.
