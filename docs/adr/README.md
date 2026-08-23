# Architecture Decision Records

Architecture Decision Records (ADRs) registram escolhas relevantes e suas
consequências para evitar que decisões de longo prazo sejam repetidas ou tomadas
sem contexto.

## Convenção

- nome: `ADR-NNN-titulo-curto.md`;
- numeração sequencial e permanente;
- estados permitidos: Proposto, Aceito, Substituído ou Rejeitado;
- uma decisão aceita não é reescrita para alterar seu resultado: um novo ADR a
  substitui e referencia o anterior.

## Índice

| ADR | Estado | Decisão |
|---|---|---|
| [ADR-001](ADR-001-debian-base.md) | Aceito | Debian 13 Trixie amd64 como base |
| [ADR-002](ADR-002-display-stack.md) | Aceito | Wayland com Labwc como fundação gráfica inicial |

Use [TEMPLATE.md](TEMPLATE.md) para novos registros.
