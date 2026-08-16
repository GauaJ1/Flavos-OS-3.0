# ADR-001 — Debian 13 Trixie amd64 como base

- **Estado:** Aceito
- **Data:** 2026-08-16
- **Responsáveis:** projeto Flavos OS

## Contexto

O Flavos OS precisa de uma base estável, mantida, amplamente documentada e capaz
de atender computadores x86-64 antigos e modernos. O projeto também precisa de um
pipeline próprio para construir imagens, sem depender da edição manual de uma ISO
ou de um desktop pré-configurado.

## Decisão

Adotar:

- Debian 13 “Trixie” como sistema-base;
- amd64 / x86-64 como arquitetura inicial e exclusiva de instalação;
- instalação mínima, sem desktop Debian;
- Linux e systemd fornecidos pela base;
- `live-build` como ferramenta principal para gerar a ISO híbrida do projeto.

A sequência de construção do produto será Debian mínimo, infraestrutura Linux,
componentes Flavos e, por fim, Flavos Desktop.

## Consequências

- builds e desenvolvimento devem ser validados prioritariamente em Debian 13
  amd64;
- o projeto reutilizará serviços, D-Bus e cgroups do systemd;
- alterações em componentes upstream exigem justificativa específica;
- máquinas exclusivamente i386 ficam fora do alvo;
- qualquer mudança de distribuição, arquitetura, init ou ferramenta principal de
  imagem exigirá um novo ADR que substitua este registro.

Este ADR não escolhe display stack, toolkit, compositor, display manager,
filesystem, instalador ou política de pacotes.
