# Roadmap do Flavos OS 3.0

## M0 — Bootstrap (concluído)

Produzir uma ISO híbrida funcionalmente reproduzível que inicialize em BIOS e
UEFI até kernel, systemd e TTY. Nenhuma interface Flavos será incluída.

Concluído em duas passagens limpas do commit
`fedc240969fe1a1bba8d694159fb657802bf4b9f`, com validação da estrutura da ISO e
boot até TTY em BIOS e UEFI. Consulte o [relatório do M0](M0-REPORT.md).

## M1 — Graphical Foundation

**Em andamento.** Pesquisar, registrar em ADRs e implementar display stack,
compositor, login e sessão, entrada, compatibilidade, áudio, rede e gerenciamento
de energia em recortes verificáveis.

### M1.1 — Wayland Display Foundation (em implementação)

Partindo exclusivamente do M0 aprovado, comprovar:

```text
login/TTY → Labwc → socket Wayland → Foot
```

O [ADR-002](adr/ADR-002-display-stack.md) aprovou Wayland como protocolo
primário e Labwc 0.8.3 sobre wlroots 0.18 como compositor técnico inicial. A
sessão usa `systemd-logind`/`libpam-systemd` para seat e login e
`dbus-user-session` para a integração D-Bus com `systemd --user`.

XWayland fica disponível na imagem, mas a execução e validação de uma aplicação
X11 pertencem ao M1.2. O M1.1 ainda não foi concluído e não autoriza avançar para
áudio, rede, energia, portais ou componentes Flavos.

### M1.2 — Compatibilidade (pendente)

Validar uma aplicação X11 real através do XWayland somente depois de o caminho
Wayland nativo do M1.1 estar estável. Escopo e gate detalhados serão fechados
antes da implementação.

## M2 — Flavos Shell

Criar Flavos Session, Panel, Launcher, Notifications, Settings e integração com
arquivos.

## M3 — Flavos Flow

Prototipar `flavos-flowd` para capturar aplicativos, janelas, posições,
workspaces, pastas e contexto suportado; depois evoluir integrações, prioridades e
restauração progressiva/gentil.

## M4 — Adaptive Experience

Detectar capacidade gráfica e aplicar automaticamente os perfis ECO, BALANCED e
FULL, variando efeitos sem remover funcionalidades.

## M5 — Live consolidado + Installer

Depois da consolidação da base, transformar o live mínimo do M0 em ambiente de
produto e implementar instalador, particionamento, criação de usuário, bootloader
e OOBE.

## M6 — Hardware Lab

Validar máquinas legacy x86-64, intermediárias e modernas em VMs e hardware
físico, com atenção especial à geração Core 2, 4 GB de RAM e HDD.

## M7 — Alpha

Publicar a primeira **Flavos OS 3.0 Developer Alpha** e iniciar o ciclo público
de testes.

## Estado atual

O projeto concluiu **M0 — Bootstrap** e iniciou **M1 — Graphical Foundation**. O
recorte atual é **M1.1 — Wayland Display Foundation, em implementação**; nenhum
PASS é alegado antes da construção e dos boots de aceitação. Toolkit, display
manager, sessão definitiva e M1.2 permanecem pendentes.
