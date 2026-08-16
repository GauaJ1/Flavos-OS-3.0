# Flavos OS 3.0 — Guia Oficial de Início

## Foundation / Project Bootstrap v0.1

### 1. Base oficial

**Sistema-base:** Debian 13 “Trixie”
**Arquitetura:** amd64 / x86-64
**Imagem de referência:** Debian 13.6.0 netinst
**Desktop Debian:** nenhum.

O Flavos OS não deverá começar de Debian XFCE, GNOME, KDE ou outro desktop pronto.

A estratégia será:

Debian mínimo → infraestrutura Linux → componentes Flavos → Flavos Desktop.

O Debian 13 suporta instalação amd64; i386 não é mais arquitetura de instalação independente nessa versão, portanto o alvo legado do Flavos deve continuar sendo máquinas antigas **x86-64**, como boa parte da geração Core 2.

### 2. Download oficial

Página oficial recomendada:

https://www.debian.org/download.pt.html

ISO atual:

https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.6.0-amd64-netinst.iso

Checksum:

https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA512SUMS

Guia oficial de instalação:

https://www.debian.org/releases/stable/amd64/

O Debian confirma atualmente `debian-13.6.0-amd64-netinst.iso` como a imagem netinst para PC 64 bits.

---

# 3. Uma regra importante

**Não vamos editar/remasterizar manualmente a ISO do Debian.**

A netinst será útil para montar máquinas de desenvolvimento e entender nossa base.

A ISO do Flavos deverá ser **gerada pelo projeto**, utilizando principalmente `live-build`.

O próprio Debian mantém `live-build` como ferramenta para construir sistemas e imagens Live a partir de uma configuração.

Documentação:

https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html

Pacote:

https://packages.debian.org/trixie/live-build

---

# 4. Criar o projeto

Estrutura inicial:

```text
flavos-os/
│
├── README.md
│
├── docs/
│   ├── VISION.md
│   ├── ARCHITECTURE.md
│   ├── FLOW.md
│   ├── ADAPTIVE_UI.md
│   ├── HARDWARE.md
│   ├── BUILD.md
│   ├── ROADMAP.md
│   └── adr/
│
├── image/
│   ├── auto/
│   └── config/
│
├── src/
│   ├── flow/
│   ├── session/
│   ├── shell/
│   ├── settings/
│   └── adaptive/
│
├── packages/
├── assets/
├── tools/
├── tests/
└── releases/
```

Tudo deve estar versionado em Git desde o primeiro dia.

---

# 5. Documentação antes da interface

Antes de desenvolver launcher, painel ou animações, criar:

**VISION.md**

Define o que é o Flavos OS.

**ARCHITECTURE.md**

Define a arquitetura geral.

**FLOW.md**

Especificação completa do Flavos Flow.

Importante:

Flow salva contexto e metadata.

Flow **não usa hibernação como fundamento** e não salva uma imagem completa da RAM.

**ADAPTIVE_UI.md**

Define como a interface adapta efeitos gráficos ao hardware sem remover recursos.

**HARDWARE.md**

Define hardware mínimo, recomendado e matriz de testes.

**BUILD.md**

Explica como produzir uma ISO do zero.

**ROADMAP.md**

Milestones oficiais.

**docs/adr/**

Architecture Decision Records.

Toda decisão arquitetural importante deverá ganhar um ADR.

Exemplo:

```text
ADR-001-debian-base.md
ADR-002-display-stack.md
ADR-003-ui-toolkit.md
ADR-004-flow-storage.md
```

Assim não repetiremos decisões indefinidamente.

---

# 6. Máquina de desenvolvimento

Criar primeiro uma VM limpa com Debian 13 amd64.

Instalar as ferramentas básicas:

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

O desenvolvimento da ISO deve inicialmente ocorrer dentro de Debian para reduzir diferenças entre ambiente de build e sistema-base.

---

# 7. Primeiro objetivo técnico

**Não construir o Flavos Desktop ainda.**

O primeiro milestone é conseguir gerar:

```text
Flavos Build System
        ↓
Debian Trixie
        ↓
ISO híbrida
        ↓
Boot
        ↓
Kernel
        ↓
systemd
        ↓
TTY
```

Nada além disso.

Um primeiro experimento com `live-build` pode começar com:

```bash
mkdir image
cd image

lb config \
  --distribution trixie \
  --architecture amd64 \
  --binary-image iso-hybrid

sudo lb build
```

O Debian Live Manual usa justamente `lb config` seguido de `lb build` como fluxo básico para produzir uma ISO híbrida.

Quando essa ISO inicial puder ser reconstruída consistentemente, avançamos.

---

# 8. Milestones oficiais

## M0 — Bootstrap

Objetivo:

```text
ISO
→ BIOS/UEFI
→ kernel
→ systemd
→ TTY
```

Sem interface Flavos.

---

## M1 — Graphical Foundation

Escolher e implementar:

* Wayland/X strategy;
* compositor/window manager;
* login/session;
* input;
* áudio;
* rede;
* gerenciamento de energia.

Nenhum componente deve ser escolhido simplesmente porque “é comum em Linux”.

Cada decisão deverá ser documentada.

---

## M2 — Flavos Shell

Criar a experiência básica:

```text
Flavos Session
Flavos Panel
Flavos Launcher
Flavos Notifications
Flavos Settings
Flavos Files integration
```

Aqui a máquina começa a parecer Flavos OS.

---

## M3 — Flavos Flow

Primeiro protótipo:

```text
flavos-flowd
```

Inicialmente deve salvar apenas:

* aplicativos;
* janelas;
* posição;
* workspace;
* pastas;
* contexto suportado.

Depois:

* integração com apps;
* prioridades;
* Progressive/Gentle Restore.

---

## M4 — Adaptive Experience

Detectar capacidade gráfica e hardware.

Aplicar automaticamente perfis como:

```text
ECO
BALANCED
FULL
```

A diferença deve estar em:

* blur;
* transparência;
* sombras;
* animações;
* efeitos;
* tarefas visuais secundárias.

**Nunca nas funcionalidades disponíveis.**

Um computador antigo continua recebendo o Flavos OS completo.

---

## M5 — Live + Installer

Somente depois da base estar sólida:

```text
Live Boot
Installer
Partitioning
User creation
Bootloader
OOBE
```

---

## M6 — Hardware Lab

Testar:

```text
Legacy x86-64
Core 2 era
4 GB RAM
HDD

↓

Intermediate
8 GB RAM
iGPU
SSD

↓

Modern
16/32+ GB
NVMe
GPU moderna
```

VMs são úteis, mas testes finais de hardware antigo precisarão de máquinas físicas.

---

## M7 — Alpha

Primeira imagem:

**Flavos OS 3.0 Developer Alpha**

Só então começar ciclo público de testes.

---

# 9. Tecnologias que NÃO devem ser decididas às pressas

O agente não deverá escolher sozinho e começar a implementar imediatamente:

```text
Wayland vs X11/fallback
compositor
GTK vs Qt/QML
display manager
filesystem
installer
Flatpak
package policy
update system
recovery
snapshot system
```

Cada uma dessas decisões afeta anos de desenvolvimento.

Devemos pesquisar e criar um ADR antes.

---

# 10. Arquitetura conceitual inicial

```text
                 FLAVOS OS 3.0
                       │
            ┌──────────┴──────────┐
            │                     │
        Flavos Flow       Adaptive Experience
            │                     │
            └──────────┬──────────┘
                       │
                 Flavos Shell
                       │
                Flavos Session
                       │
               System Services
                       │
                  systemd
                       │
                Debian Trixie
                       │
                 Linux Kernel
```

O systemd já fornece infraestrutura de gerenciamento de serviços, ativação sob demanda, D-Bus e cgroups, então devemos utilizar essas capacidades em vez de recriá-las em scripts Flavos.

Documentação:

https://systemd.io/

D-Bus:

https://dbus.freedesktop.org/

---

# 11. Regras de arquitetura

### Regra 1

Nenhum wrapper de wrapper.

### Regra 2

Um componente deve possuir uma responsabilidade clara.

Exemplo:

```text
flavos-session
→ sessão

flavos-flowd
→ Flow

flavos-adaptive
→ adaptação

flavos-shell
→ interface principal
```

### Regra 3

Nenhum fallback improvisado sem documentação.

### Regra 4

O build precisa ser reproduzível.

### Regra 5

A interface nunca deve controlar diretamente funções críticas do sistema.

### Regra 6

O Debian fica abaixo do Flavos; não devemos modificar componentes upstream sem necessidade.

### Regra 7

Performance é requisito, não etapa de otimização no final.

---

# 12. Primeira tarefa do projeto — 11/08/2026

Amanhã NÃO começaremos pelo Flow.

Também NÃO começaremos pela interface.

Ordem:

```text
1. Baixar Debian 13
2. Criar ambiente Debian de desenvolvimento
3. Criar repositório flavos-os
4. Criar documentação inicial
5. Instalar live-build
6. Criar configuração mínima
7. Gerar ISO Flavos experimental
8. Bootar em QEMU
9. Testar BIOS
10. Testar UEFI
11. Registrar problemas
12. Fazer o mesmo build novamente
```

O objetivo do primeiro dia é poder dizer:

> “Temos uma imagem Flavos reproduzível, baseada no Debian 13, que inicializa corretamente.”

Só então começa a construção do sistema.

---

# 13. Instrução inicial para o agente

O agente que trabalhar no Flavos OS deverá receber estas regras:

```text
Você está trabalhando no Flavos OS 3.0.

Base oficial:
Debian 13 Trixie amd64.

O Flavos OS é uma plataforma própria construída sobre Debian,
não uma simples customização visual da distribuição.

Princípios:

1. Priorize arquitetura antes de interface.
2. Não introduza GNOME, KDE ou XFCE como desktop-base sem decisão explícita.
3. Utilize builds reproduzíveis.
4. Utilize live-build para geração das imagens.
5. Evite alterações diretas em pacotes Debian upstream quando não forem necessárias.
6. Não crie wrappers ou fallbacks improvisados.
7. Cada daemon Flavos deve possuir uma responsabilidade definida.
8. Toda decisão arquitetural significativa deve ser registrada em docs/adr/.
9. Flow não deve utilizar hibernação/imagem completa de RAM como mecanismo principal.
10. Adaptive UI pode reduzir efeitos gráficos, nunca funcionalidades.
11. Compatibilidade com hardware x86-64 antigo é requisito de projeto.
12. Performance e baixo consumo de recursos são requisitos desde o início.
13. Antes de alterar boot, sessão, display stack, filesystem ou package management, documente a proposta.
14. Não avance para interface sofisticada enquanto a camada inferior não estiver estável.

Sempre preserve a capacidade de reconstruir o Flavos OS a partir do repositório.
```

---

# 14. Documentação obrigatória para o agente

### Debian 13

https://www.debian.org/releases/trixie/

### Download

https://www.debian.org/download.pt.html

### Installation Guide

https://www.debian.org/releases/stable/amd64/

### Release Notes

https://www.debian.org/releases/trixie/releasenotes

### Debian Live Manual

https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html

### live-build

https://packages.debian.org/trixie/live-build

### systemd

https://systemd.io/

### D-Bus

https://dbus.freedesktop.org/

Essas deverão ser consideradas as referências iniciais, preferindo sempre documentação oficial/upstream a tutoriais aleatórios.

---

# 15. Ponto de partida prático do M0

## 15.1 Situação após o encerramento do M0

O plano deste capítulo foi concluído em duas passagens limpas do commit
`fedc240969fe1a1bba8d694159fb657802bf4b9f`; resultados e evidências estão no
[relatório do M0](M0-REPORT.md). O M1 ainda não foi iniciado.

A imagem netinst de referência usada para preparar o laboratório está disponível em:

```text
image/debian-13.6.0-amd64-netinst.iso
```

A ISO foi identificada como Debian 13.6.0 amd64 netinst bootável. Em 16/08/2026,
o SHA-512 local coincidiu com o valor publicado pelo Debian:

```text
ce0eeee7b51fdcdbed1e5116668c1fee27e528767bdf488e5f115a67b225e5dfd0afca1d456aaa9408ceb6b8527521ff7b6b5d62fdbe6f8c5faaf8df56a96292
```

A ISO é um artefato local e não deve ser versionada no Git.

## 15.2 Papel da ISO netinst

A netinst será usada somente para instalar uma VM Debian 13 mínima destinada ao
desenvolvimento e ao build. Ela não será extraída, editada ou usada como entrada
direta da imagem Flavos.

O fluxo correto é:

```text
Debian netinst
      ↓
VM Debian 13 mínima de desenvolvimento
      ↓
live-build + configuração versionada do Flavos
      ↓
ISO híbrida Flavos gerada do zero
```

O `live-build` buscará os pacotes nos repositórios Debian configurados. Nenhum
arquivo da netinst deverá ser copiado manualmente para a futura ISO Flavos.

## 15.3 Ordem recomendada de execução

### Etapa A — Criar a VM de desenvolvimento

Criar uma VM chamada `flavos-build-trixie` usando a netinst verificada. Uma
configuração inicial adequada para o laboratório é:

- 4 CPUs virtuais;
- 4 GB de RAM como padrão seguro, ou 8 GB quando o host tiver memória disponível;
- disco virtual de 40 GB;
- Debian 13 amd64 sem ambiente desktop;
- acesso à internet para os repositórios Debian;
- usuário de desenvolvimento com acesso controlado a `sudo`.

Esses recursos são para a máquina que constrói a ISO, não representam os
requisitos mínimos do Flavos OS.

### Etapa B — Preparar o ambiente de build

Dentro da VM Debian, instalar somente as ferramentas necessárias ao M0:

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

Depois, clonar o repositório do Flavos OS 3.0 e registrar no relatório do M0 as
versões do Debian, `live-build`, QEMU, xorriso e squashfs-tools.

### Etapa C — Criar o Flavos Build System mínimo

O conjunto de mudanças versionado para o M0 contém:

- `image/auto/config`: configuração repetível do `lb config`;
- `image/auto/build`: comando único para executar o build;
- `image/auto/clean`: limpeza segura dos artefatos gerados;
- `image/config/package-lists/`: lista mínima de kernel, systemd, live boot e
  ferramentas de console;
- `image/config/includes.chroot/`: identidade mínima do sistema, sem desktop;
- comandos em `tools/` para iniciar a ISO em QEMU;
- testes em `tests/` para validar os arquivos internos da imagem.

A primeira configuração deve permanecer pequena. Não adicionar display server,
compositor, toolkit gráfico, navegador, gerenciador de arquivos ou instalador.

### Etapa D — Gerar a primeira ISO experimental

Executar o build a partir de uma árvore limpa e guardar fora do Git:

- a ISO híbrida resultante;
- o checksum SHA-256 ou SHA-512;
- a lista de pacotes e suas versões;
- o log completo do build;
- o commit do repositório usado na construção.

O nome inicial recomendado para o artefato é:

```text
flavos-3.0-m0-amd64.hybrid.iso
```

Essa imagem ainda não é uma release. É apenas o primeiro artefato técnico do M0.

### Etapa E — Validar BIOS e UEFI

Executar a mesma ISO em duas VMs descartáveis:

1. QEMU com BIOS legado;
2. QEMU com UEFI por meio do OVMF.

Os comandos verificados são:

```bash
./tests/validate-m0-iso.sh image/flavos-3.0-m0-amd64.hybrid.iso
./tools/test-m0-boot.sh all
```

O autologin em `ttyS0`, o probe `flavos.m0.probe=1` e o console serial pertencem
somente ao laboratório técnico do M0. Eles permitem ao harness executar um desafio
bidirecional no TTY e não estabelecem política de autenticação para imagens de produto.

Nos dois modos, registrar evidências de que:

```text
kernel inicializou
systemd é o PID 1
arquitetura é x86_64
TTY aceita entrada
identidade Flavos está presente
nenhum ambiente gráfico foi iniciado
```

O teste deve falhar claramente se a VM não chegar ao TTY dentro do tempo definido
para o laboratório.

### Etapa F — Repetir do zero

Limpar todos os artefatos produzidos e repetir configuração, build e testes. No
M0, “reproduzível” significa que dois builds limpos:

- terminam com sucesso a partir do mesmo commit;
- geram a mesma seleção de pacotes;
- inicializam em BIOS e UEFI;
- chegam ao mesmo estado funcional de TTY.

Checksums diferentes devem ser investigados e registrados, pois timestamps e
atualizações do repositório Debian podem impedir identidade binária mesmo quando o
resultado funcional é equivalente. Reprodutibilidade byte a byte e política de
snapshots de pacotes exigirão uma decisão específica antes de releases públicas.

## 15.4 Entregáveis para encerrar o M0

- configuração completa do `live-build` versionada;
- comandos únicos e documentados para configurar, construir e limpar;
- comandos de boot para BIOS e UEFI;
- validações automatizadas da estrutura da ISO;
- manifesto de pacotes e checksums;
- relatório com as duas execuções do build e os testes de boot;
- documentação `BUILD.md` atualizada com comandos realmente verificados.

Todos esses entregáveis foram cumpridos e consolidados no
[relatório do M0](M0-REPORT.md).

## 15.5 Gate do M0

O gate técnico foi cumprido: a partir de uma VM Debian 13, o repositório reconstrói
uma ISO que chega ao TTY em BIOS e UEFI. Isso encerra o M0, mas não inicia
automaticamente o M1.

## 15.6 Estado após o encerramento

O projeto permanece no marco M0 concluído. Nenhuma escolha de display stack,
compositor, toolkit, login gráfico ou sessão foi feita neste encerramento. O M1 só
poderá começar por decisão explícita, pesquisa e ADRs próprios.
