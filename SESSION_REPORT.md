# AFPI Project Session Report - April 17, 2026 (Final Refinement)

## 🎯 Objective
Validar o deploy real em VM, corrigindo falhas de comunicação com a sessão gráfica (D-Bus), compatibilidade com Plasma 6 e resiliência do DNF.

## 🏗️ Evolução Técnica

### 📂 Otimização de Core
- **`ansible.cfg`**: Adicionado arquivo de configuração com `pipelining = True` e `become_ask_pass = True`, acelerando o deploy e eliminando a necessidade do parâmetro `-K` manual.
- **Git Sync:** Repositório local vinculado com sucesso ao GitHub ([phguima/afpi](https://github.com/phguima/afpi)).

## 🚀 Vitórias Técnicas e Correções (VM Test Phase)

### 1. Compatibilidade Plasma 6 (Fedora 43+)
- **KDE Extensions:** Corrigido o erro de metadados inválidos mudando os tipos de pacote para `Plasma/Applet` e `KWin/Script`.
- **D-Bus Bridge:** Implementada injeção de barramento de sessão (`export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus`) em todas as tarefas que interagem com a interface gráfica, permitindo que o Ansible mude wallpapers e instale widgets corretamente.
- **Robustez KNS:** Retorno ao método nativo do `kpackagetool6` após falhas de download direto da KDE Store, garantindo que o próprio KDE gerencie os redirecionamentos da loja.

### 2. Estabilidade do Sistema (DNF & Kernel)
- **Kernel Protection:** Ajustada a tarefa de limpeza para ignorar explicitamente o kernel em execução (`uname -r`), evitando que o DNF aborte a execução por motivos de segurança.
- **DNF5 Syntax:** Corrigida a sintaxe do `config-manager` para desativação de repositórios debug, garantindo compatibilidade com as versões mais recentes do Fedora.

### 3. Lógica de Deploy
- **Ordem de Execução:** Movidos os fixes de cedilha (Brave/Chromium) da role `desktop` para a role `apps`, garantindo que a configuração só ocorra **após** a instalação física dos navegadores.
- **Hardware Detection:** Evolução do comando de detecção de disco para `findmnt -no UUID /`, tornando-o imune a problemas de caminhos complexos em subvolumes Btrfs.

---

## 🔄 Como Retomar a Próxima Sessão
Para continuar, forneça o seguinte prompt:
> **"Nexus, vamos retomar o AFPI. O sistema está blindado e testado em VM. Algum novo app ou tweak para o setup principal?"**

### Estado Atual:
- [x] Repositório Git limpo e sincronizado (sem arquivos temporários).
- [x] Instalação de widgets KDE funcional via D-Bus.
- [x] Aplicação de wallpaper forçada e persistente.
- [x] Proteção de kernel e detecção de hardware robustas.

### Próximos Passos Sugeridos:
1.  **Deploy em Máquina Real:** Agora que a VM passou, o projeto está pronto para a estação de trabalho principal.
2.  **Monitoramento de RAM:** Adicionar avisos no README sobre a RAM necessária para instalar pacotes pesados como Android Studio (erro OOM rc-9).

---

