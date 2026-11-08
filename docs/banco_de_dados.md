# Banco de dados e persistência

## Estado atual

Não há banco de dados, esquema, serviço de persistência ou dependências de armazenamento configuradas. Nenhuma estratégia foi escolhida.

## Decisões pendentes

- Se os dados serão locais, remotos ou uma combinação dos dois.
- Requisitos de acesso sem conexão, sincronização, autenticação, backup e retenção.
- Tecnologia de armazenamento e responsabilidades por migrações.
- Classificação dos dados, controles de acesso e ciclo de vida de exclusão.

## Diretrizes quando a persistência for definida

- Escolher a solução apenas após documentar os dados e os requisitos de sincronização e privacidade.
- Versionar esquemas e preparar migrações explícitas para mudanças incompatíveis.
- Evitar dados pessoais desnecessários; documentar finalidade, retenção e exclusão.
- Definir identificadores, datas e índices de acordo com os padrões de consulta reais. Padronizar datas em UTC quando houver intercâmbio entre fusos.
- Manter credenciais fora do cliente e do repositório; dados armazenados localmente devem seguir os requisitos de sensibilidade definidos para o produto.
- Testar migrações e comportamentos de leitura e escrita que forem implementados.

## Esquema

Ainda não aplicável. Registrar entidades, campos, restrições, relações e estratégia de migração quando houver uma decisão aprovada.
