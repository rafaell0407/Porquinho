# Instruções de desenvolvimento

Estas instruções se aplicam a todo o repositório. Leia também os documentos em `docs/` antes de alterar o projeto e mantenha-os alinhados com decisões confirmadas.

## Estado atual

- A pasta está em fase de preparação e ainda não contém um aplicativo Flutter, código-fonte, testes ou `pubspec.yaml`.
- Não presuma funcionalidades, usuários, regras de negócio, arquitetura ou banco de dados a partir do nome da pasta.
- Registre decisões como pendentes até que sejam confirmadas. Não transforme sugestões em requisitos aprovados.

## Preservação e segurança das alterações

- Antes de editar, inspecione os arquivos afetados e o estado do repositório. Preserve o comportamento existente e limite cada alteração ao objetivo solicitado.
- Não apague, substitua ou regenere arquivos do projeto sem necessidade demonstrável. Nunca use comandos destrutivos amplos como forma de “limpar” o projeto.
- Não altere configurações, plataformas, versões ou arquivos gerados sem explicar a necessidade e o impacto. Preserve mudanças locais preexistentes.
- Não adicione dependências quando a biblioteca padrão ou recursos já existentes forem suficientes. Justifique dependências novas e atualize o lockfile com o gerenciador apropriado.
- Não inclua segredos, credenciais, chaves privadas ou dados pessoais em código, documentação ou logs. Use configuração segura e exemplos fictícios.
- Para mudanças de dados, preserve dados existentes, descreva migrações e considere como reverter a alteração antes de executá-la.

## Qualidade e verificação

- Ao implementar ou corrigir código, adicione ou atualize testes que cubram o comportamento alterado e execute os testes e verificações aplicáveis ao escopo.
- Em um projeto Flutter válido, prefira executar `flutter analyze` e `flutter test`; execute também verificações específicas necessárias para a mudança.
- Se uma ferramenta ou verificação não puder ser executada, informe o comando, o bloqueio observado e o que ficou sem validação. Não afirme que algo foi testado sem executá-lo.
- Siga a formatação e as convenções já adotadas pelo projeto. Não faça reformatação ampla incidental.
- Revise o diff para confirmar que só contém alterações intencionais e que nenhuma funcionalidade ou configuração foi removida por acidente.

## Documentação

- Atualize `docs/` quando uma mudança alterar requisitos, arquitetura, persistência, regras de negócio ou plano de entrega.
- Separe fatos observados, decisões aprovadas e propostas. Identifique explicitamente pontos que ainda dependem de confirmação.
