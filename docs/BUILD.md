# Build do Flavos OS 3.0

## Estado desta etapa

O pipeline do M0 foi executado e validado em duas passagens limpas do commit
`fedc240969fe1a1bba8d694159fb657802bf4b9f`. Os hashes, manifestos, versões das
ferramentas e evidências BIOS/UEFI estão no [relatório do M0](M0-REPORT.md).
Este encerramento não inicia o M1.

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
sudo apt install git live-build qemu-system-x86 qemu-utils ovmf xorriso squashfs-tools
```

## Configuração mínima de referência

O primeiro experimento do M0 parte deste fluxo resumido:

```bash
cd image
lb config \
  --distribution trixie \
  --architecture amd64 \
  --binary-image iso-hybrid
sudo lb build
```

No repositório, as opções completas ficam em `image/auto/config`. O fluxo
pretendido dentro da VM é:

```bash
cd image
sudo lb clean --purge
lb config
sudo lb build
```

Os scripts automáticos usam `noauto` internamente para evitar recursão. O resultado
esperado é `image/flavos-3.0-m0-amd64.hybrid.iso`.

A estrutura versionada deve ser validada sem privilégios antes de cada build:

```bash
./tests/validate-m0-config.sh
```

O build oficial do M0 deve partir de um commit com worktree limpo. O script recusa
alterações não versionadas, registra commit, `SOURCE_DATE_EPOCH` e versão do
`live-build` no log. A sequência segura de duas passagens é:

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

Cada arquivamento cria um diretório único em `releases/local/m0/`, contendo ISO,
log, manifestos, versões das ferramentas, commit e SHA-512. Esse diretório é
local e ignorado pelo Git. A limpeza recusa remover uma ISO que ainda não possua
cópia arquivada e validada. Um descarte intencional exige explicitamente
`FLAVOS_DISCARD_UNARCHIVED=1`.

No M0, firmware para hardware físico, Debian Installer e Secure Boot permanecem
desabilitados. O objetivo é validar exclusivamente o live boot mínimo em QEMU com
BIOS e UEFI; essas limitações não definem a política dos milestones posteriores.

## Validar a ISO e o boot

A estrutura interna e os dois caminhos de firmware são validados com:

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
