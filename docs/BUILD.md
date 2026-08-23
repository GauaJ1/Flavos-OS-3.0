# Build do Flavos OS 3.0

## Estado desta etapa

O pipeline do M0 foi executado e validado em duas passagens limpas do commit
`fedc240969fe1a1bba8d694159fb657802bf4b9f`. Os hashes, manifestos, versões das
ferramentas e evidências BIOS/UEFI estão no [relatório do M0](M0-REPORT.md).
Depois desse encerramento, o M1 foi aberto explicitamente. O recorte
**M1.1 — Wayland Display Foundation** foi concluído em duas passagens limpas do
commit `54fff9a5816a12853a7213062aa6f4f73b695125`; hashes, manifestos e evidências
BIOS/UEFI estão no [relatório do M1.1](M1.1-REPORT.md). O M1.2 não foi iniciado.

## Estratégia aprovada

A ISO do Flavos OS será gerada pelo projeto com `live-build`. Não será criada por
edição ou remasterização manual de uma ISO pronta do Debian.

O ambiente de referência para desenvolvimento e build é uma instalação limpa do
Debian 13 amd64 sem desktop. Manter o host alinhado ao sistema-base reduz diferenças
entre o ambiente de construção e a imagem resultante.

O preparo desse ambiente está documentado em
[VM de desenvolvimento](DEVELOPMENT_VM.md).

## Dependências previstas do host

```bash
sudo apt update
sudo apt install git live-build qemu-system-x86 qemu-utils ovmf xorriso \
  squashfs-tools imagemagick
```

## Referência histórica do M0

O primeiro experimento do M0 partiu deste fluxo resumido:

```bash
cd image
lb config \
  --distribution trixie \
  --architecture amd64 \
  --binary-image iso-hybrid
sudo lb build
```

O commit registrado no relatório conserva as opções exatas usadas no M0. A
configuração ativa em `image/auto/config` evoluiu para o M1.1, preservando a
mesma mecânica de construção dentro da VM:

```bash
cd image
sudo lb clean --purge
lb config
sudo lb build
```

Os scripts automáticos usam `noauto` internamente para evitar recursão. No M0, o
resultado foi `image/flavos-3.0-m0-amd64.hybrid.iso`; no recorte ativo, o
resultado verificado é `image/flavos-3.0-m1.1-amd64.hybrid.iso`.

A estrutura do M0 foi validada sem privilégios, no commit encerrado, com:

```bash
./tests/validate-m0-config.sh
```

O build oficial do M0 partiu de um commit com worktree limpo. Naquela revisão, o
script recusava alterações não versionadas e registrava commit,
`SOURCE_DATE_EPOCH` e versão do `live-build` no log. A sequência executada foi:

```bash
cd image
lb config
sudo lb build
cd ..
./tools/archive-m0-build.sh

# Testar a ISO arquivada e a ISO em image/, depois preparar a segunda passagem.
cd image
sudo lb clean --purge
lb config
sudo lb build
cd ..
./tools/archive-m0-build.sh
```

Cada arquivamento criou um diretório único em `releases/local/m0/`, contendo ISO,
log, manifestos, versões das ferramentas, commit e SHA-512. Esse diretório é
local e ignorado pelo Git. Na revisão M0, a limpeza recusava remover uma ISO que
ainda não possuísse cópia arquivada e validada; um descarte intencional exigia
explicitamente `FLAVOS_DISCARD_UNARCHIVED=1`.

No M0, firmware para hardware físico, Debian Installer e Secure Boot permanecem
desabilitados. O objetivo é validar exclusivamente o live boot mínimo em QEMU com
BIOS e UEFI; essas limitações não definem a política dos milestones posteriores.

## Fluxo verificado do M1.1 (concluído)

O M1.1 preserva o gate M0 e acrescenta a menor stack necessária para comprovar
`login/TTY → Labwc → Wayland → Foot`. A imagem técnica não adiciona desktop
environment, display manager, painel, launcher ou componentes visuais Flavos.
XWayland fica disponível, mas o teste de uma aplicação X11 é escopo do M1.2.

A interface verificada para configuração, validação, arquivamento e boot é:

```bash
./tests/validate-m1-config.sh

cd image
sudo lb clean --purge
lb config
sudo lb build
cd ..

./tests/validate-m1-iso.sh image/flavos-3.0-m1.1-amd64.hybrid.iso
./tools/archive-m1-build.sh
./tools/test-m1-boot.sh all
```

Esses comandos foram executados em duas passagens limpas e independentes. Cada
ISO foi arquivada e passou nos caminhos BIOS e UEFI; a proveniência e os
resultados estão no [relatório de encerramento](M1.1-REPORT.md).

O harness M1.1 é executado como usuário normal. Ele expõe uma GPU
`virtio-vga` com scanout DRM, teclado e mouse virtuais, mantém a ISO somente
leitura e a rede desabilitada e preserva em
`releases/local/m1.1/boot-tests/` os logs seriais, probes, nonces, screenshots e
checksums. `imagemagick` é usado somente no host para confirmar que o framebuffer
contém a janela Foot em tela cheia; processo ou socket isolado não produz PASS.
Os nonces entregues por `fw_cfg` permanecem legíveis somente pelo probe root; os
challenges Foot/TTY publicam apenas os dígitos realmente recebidos, e o probe faz
a comparação autoritativa sem gravar no diretório de estado do usuário.

Para testar exatamente uma ISO arquivada com o harness, use
`FLAVOS_M1_ISO=/caminho/flavos-3.0-m1.1-amd64.hybrid.iso`. O validador estrutural
recebe a ISO como argumento posicional e aceita o manifesto correspondente por
meio de `FLAVOS_M1_MANIFEST`:

```bash
FLAVOS_M1_MANIFEST=/caminho/flavos-3.0-m1.1-amd64.packages \
  ./tests/validate-m1-iso.sh \
  /caminho/flavos-3.0-m1.1-amd64.hybrid.iso
```

O teste normal deixa a stack selecionar seu renderer. Uma execução manual com
`WLR_RENDERER=pixman` pode ser usada separadamente como experimento diagnóstico,
mas não é fallback automático e não substitui o gate gráfico normal. A decisão
completa está no [ADR-002](adr/ADR-002-display-stack.md).

## Validar a ISO e o boot

### M1.1 encerrado

O gate M1.1 confirmou em duas passagens limpas: imagem híbrida BIOS/UEFI,
manifesto interno coerente, Labwc 0.8.3, socket Wayland, Foot, sessão
`systemd-logind`, D-Bus e `systemd --user`, entrada real de mouse/teclado,
logout e retorno ao `tty1`. Consulte o [relatório do M1.1](M1.1-REPORT.md).

XWayland foi confirmado como disponível, mas nenhuma aplicação X11 foi executada;
essa prova pertence ao M1.2, que não foi iniciado.

### M0 encerrado

Na revisão encerrada do M0, a estrutura interna e os dois caminhos de firmware
foram validados com:

```bash
./tests/validate-m0-iso.sh image/flavos-3.0-m0-amd64.hybrid.iso
./tools/test-m0-boot.sh all
```

O validador da ISO compara o manifesto interno ao manifesto externo, confirma a
imagem híbrida, as entradas El Torito BIOS/UEFI, kernel, initrd, squashfs, pacotes
obrigatórios e ausência de stack gráfica. O harness de boot aceita `all`, `bios`
ou `uefi`; deve ser executado como usuário normal, nunca com `sudo`. Por padrão,
ele limita cada modo a 180 segundos e preserva logs, probes e desafios TTY em
`releases/local/m0/boot-tests/`.

Para testar outro artefato, informe `FLAVOS_M0_ISO=/caminho/imagem.hybrid.iso`.
O manifesto correspondente pode ser indicado ao validador com
`FLAVOS_M0_MANIFEST=/caminho/imagem.packages`.

### Serial exclusiva do laboratório M0

A imagem técnica do M0 inclui `console=ttyS0`, o probe condicionado por
`flavos.m0.probe=1` e um drop-in de autologin do usuário live `flavos` em
`serial-getty@ttyS0.service`. Isso existe exclusivamente para o harness comprovar
entrada e saída reais no TTY por um desafio bidirecional. Não é política de login,
segurança ou produto do Flavos OS e deve ser removido ou redesenhado antes de uma
imagem destinada a usuários. O harness também envia `Enter` pelo monitor QEMU
para selecionar a entrada live sem versionar uma decisão de timeout dos menus
Syslinux/GRUB.

## Critério de reprodutibilidade do M0

1. construir a imagem a partir de um checkout limpo;
2. registrar versões de ferramentas e pacotes relevantes;
3. iniciar a ISO em QEMU com BIOS;
4. iniciar a mesma ISO em QEMU com UEFI/OVMF;
5. chegar a um TTY utilizável nos dois modos;
6. arquivar a primeira passagem e validar sua cópia;
7. limpar os artefatos de build;
8. repetir o build completo, arquivamento e testes;
9. registrar diferenças, problemas e resultados.

O cumprimento desses critérios está registrado no
[relatório de encerramento do M0](M0-REPORT.md).

Não fazem parte do M0: ambiente gráfico, shell Flavos, Flow, experiência
adaptativa ou instalador.

## Referências

- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html)
- [Pacote live-build no Debian Trixie](https://packages.debian.org/trixie/live-build)
