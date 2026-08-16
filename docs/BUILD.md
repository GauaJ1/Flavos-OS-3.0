# Build do Flavos OS 3.0

## Estado desta etapa

A configuração inicial do pipeline está versionada em `image/auto/` e
`image/config/`. Ela ainda precisa ser executada e validada dentro da VM Debian 13
antes de ser considerada o primeiro build concluído do M0.

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

Antes do primeiro build, a estrutura versionada pode ser validada sem privilégios:

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

Não fazem parte do M0: ambiente gráfico, shell Flavos, Flow, experiência
adaptativa ou instalador.

## Referências

- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html)
- [Pacote live-build no Debian Trixie](https://packages.debian.org/trixie/live-build)
