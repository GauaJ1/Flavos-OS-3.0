# Build do Flavos OS 3.0

## Estado desta etapa

O pipeline ainda não está implementado. Os diretórios `image/auto/` e
`image/config/` existem apenas como estrutura versionada para o próximo passo do
M0.

## Estratégia aprovada

A ISO do Flavos OS será gerada pelo projeto com `live-build`. Não será criada por
edição ou remasterização manual de uma ISO pronta do Debian.

O ambiente de referência para desenvolvimento e build é uma instalação limpa do
Debian 13 amd64 sem desktop. Manter o host alinhado ao sistema-base reduz diferenças
entre o ambiente de construção e a imagem resultante.

## Dependências previstas do host

```bash
sudo apt update
sudo apt install git live-build qemu-system-x86 ovmf xorriso squashfs-tools
```

## Configuração mínima de referência

O primeiro experimento do M0 partirá deste fluxo, que ainda deverá ser incorporado
a scripts versionados:

```bash
cd image
lb config \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid
sudo lb build
```

## Critério de reprodutibilidade do M0

1. construir a imagem a partir de um checkout limpo;
2. registrar versões de ferramentas e pacotes relevantes;
3. iniciar a ISO em QEMU com BIOS;
4. iniciar a mesma ISO em QEMU com UEFI/OVMF;
5. chegar a um TTY utilizável nos dois modos;
6. limpar os artefatos de build;
7. repetir o build completo e os testes;
8. registrar diferenças, problemas e resultados.

Não fazem parte do M0: ambiente gráfico, shell Flavos, Flow, experiência
adaptativa ou instalador.

## Referências

- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html)
- [Pacote live-build no Debian Trixie](https://packages.debian.org/trixie/live-build)
