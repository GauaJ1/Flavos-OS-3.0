# Flavos Flow

## Objetivo

O Flavos Flow deverá preservar contexto de trabalho suportado para que uma sessão
possa ser retomada de forma progressiva e compreensível pelo usuário.

## Limite fundamental

Flow não é hibernação e não salva uma imagem completa da RAM. Seu modelo é
baseado em estado semântico e metadados fornecidos pelo sistema ou por integrações
compatíveis.

## Contexto previsto para o primeiro protótipo

- aplicativos abertos;
- janelas e suas posições;
- workspace associado;
- pastas em uso;
- contexto adicional explicitamente suportado por cada integração.

## Restauração

A evolução prevista contempla restauração progressiva e gentil: o sistema deve
priorizar o que é relevante e evitar uma carga simultânea desnecessária. Política
de prioridade, experiência de consentimento e comportamento diante de falhas
serão definidos antes do milestone M3.

## Requisitos arquiteturais

- salvar somente dados necessários e documentados;
- distinguir estado capturado, restaurado, ignorado e incompatível;
- tolerar aplicativos ausentes ou versões incompatíveis;
- manter a sessão utilizável mesmo quando parte da restauração falhar;
- não transformar o Flow em autoridade direta sobre funções críticas do sistema.

## Decisões pendentes

Formato e local de armazenamento, APIs, política de retenção, privacidade,
integrações por aplicativo e contrato de restauração exigem pesquisa e ADRs. Não
há implementação de Flow nesta etapa.
