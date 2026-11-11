# CLAUDE.md — Porquinho

@AGENTS.md

## Contexto da transição
O desenvolvimento foi iniciado com o Codex e continua com o Claude Code a partir da Fase 2.
O histórico do Git e docs/historico/decisoes.md registram o que já foi feito.
Não refaça entregas concluídas; parta do estado registrado em docs/estado_atual.md (leia primeiro).

## Documentos de referência (ler sob demanda, não todos de uma vez)
- Estado atual (fase, última entrega, pendências): docs/estado_atual.md
- Escopo: docs/requisitos.md
- Regras financeiras: docs/regras_negocio.md
- Arquitetura: docs/arquitetura.md (seção 15 = pendências técnicas; seção 17 = Fase 2)
- Banco: docs/banco_de_dados.md (seções 16.8 a 16.10 = schema, RPCs e Drift)
- Ordem de execução: docs/roadmap.md
- Histórico de entregas e textos superados (só consulta): docs/historico/decisoes.md

## Comandos do projeto (Windows / PowerShell)
- Dependências: `flutter pub get`
- Geração Drift: `dart run build_runner build --delete-conflicting-outputs`
- Formatação: `dart format lib test`
- Análise: `flutter analyze`
- Testes Flutter: `flutter test` (um arquivo: `flutter test caminho/do_teste.dart`)
- Testes Web: `flutter test --platform chrome`
- Suíte PostgreSQL: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tooling/test_postgres_schema.ps1`
- Supabase local: `supabase start` / `supabase status` (projeto porquinho-dev)

## Limites
- Nunca executar `supabase db push`, `supabase link` ou qualquer ação no Supabase gerenciado sem autorização explícita.
- Nunca fazer `git push`. Commits só quando eu pedir.
- Não editar migrations já existentes em supabase/migrations/; mudanças vão em nova migration.
- Ao alterar schema Drift: incrementar schemaVersion, gerar snapshot em drift_schemas/ e testar a migração.
- Trabalhar uma "Entrega" por vez; ao final, atualizar roadmap.md e os documentos afetados e parar para validação.