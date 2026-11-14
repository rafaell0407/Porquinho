# CLAUDE.md — Norte

App de finanças pessoais (Flutter, Android + Web). Único arquivo de instruções do agente (o antigo AGENTS.md foi incorporado aqui em 12/11/2026; texto integral no histórico do Git).

## 1. Início de sessão
1. Ler `docs/estado_atual.md` (fase e última entrega) e, se for planejar, `docs/pendencias.md`.
2. Ler os demais documentos **só sob demanda**, pela tabela abaixo. Não reler o que já foi lido; não fazer varredura geral em tarefa pontual.
3. Não refazer entregas concluídas.

| Preciso de… | Arquivo |
|---|---|
| Fase, última entrega, próximo passo | `docs/estado_atual.md` |
| O que falta: decisões (D), ações do responsável (R), técnicas (T), ajustes (A), melhorias (M) | `docs/pendencias.md` (lista-mestra, IDs fixos) |
| Onde fica cada tela/módulo/arquivo, com RF/RN e tabelas | `docs/mapa_app.md` (ler a linha do módulo antes de abrir código) |
| Escopo funcional (RF) | `docs/requisitos.md` (buscar pelo ID) |
| Regras financeiras (RN) | `docs/regras_negocio.md` (buscar pelo ID, ex. `### RN038`) |
| Stack, camadas, sync, segurança, ambientes | `docs/arquitetura.md` (só o vigente) |
| Tabelas, RPCs, migrations, Drift | `docs/banco_de_dados.md` (só o vigente) |
| Entregas da fase atual (8) | `docs/entregas_fase8.md` |
| Fases 2–7, roadmap, versões longas de arquitetura/banco, decisões superadas | `docs/historico/` (só consulta; ler apenas se pedido ou indispensável) |

Manutenção: docs vigentes descrevem só o que vale hoje (sem histórico de status); o que ficar superado vai para `docs/historico/`. Novo módulo/tela/rota → atualizar `mapa_app.md`; nova tabela/RPC/migration → `banco_de_dados.md`.

Fonte de verdade: `requisitos.md` (escopo) e `regras_negocio.md` (financeiro) prevalecem; em conflito entre documentos, código e pedido, **não escolher em silêncio** — apontar a divergência e pedir confirmação se mexer em regra financeira, escopo ou decisão técnica aprovada. Status usados: APROVADO, PROPOSTA, PENDENTE, FORA DO ESCOPO.

## 2. Comandos (Windows / PowerShell)
- `flutter pub get` · `dart run build_runner build --delete-conflicting-outputs`
- `dart format lib test` · `flutter analyze`
- `flutter test [arquivo]` · Web: `flutter test --platform chrome`
- PostgreSQL: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tooling/test_postgres_schema.ps1`
- Supabase local: `supabase start` / `supabase status`

## 3. Limites
- Nunca `supabase db push`, `supabase link` ou ação no Supabase gerenciado sem autorização explícita.
- Nunca `git push`. Commit só quando pedido.
- Não editar migrations existentes em `supabase/migrations/`; criar nova.
- Schema Drift alterado: incrementar `schemaVersion`, gerar snapshot em `drift_schemas/` e testar a migração.
- Fase concluída: mover seu `entregas_faseN.md` para `docs/historico/`.
- Uma Entrega por vez; ao final atualizar `estado_atual.md`, `pendencias.md` e docs afetados (`mapa_app.md`, `banco_de_dados.md`, `arquitetura.md`), e parar para validação.
- Não implementar regra marcada PENDENTE nem mudar escopo sem aprovação. O agente não decide regra financeira.
- Problema fora do escopo: registrar em `docs/pendencias.md`, não resolver sozinho.
- Sem segredos, senhas ou tokens no repositório. Nova dependência: avaliar manutenção, licença, segurança e custo antes.

## 4. Regras de produto invioláveis (detalhe nas RNs)
1. **Navegação:** barra inferior em pílula (solta das bordas, + elevado no centro) com Home, Ferramentas, Adicionar (+), Lançamentos e Mais (Ferramentas substituiu Relatórios em 13/11/2026). Abas: Home, Ferramentas, Lançamentos e Mais; + abre o novo lançamento. Os cinco relatórios são uma ferramenta do catálogo Ferramentas (rota `/relatorios`). Categorias e demais itens secundários ficam em Mais. Nova ferramenta = módulo próprio + registro em `lib/features/tools/registry/tool_registry.dart`, só com aprovação; nunca criar ferramenta fictícia.
2. **Fora do MVP — não criar:** contas bancárias/saldos/conciliação; saldo inicial especial (usuário cria categoria comum "Saldo inicial", sem tratamento especial); Porquinho virtual, reservas, compromissos; carteira/ativos/rentabilidade; compras de cartão, parcelas, fatura automática (fatura = despesa recorrente variável); rendimento automático (CDI, taxa).
3. **Indicador único:** dinheiro livre do período = receitas contabilizadas − despesas contabilizadas − investimentos. Sem saldo disponível/atual/bancário, sem sobra de períodos anteriores.
4. **Receitas:** período pela data de recebimento (passada ou futura). Recorrente gera ocorrência pendente; só conta após confirmar. Valor da ocorrência editável sem alterar o modelo.
5. **Despesas:** avulsa conta ao cadastrar; recorrente conta ao gerar (variável, após informar valor). Pagar só muda status/data, sem segunda dedução. Não paga fica no período original.
6. **Investimentos:** só valor e data, sem descrição/categoria/ativo; deduz ao lançar; sem status; pode ser recorrente (conta sem confirmação); sem resgate (desfazer = cancelar). Rendimento recebido = receita comum.
7. **Períodos:** mês-calendário ou ciclo com dia inicial; mudança vale do próximo período; históricos preservam a configuração; sem lacuna/sobreposição; intervalos [início, fim); dia inexistente usa o último dia do mês.
8. **Categorias:** receita ou despesa (tipo imutável), subcategorias opcionais, nunca apagadas — só desativadas; investimentos não usam categorias.
9. **Edição/cancelamento:** qualquer lançamento, em qualquer status; cancelado sai do cálculo mas não é apagado; auditoria com valores antigo/novo, operação, data/hora e usuário; recalcular períodos afetados.
10. **Nome:** Norte (12/11/2026); não reintroduz o módulo "Porquinho virtual".

## 5. Padrões técnicos
- Camadas apresentação / aplicação / domínio / infraestrutura; regras financeiras fora de widgets, centralizadas em domínio testável (ex.: `lib/core/domain/surplus.dart`).
- Dinheiro em BRL, centavos inteiros; nunca ponto flutuante. Não inventar arredondamento, juros ou convenção de data. Zona `America/Sao_Paulo`.
- Competência: receita pela data de recebimento; despesa pela data de cadastro/geração; investimento pela data do lançamento; pagamento não muda o período.
- Cliente e servidor devem dar o mesmo resultado; divergência é sinalizada, nunca corrigida em silêncio.
- Offline primeiro (Android): gravar localmente antes de dizer "salvo"; transações; operações idempotentes; conflito por versão, preservando as versões e informando o usuário — nunca "última gravação vence". Web: somente online.
- Dados isolados por usuário (RLS no servidor, armazenamento protegido no aparelho).

## 6. Testes
Rodar só o relacionado à mudança: format + analyze; unitários de dinheiro livre/competência; edição, cancelamento, recorrência e período; equivalência local × remoto; sync idempotente e conflitos; isolamento por usuário; interface. Nunca declarar teste não executado.

## 7. Comunicação com o responsável
Português simples, focado no comportamento do app; código/logs só se necessário. Respostas curtas, sem relatórios intermediários. Na conclusão, só os itens pertinentes:
- **Implementado:** o que mudou para o usuário.
- **Requisitos:** RFs/RNs atendidos.
- **Testes:** o que rodou e o resultado.
- **Pendências:** o que falta ou precisa de validação (e registrar em `docs/pendencias.md`).
