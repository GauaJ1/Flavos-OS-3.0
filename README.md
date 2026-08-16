# Flavos OS 3.0

> **Estado:** Foundation / Project Bootstrap v0.1 — concluído<br>
> **Milestone atual:** M0 — Bootstrap (concluído; M1 não iniciado)<br>
> **Base:** Debian 13 “Trixie”<br>
> **Arquitetura:** amd64 / x86-64

O Flavos OS 3.0 é um sistema operacional desktop construído sobre uma instalação
mínima do Debian. O projeto não parte de um desktop Debian pronto: sua evolução
segue a sequência **Debian mínimo → infraestrutura Linux → componentes Flavos →
Flavos Desktop**.

## Resultado do M0

O M0 produziu uma ISO híbrida mínima capaz de inicializar tanto em BIOS quanto
em UEFI:

```text
ISO → kernel Linux → systemd → TTY
```

O bootstrap foi validado em duas passagens limpas do commit
`fedc240969fe1a1bba8d694159fb657802bf4b9f`. A estrutura da ISO e os boots BIOS
e UEFI foram verificados pelo laboratório automatizado; hashes, manifestos e
evidências estão no [relatório de encerramento do M0](docs/M0-REPORT.md). A
conclusão do M0 não inicia o M1.

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
├── image/       # configuração do live-build e laboratório local ignorado
├── src/         # futuros componentes Flavos
├── packages/    # futuros pacotes próprios
├── assets/      # identidade e recursos visuais
├── tools/       # ferramentas de desenvolvimento e build
├── tests/       # validações automatizadas
└── releases/    # metadados de versões e artefatos publicados
```

## Documentação

- [Guia oficial de início](docs/BASEIDEIA.md)
- [Visão](docs/VISION.md)
- [Arquitetura](docs/ARCHITECTURE.md)
- [Flavos Flow](docs/FLOW.md)
- [Interface adaptativa](docs/ADAPTIVE_UI.md)
- [Hardware](docs/HARDWARE.md)
- [Build](docs/BUILD.md)
- [Relatório de encerramento do M0](docs/M0-REPORT.md)
- [VM de desenvolvimento](docs/DEVELOPMENT_VM.md)
- [Roadmap](docs/ROADMAP.md)
- [Architecture Decision Records](docs/adr/README.md)

## Referências oficiais

- [Download do Debian](https://www.debian.org/download.pt.html)
- [Guia de instalação do Debian](https://www.debian.org/releases/stable/amd64/)
- [Debian Live Manual](https://live-team.pages.debian.net/live-manual/html/live-manual/index.pt_BR.html)
- [Pacote live-build no Debian Trixie](https://packages.debian.org/trixie/live-build)
