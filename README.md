# AFPI (Advanced Fedora Post-Install) - Ansible Role-Based

AFPI é um sistema modular e inteligente para a pós-instalação do Fedora Workstation. Ele utiliza uma arquitetura baseada em **Roles** e **Templates Dinâmicos**, permitindo que sua personalização de desktop e otimizações de hardware sejam aplicadas de forma consistente, tornando o deploy do seu ambiente de trabalho totalmente automatizado e "hardware-aware".

## 🏗️ Arquitetura e Roles

O projeto é organizado para isolar responsabilidades, garantindo idempotência e facilidade de manutenção:

*   **`common`**: Otimizações de sistema (DNF, RPM Fusion), limpeza de kernels e configuração do **Zero-Config ZSH** (Oh-My-Zsh com tema Kali-like e plugins auto-gerenciados).
*   **`hardware`**: Detecção e instalação de drivers (NVIDIA assinado para Secure Boot, Intel, AMD), codecs multimídia e suporte ASUS ROG.
*   **`desktop`**: 
    *   **Layout Plasma Real**: Automação completa do layout do KDE via template Jinja2, preservando posições de widgets, painéis e configurações de transparência.
    *   **Detecção Inteligente**: Identifica automaticamente UUIDs de disco, GPUs e IDs de bateria para que os widgets de monitoramento funcionem sem intervenção manual.
    *   **Visual**: Gestão unificada de wallpapers (Desktop/SDDM) e perfis de terminal (Konsole/PTYxis).
*   **`apps`**: Suite completa via DNF e Flatpak, com automação de GPU para Steam e produtividade (Brave, VS Code).
*   **`ai_tools`**: Integração do ecossistema de IA (Gemini CLI e extensões) e bibliotecas Python via `pipx`.

## 🔐 Gestão de Segredos (Ansible Vault)

O AFPI utiliza o **Ansible Vault** para proteger informações sensíveis como tokens de API e senhas.

### Criptografar pela primeira vez
```bash
ansible-vault encrypt group_vars/all/secrets.yml
```

### Editar segredos existentes
Não abra o arquivo diretamente. Use o comando abaixo para editar em texto puro (o Ansible criptografará de volta ao salvar):
```bash
ansible-vault edit group_vars/all/secrets.yml
```

### Descriptografar permanentemente
```bash
ansible-vault decrypt group_vars/all/secrets.yml
```

### Criptografar Foto de Perfil (Privacidade Total)
Para evitar subir sua foto pessoal para o repositório, você pode guardá-la criptografada no Vault:
1. Gere a string: `base64 -w 0 path/to/photo.jpg > string.txt`
2. Adicione ao `secrets.yml`: `user_profile_picture_base64: "CONTEUDO_DO_STRING.TXT"`
3. O AFPI detectará a variável e criará o arquivo `.face.icon` dinamicamente.

### Executar o Playbook com Segredos
Sempre que houver arquivos criptografados, adicione `--ask-vault-pass`:
```bash
ansible-playbook -i inventory.ini site.yml --ask-vault-pass -K
```

## 🚀 Como Começar

### 1. Bootstrap do Sistema
Prepare o ambiente Ansible:
```bash
./bootstrap.sh
```

### 3. Executar o Playbook
Aplique a configuração completa:
```bash
ansible-playbook -i inventory.ini site.yml --ask-vault-pass -K
```

## 🛠️ Diferenciais do AFPI

### Hardware-Aware Configuration
O AFPI interage com o hardware real. Se você trocar de máquina, ele detectará o novo UUID do disco e os novos sensores de bateria, ajustando os arquivos de configuração do Plasma dinamicamente antes de aplicá-los.

### Zero-Config Shell
A configuração do ZSH foi simplificada. O tema `kali-like-alt` gerencia suas próprias dependências (syntax highlighting e autosuggestions), reduzindo a complexidade do playbook e o tempo de execução.

### Correção Universal de Cedilha (ç)
Ajuste fino em três camadas (Sistema, Flatpak e Ozone/X11) para garantir que a cedilha funcione perfeitamente em todos os aplicativos, inclusive navegadores e ferramentas de comunicação.

