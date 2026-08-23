# Visão do Flavos OS 3.0

## Propósito

O Flavos OS 3.0 busca oferecer uma experiência desktop própria, coerente e
completa sobre uma base Linux estável. O sistema deve funcionar tanto em
máquinas x86-64 antigas quanto em hardware moderno, adaptando o custo visual sem
fragmentar suas funcionalidades.

## Direção do produto

O Flavos OS não é um tema aplicado a um desktop existente. Ele será composto por
serviços e elementos de interface Flavos construídos progressivamente sobre uma
instalação mínima do Debian 13 “Trixie”.

A experiência final será organizada em torno de duas capacidades centrais:

- **Flavos Flow:** preservação e restauração gradual do contexto de trabalho;
- **Adaptive Experience:** ajuste automático da apresentação visual à capacidade
  do equipamento, mantendo os mesmos recursos disponíveis.

Essas capacidades serão integradas pela Flavos Shell e pela Flavos Session, sem
substituir a infraestrutura que o Linux, o Debian e o systemd já fornecem.

## Princípios do produto

1. **Identidade própria:** os componentes visíveis principais pertencem à
   experiência Flavos.
2. **Funcionalidade íntegra:** hardware antigo recebe o sistema completo, com
   efeitos visuais adequados à sua capacidade.
3. **Continuidade:** o Flow restaura contexto suportado sem depender de uma
   imagem integral da memória.
4. **Desempenho desde a fundação:** consumo de recursos, latência e tempo de boot
   são critérios de arquitetura.
5. **Base sustentável:** componentes upstream não são bifurcados ou modificados
   sem necessidade documentada.
6. **Decisões explícitas:** escolhas de longo prazo são registradas em ADRs.

## Limites atuais

O M0 foi concluído sem desktop, shell, Flow, instalador ou efeitos adaptativos. O
M1 está em andamento e seu recorte atual, M1.1, acrescenta somente a fundação
técnica `TTY → Labwc → Wayland → Foot` descrita no
[ADR-002](adr/ADR-002-display-stack.md).

Essa primeira janela não é ainda o Flavos Desktop e não escolhe toolkit, display
manager, shell ou sessão definitiva. XWayland fica disponível, mas a
compatibilidade X11 será testada apenas no M1.2.
