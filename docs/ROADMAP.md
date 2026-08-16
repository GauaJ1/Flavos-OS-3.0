# Roadmap do Flavos OS 3.0

## M0 — Bootstrap

Produzir uma ISO híbrida reproduzível que inicialize em BIOS e UEFI até kernel,
systemd e TTY. Nenhuma interface Flavos será incluída.

## M1 — Graphical Foundation

Pesquisar, registrar em ADRs e implementar display stack, compositor ou window
manager, login e sessão, entrada, áudio, rede e gerenciamento de energia.

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

O projeto está em **Foundation / Project Bootstrap v0.1**, executando o M0. A
configuração inicial do `live-build` e o laboratório da VM já existem; a primeira
ISO ainda precisa ser construída e validada.
