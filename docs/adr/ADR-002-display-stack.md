# ADR-002 — Fundação gráfica Wayland com Labwc

- **Estado:** Aceito
- **Data:** 2026-08-23
- **Responsáveis:** projeto Flavos OS

## Contexto

O M0 comprovou o caminho ISO, kernel Linux, systemd e TTY. O M1 precisa
acrescentar uma fundação gráfica sem antecipar o Flavos Desktop, o toolkit da
interface, um display manager ou a sessão definitiva do produto.

O primeiro recorte, M1.1, deve comprovar somente o caminho técnico
`login/TTY → compositor → socket Wayland → aplicação Wayland`, preservando os
boots BIOS e UEFI e a possibilidade de retornar ao TTY.

No Debian 13 “Trixie” amd64, o pacote `labwc` está na versão `0.8.3-1` e usa a
biblioteca `libwlroots-0.18`; o código-fonte empacotado de wlroots está na versão
`0.18.2-3`. O Labwc é um compositor Wayland do tipo *stacking*, pequeno e
independente de um ambiente desktop completo.

## Opções consideradas

1. **Wayland com Labwc:** fornece compositor e gerenciamento convencional de
   janelas sem incorporar um desktop environment.
2. **Sessão Xorg completa:** amplia desde já a arquitetura e a superfície de
   manutenção, sem evidência de hardware físico que exija esse caminho.
3. **Desktop environment pronto:** entregaria componentes além do gate e
   contrariaria a construção progressiva dos componentes Flavos.

## Decisão

Adotar para a fundação gráfica inicial:

- Wayland como protocolo gráfico primário;
- Labwc `0.8.3` como compositor técnico inicial;
- wlroots `0.18`, fornecido pelo Debian Trixie como `0.18.2-3`, como
  infraestrutura do compositor;
- Foot como aplicação Wayland técnica para provar a primeira janela;
- XWayland instalado e disponível para compatibilidade, conforme a dependência
  do pacote Labwc, mas sem declarar compatibilidade X11 no M1.1: o teste de uma
  aplicação X11 pertence ao M1.2;
- `systemd-logind` como único broker de sessão e seat, com a sessão registrada
  por PAM através de `libpam-systemd`; o daemon `seatd` não será habilitado como
  segundo broker;
- `dbus-user-session` para a sessão D-Bus integrada a `systemd --user`;
- renderer escolhido normalmente pela stack. `WLR_RENDERER=pixman` fica
  disponível apenas como experimento manual para diagnóstico de hardware
  legado; não é fallback automático nem substitui o teste gráfico normal.

O Xorg completo permanece fora da arquitetura. Sua inclusão exigirá evidência
de testes em hardware físico e um novo ADR. Também continuam pendentes o display
manager, o toolkit Flavos, a sessão definitiva, a política de login do produto e
os demais serviços previstos para o M1.

## Consequências

- o M1.1 pode ser validado sem painel, launcher, tema definitivo ou qualquer
  componente visual Flavos;
- a imagem técnica continuará partindo de um login no TTY; isso não define a
  experiência final de autenticação;
- entrada, output DRM, socket Wayland, Labwc e Foot precisam ser comprovados em
  BIOS e UEFI sem regressão do gate M0;
- a presença de XWayland na imagem não constitui um teste X11 aprovado;
- o caminho Pixman deve ser solicitado explicitamente e registrado como
  experimento, nunca ativado silenciosamente;
- Labwc é a escolha inicial da fundação, não uma decisão irrevogável sobre o
  compositor ou a shell final do produto. Uma substituição exigirá outro ADR.

## Referências oficiais

- [Labwc 0.8.3-1 para Debian Trixie amd64](https://packages.debian.org/trixie/amd64/labwc)
- [Manual do Labwc 0.8.3 no Debian Trixie](https://manpages.debian.org/trixie/labwc/labwc.1.en.html)
- [wlroots 0.18.2-3 no Debian Sources](https://sources.debian.org/src/wlroots/0.18.2-3/)
- [Variáveis de ambiente do wlroots 0.18.2-3](https://sources.debian.org/src/wlroots/0.18.2-3/docs/env_vars.md/)
- [`pam_systemd(8)` no Debian Trixie](https://manpages.debian.org/trixie/libpam-systemd/pam_systemd.8.en.html)
- [`systemd-logind(8)` no Debian Trixie](https://manpages.debian.org/trixie/systemd/systemd-logind.8.en.html)
- [`dbus-user-session` no Debian Trixie](https://packages.debian.org/trixie/dbus-user-session)
