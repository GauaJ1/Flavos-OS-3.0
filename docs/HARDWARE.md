# Hardware e Matriz de Testes

## Plataforma-alvo

O alvo inicial é amd64 / x86-64. Debian 13 não oferece i386 como arquitetura de
instalação independente; o foco legado permanece em computadores x86-64 antigos,
incluindo parte relevante da geração Core 2.

## Baselines de laboratório

Estas configurações são pontos de teste, não requisitos finais publicados:

| Classe | Referência de laboratório |
|---|---|
| Legacy x86-64 | geração Core 2, 4 GB de RAM e HDD |
| Intermediária | 8 GB de RAM, GPU integrada e SSD |
| Moderna | 16/32+ GB de RAM, NVMe e GPU moderna |

## Matriz encerrada do M0

O M0 foi exercitado nestes modos; os resultados estão no
[relatório de encerramento](M0-REPORT.md):

| Firmware | Máquina | Resultado comprovado |
|---|---|---|
| BIOS legado | QEMU | kernel, systemd e TTY utilizável |
| UEFI | QEMU com OVMF | kernel, systemd e TTY utilizável |

Máquinas virtuais validam o pipeline e os caminhos de firmware. A homologação de
hardware antigo requer máquinas físicas em milestones posteriores.

## Matriz encerrada do M1.1

As duas passagens limpas preservaram o resultado M0 e exercitaram a fundação
gráfica nos dois caminhos. Os resultados estão no
[relatório do M1.1](M1.1-REPORT.md):

| Firmware | Máquina | Resultado comprovado |
|---|---|---|
| BIOS legado | QEMU | TTY utilizável, sessão logind, output DRM, Labwc, socket Wayland, entrada e Foot |
| UEFI | QEMU com OVMF | TTY utilizável, sessão logind, output DRM, Labwc, socket Wayland, entrada e Foot |

Teclado e ponteiro precisam produzir evidência de entrada real; detectar apenas
processos ou pacotes não basta. O teste de cliente X11 via XWayland fica para o
M1.2. Uma execução manual com `WLR_RENDERER=pixman` pode fornecer diagnóstico de
software rendering, mas não conta como fallback nem substitui o renderer normal
no gate.

Esta matriz recebeu PASS nas quatro execuções. Compatibilidade com GPUs antigas
será medida em hardware físico antes de qualquer decisão sobre Xorg completo ou
fallback automático. O encerramento do laboratório QEMU não constitui
homologação de hardware físico.

## Critérios a medir futuramente

- sucesso e tempo de boot;
- consumo de memória em repouso;
- compatibilidade de vídeo, entrada, áudio, rede e energia;
- estabilidade sob armazenamento lento;
- comportamento dos perfis ECO, BALANCED e FULL.

Os requisitos mínimo e recomendado definitivos serão publicados somente após
resultados repetíveis do Hardware Lab.
