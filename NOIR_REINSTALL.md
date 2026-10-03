# noir: passo a passo depois da reinstalação (temporário)

> Arquivo temporário da etapa 8 do `TODO.md` (NVIDIA no `noir` com Secure Boot). Apagar quando a
> etapa terminar. Os detalhes e o histórico (RTD3, achado do RTC) ficam no `TODO.md`.

## 1. Conferências iniciais

```bash
mokutil --sb-state                 # SecureBoot enabled
timedatectl | grep "RTC in local"  # provavelmente "yes", por causa do Windows
sudo timedatectl set-local-rtc 0   # RTC em UTC
```

No Windows (se ainda não feito), num prompt de administrador:

```
reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
```

## 2. Clonar e bootstrap

O repo é público: clone por https, sem chave SSH.

```bash
git clone https://github.com/phguima/afpi.git ~/afpi && cd ~/afpi
./bootstrap.sh                     # hostname: noir
```

## 3. 1ª execução

Sempre de um terminal da sessão gráfica:

```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass
```

Deve parar no reboot gate ("needs a REBOOT"). **Reiniciar.**

## 4. 2ª execução

Mesmo comando. Instala driver NVIDIA, Vulkan, VA-API, `nvidia.conf` e todo o resto; gera a chave
akmods e mostra o aviso de MOK.

```bash
sudo ls -l /etc/pki/akmods/certs/    # um .der + o symlink public_key.der
sudo mokutil --list-new              # a chave pendente
```

## 5. Reboot e enroll

Tela azul do MokManager: **Enroll MOK** → Continue → Yes → senha `fedora-afpi` → Reboot.

## 6. Driver

```bash
nvidia-smi
modinfo -F signer nvidia; modinfo -F signer vboxdrv               # o mesmo signer
sudo mokutil --test-key /etc/pki/akmods/certs/public_key.der      # already enrolled
```

## 7. dGPU suspendendo (RTD3)

Esperar alguns segundos depois do último `nvidia-smi` (ele acorda a GPU).

```bash
cat /sys/module/nvidia/parameters/DynamicPowerManagement    # 2
cat /proc/driver/nvidia/gpus/*/power                        # Runtime D3 status: Enabled (fine-grained)
lspci | grep -i nvidia                                      # anotar o endereço (ex.: 01:00.0)
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status  # suspended?
supergfxctl -g                                              # Hybrid
```

Se ficar `active` sem nada usando a GPU: guardar as saídas e ajustar o `nvidia.conf` (ver o bloco
"Retomar daqui" da etapa 8 no `TODO.md`).

## 8. 3ª execução (idempotência)

Mesmo comando: `changed=0`, sem aviso de MOK nem de reboot. Depois:

```bash
ansible-playbook -i inventory.ini site.yml -K --ask-vault-pass --check   # failed=0
```

O restante (PRIME, Steam, próximo kernel) está na etapa 8 do `TODO.md`.
