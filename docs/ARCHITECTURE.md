# Arquitetura do Flavos OS 3.0

## Visão em camadas

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

Esta figura descreve a direção conceitual. No bootstrap atual, somente Debian,
kernel, systemd e o destino TTY estão aprovados.

## Responsabilidades previstas

| Componente | Responsabilidade |
|---|---|
| `flavos-session` | ciclo de vida da sessão Flavos |
| `flavos-shell` | experiência principal de interface |
| `flavos-flowd` | captura e restauração de contexto suportado |
| `flavos-adaptive` | classificação de capacidade e perfil visual |

Os limites públicos, protocolos e linguagens desses componentes ainda não estão
definidos.

## Regras arquiteturais

1. Evitar wrappers sem responsabilidade própria.
2. Manter uma responsabilidade clara por componente.
3. Não criar fallback sem decisão e documentação.
4. Tornar o build reconstruível a partir do conteúdo versionado.
5. Impedir que a interface controle diretamente funções críticas do sistema.
6. Reutilizar capacidades upstream do Debian e do systemd antes de criar uma
   implementação Flavos equivalente.
7. Tratar desempenho como requisito de projeto.

## Infraestrutura aprovada

- Debian 13 “Trixie” amd64 como sistema-base;
- Linux como kernel;
- systemd como init e infraestrutura de serviços;
- D-Bus e cgroups por meio da infraestrutura padrão do sistema;
- `live-build` como ferramenta principal para gerar a futura ISO híbrida.

## Decisões deliberadamente pendentes

Exigem pesquisa e ADR antes da implementação:

- Wayland, X11 e eventual estratégia de compatibilidade;
- compositor e gerenciador de janelas;
- GTK, Qt/QML ou outro toolkit;
- display manager;
- filesystem;
- instalador;
- Flatpak e política de pacotes;
- atualizações, recuperação e snapshots.
