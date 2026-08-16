# VM de desenvolvimento Debian 13

## Objetivo

A VM `flavos-build-trixie` isola o ambiente oficial de build do Flavos OS 3.0.
Ela é instalada pela netinst oficial e não é uma imagem Flavos nem um alvo de
homologação de hardware.

## Recursos padrão

- firmware UEFI com OVMF;
- 4 vCPUs;
- 4 GB de RAM;
- disco QCOW2 esparso de 40 GB;
- rede NAT do QEMU;
- SSH exposto somente em `127.0.0.1:2222`;
- KVM quando o dispositivo estiver acessível, com fallback explícito para TCG.

Os recursos podem ser alterados por variáveis de ambiente, mas 8 GB de RAM só
devem ser usados quando o host tiver memória disponível suficiente.

## Preparação

No host Debian/Ubuntu/Mint, os scripts da VM utilizam estas dependências:

```bash
sudo apt install qemu-system-x86 qemu-system-gui qemu-utils ovmf virt-viewer
```

Confirme que a ISO está no caminho esperado e valide sua integridade:

```bash
./tools/verify-debian-iso.sh
```

Crie o disco e o estado UEFI sem iniciar a VM:

```bash
./tools/create-build-vm.sh
```

Os artefatos ficam em `image/.vm/flavos-build-trixie/`, que é ignorado pelo Git.
Os scripts são idempotentes e não substituem disco ou estado UEFI existentes.

## Instalação

Inicie o instalador com:

```bash
./tools/run-build-vm.sh install
```

Seleções recomendadas no Debian Installer:

1. hostname `flavos-build-trixie`;
2. deixar os campos de senha de `root` vazios, desabilitando login direto de root;
3. criar um usuário normal com senha local forte, que receberá acesso a `sudo`;
4. particionamento guiado do disco virtual, com todos os arquivos em uma partição;
5. nenhum ambiente desktop;
6. somente **SSH server** e **standard system utilities** na seleção de software;
7. instalação normal do carregador de boot no disco virtual.

Não armazene tokens, chaves de release ou outras credenciais permanentes na VM.

Depois que a instalação terminar e a VM desligar, inicialize apenas pelo disco:

```bash
./tools/run-build-vm.sh boot
```

O acesso SSH, quando o serviço estiver ativo, usa:

```bash
ssh -p 2222 USUARIO@127.0.0.1
```

Se uma senha de root tiver sido definida no instalador e o usuário normal não
receber `sudo`, não é necessário reinstalar. Entre como root com `su -` e execute:

```bash
apt update
apt install sudo
usermod -aG sudo USUARIO
```

Saia da sessão e entre novamente com o usuário normal antes de testar `sudo -v`.

## Dependências do M0 dentro da VM

```bash
sudo apt update
sudo apt install \
  git \
  live-build \
  qemu-system-x86 \
  qemu-utils \
  ovmf \
  xorriso \
  squashfs-tools
```

Após instalar as dependências, clone o repositório
`https://github.com/GauaJ1/Flavos-OS-3.0.git` dentro da VM.

## Display VNC

Se o display GTK não estiver disponível, inicie a VM com VNC restrito ao
loopback:

```bash
FLAVOS_VM_DISPLAY=vnc ./tools/run-build-vm.sh install
```

Em outro terminal:

```bash
remote-viewer vnc://127.0.0.1:5901
```

## Variáveis suportadas

| Variável | Padrão | Uso |
|---|---|---|
| `FLAVOS_VM_MEMORY_MB` | `4096` | memória da VM em MiB |
| `FLAVOS_VM_CPUS` | `4` | quantidade de vCPUs |
| `FLAVOS_VM_DISK_SIZE` | `40G` | tamanho virtual na criação do disco |
| `FLAVOS_VM_SSH_PORT` | `2222` | porta SSH no loopback do host |
| `FLAVOS_VM_DISPLAY` | `gtk` | backend `gtk` ou `vnc` |
| `FLAVOS_VM_DIR` | `image/.vm/flavos-build-trixie` | diretório local da VM |
| `FLAVOS_DEBIAN_ISO` | ISO netinst em `image/` | caminho alternativo da ISO |
| `FLAVOS_OVMF_CODE` | `/usr/share/OVMF/OVMF_CODE_4M.fd` | firmware UEFI somente leitura |
| `FLAVOS_OVMF_VARS` | `/usr/share/OVMF/OVMF_VARS_4M.fd` | template do estado UEFI |

## Diagnóstico

Se aparecer o aviso sobre TCG, verifique no host:

```bash
ls -l /dev/kvm
id -nG
```

O script testa acesso efetivo ao dispositivo; apenas o módulo carregado ou a
presença do grupo `kvm` não são suficientes. Não crie `/dev/kvm` manualmente.
