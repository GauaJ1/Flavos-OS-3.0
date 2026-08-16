# Adaptive Experience

## Objetivo

A interface do Flavos OS deverá adaptar seu custo gráfico à capacidade do
equipamento, mantendo a mesma experiência funcional em todas as classes de
hardware suportadas.

## Perfis conceituais

```text
ECO → BALANCED → FULL
```

Os perfis podem variar intensidade ou presença de:

- blur e transparência;
- sombras;
- duração e complexidade de animações;
- efeitos de composição;
- tarefas visuais secundárias.

## Invariante funcional

Nenhum perfil pode remover funcionalidades, alterar o conteúdo disponível ou
criar uma edição inferior do Flavos OS. Um computador antigo continua recebendo
shell, Flow, configurações e integrações equivalentes; apenas o custo visual é
ajustado.

## Comportamento esperado

- selecionar automaticamente um perfil inicial com base em evidências do
  hardware e do desempenho observado;
- permitir ajustes previsíveis sem exigir conhecimento técnico;
- evitar oscilações frequentes de perfil;
- manter acessibilidade e legibilidade em todos os níveis;
- possibilitar diagnóstico da escolha automática.

## Decisões pendentes

Os indicadores de capacidade, limites entre perfis, toolkit, compositor, formato
de configuração e política de substituição manual ainda não foram escolhidos.
Essas decisões serão pesquisadas e registradas antes do milestone M4.
