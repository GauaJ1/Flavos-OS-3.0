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

Esta figura descreve a direção conceitual. O M0 aprovou Debian, kernel, systemd e
o destino TTY; o M1.1 comprovou a fundação gráfica técnica abaixo da futura
Flavos Session.

## Fundação gráfica inicial

```text
aplicação técnica Foot
          │
       Wayland
          │
    Labwc 0.8.3
          │
   wlroots 0.18
          │
DRM/libinput + systemd-logind
```

Wayland é o protocolo primário e Labwc é o compositor técnico inicial. A sessão
começa no login do TTY: `libpam-systemd` registra a sessão no
`systemd-logind`, que permanece o único broker de seat. `dbus-user-session`
fornece o barramento integrado a `systemd --user`. Essa composição é uma
instrumentação encerrada do M1.1, não a Flavos Session definitiva. Os resultados
estão no [relatório do M1.1](M1.1-REPORT.md).

XWayland está disponível para a futura compatibilidade, mas uma aplicação X11 só
será aceita no M1.2. O renderer normal não é forçado. O modo
`WLR_RENDERER=pixman` é exclusivamente um experimento manual para diagnóstico e
não constitui fallback automático. Consulte o
[ADR-002](adr/ADR-002-display-stack.md).

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
- `live-build` como ferramenta principal para gerar a futura ISO híbrida;
- Wayland como protocolo gráfico primário;
- Labwc 0.8.3 sobre wlroots 0.18 como fundação gráfica inicial;
- `systemd-logind`/`libpam-systemd` como caminho único de sessão e seat;
- `dbus-user-session` para o barramento da sessão de usuário;
- XWayland disponível para compatibilidade a ser validada no M1.2.

## Decisões deliberadamente pendentes

Exigem pesquisa e ADR antes da implementação:

- necessidade de uma sessão Xorg completa, condicionada a testes físicos e a um
  novo ADR;
- compositor definitivo do produto, além do Labwc técnico inicial;
- GTK, Qt/QML ou outro toolkit;
- display manager;
- Flavos Session definitiva e política de login;
- filesystem;
- instalador;
- Flatpak e política de pacotes;
- atualizações, recuperação e snapshots.
