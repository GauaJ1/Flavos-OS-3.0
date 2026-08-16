# Flavos OS 3.0

> **Estado:** Foundation / Project Bootstrap v0.1<br>
> **Milestone atual:** M0 — Bootstrap<br>
> **Base:** Debian 13 “Trixie”<br>
> **Arquitetura:** amd64 / x86-64

O Flavos OS 3.0 é um sistema operacional desktop construído sobre uma instalação
mínima do Debian. O projeto não parte de um desktop Debian pronto: sua evolução
segue a sequência **Debian mínimo → infraestrutura Linux → componentes Flavos →
Flavos Desktop**.

## Objetivo atual

O M0 deve produzir, de forma reproduzível, uma ISO híbrida mínima capaz de
inicializar tanto em BIOS quanto em UEFI:

```text
ISO → kernel Linux → systemd → TTY
```

Esta versão do repositório contém somente a fundação documental e a estrutura do
projeto. A configuração do `live-build`, a geração da ISO e os testes em QEMU
ainda não foram implementados.

## Princípios

- o Debian permanece abaixo da camada Flavos, com o mínimo possível de alterações
  em componentes upstream;
- systemd fornece a infraestrutura de serviços, D-Bus e cgroups;
- cada componente Flavos possui uma responsabilidade clara;
- o build deve ser reproduzível;
- desempenho é requisito desde o início;
- perfis gráficos podem reduzir efeitos, nunca funcionalidades;
- decisões arquiteturais relevantes exigem pesquisa e um ADR.

## Estrutura

```text
.
├── docs/        # visão, arquitetura, especificações e ADRs
├── image/       # futura configuração do live-build
├── src/         # futuros componentes Flavos
├── packages/    # futuros pacotes próprios
├── assets/      # identidade e recursos visuais
├── tools/       # ferramentas de desenvolvimento e build
├── tests/       # validações automatizadas
└── releases/    # metadados de versões e artefatos publicados
```

## Documentação

- [Visão](docs/VISION.md)
- [Arquitetura](docs/ARCHITECTURE.md)
- [Flavos Flow](docs/FLOW.md)
- [Interface adaptativa](docs/ADAPTIVE_UI.md)
- [Hardware](docs/HARDWARE.md)
- [Build](docs/BUILD.md)
- [Roadmap](docs/ROADMAP.md)
- [Architecture Decision Records](docs/adr/README.md)

## Referências oficiais

- [Download do Debian](https://www.debian.org/download.pt.html)
- [Guia de instalação do Debian](https://www.debian.org/releases/stable/amd64/)
- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html)
- [Pacote live-build no Debian Trixie](https://packages.debian.org/trixie/live-build)
