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

## Matriz do M0

Cada build mínimo deverá ser exercitado, no mínimo, nestes modos:

| Firmware | Máquina | Resultado esperado |
|---|---|---|
| BIOS legado | QEMU | kernel, systemd e TTY utilizável |
| UEFI | QEMU com OVMF | kernel, systemd e TTY utilizável |

Máquinas virtuais validam o pipeline e os caminhos de firmware. A homologação de
hardware antigo requer máquinas físicas em milestones posteriores.

## Critérios a medir futuramente

- sucesso e tempo de boot;
- consumo de memória em repouso;
- compatibilidade de vídeo, entrada, áudio, rede e energia;
- estabilidade sob armazenamento lento;
- comportamento dos perfis ECO, BALANCED e FULL.

Os requisitos mínimo e recomendado definitivos serão publicados somente após
resultados repetíveis do Hardware Lab.
