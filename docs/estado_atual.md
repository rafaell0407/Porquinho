# Estado atual — Porquinho

**Atualizado em:** 11/11/2026. Ponto de partida de cada sessão. Detalhe das entregas: `docs/entregas_fase2.md` a `docs/entregas_fase6.md`. Histórico de decisões: `docs/historico/decisoes.md`.

## Fase
- Fase 1 (documentação): CONCLUÍDA em 08/11/2026.
- Fase 2 (modelagem física e base técnica): CONCLUÍDA em 10/11/2026 (Entregas 1–21).
- Fase 3 (estrutura Flutter e base offline): CONCLUÍDA em 10/11/2026 (Entregas 23–31 validadas pelo responsável).
- Fase 4 (categorias e lançamentos avulsos): CONCLUÍDA em 11/11/2026 (Entregas 32–42, `docs/entregas_fase4.md`, validadas pelo responsável).
- Fase 5 (recorrências): CONCLUÍDA em 11/11/2026 (Entregas 43–50, `docs/entregas_fase5.md`, validadas pelo responsável). 
- Fase 6 (investimentos simples e rendimentos manuais): IMPLEMENTADA em 11/11/2026 (Entregas 51–58, `docs/entregas_fase6.md`; a 54 foi removida por D3). **VALIDADA pelo responsável em 11/11/2026.** Fases 7 e 8: NÃO INICIADAS.
- Plataformas do MVP: Android e Web (iOS fora do MVP — decisão de 10/11/2026). Web somente online.

## Entregas
| Entrega | Resumo | Situação |
|---|---|---|
| 1–8 | Banco PostgreSQL/Supabase: schema, RPCs de categorias, períodos, subcategorias, investimentos, lançamentos e recorrências | 1, 2, 5, 6 validadas; 3, 4, 7A–8 sem validação registrada |
| 9–10 | Drift local v1 e precisão monetária (nativo e Web) | 10 validada |
| 11–12 | Criptografia local (SQLite3MultipleCiphers), Drift cifrado, schema v2 | validadas |
| 13 | Origem da chave do banco (`flutter_secure_storage`, projeto `android/`) | validada |
| 14–19 | Sessão, Supabase Auth, confirmação de e-mail, login, nova senha, banco local ligado ao app, logout | validadas |
| 20 | PIN/biometria (RF003) | validada (biometria só em testes automáticos) |
| 21 | Protocolo de sincronização (21A–21D): estados, RPC `resolve_sync_conflict`, motor de envio, logout com pendências | validada (10/11/2026) |
| 22 | Itens que precisam de atenção (conflitos e recusas), celular e Web | validada (11/11/2026) |
| 23 | Composição pelo Riverpod | validada |
| 24 | Navegação Dashboard / Lançamentos / Mais | validada (10/11/2026) |
| 25 | Banco local ligado ao usuário (D2) | validada (10/11/2026) |
| 26 | Gravação local única e versão após envio | validada (10/11/2026) |
| 27A | Proposta do download | aprovada (escopo ampliado: tudo) |
| 27B | Download dos dados do servidor (Drift v3) | validada (10/11/2026) |
| 28 | Indicador de conexão e sincronização | validada (10/11/2026) |
| 29 | Web somente online | validada (10/11/2026) |
| 31 | Fechamento da Fase 3 | validada (10/11/2026) |
| 32–42 | Fase 4: domínio (dinheiro, períodos, sobra), fila com dependências, primeiro acesso, períodos sob demanda, categorias e subcategorias, receita e despesa avulsas, Dashboard e Lançamentos | validadas (11/11/2026) |
| 43–50 | Fase 5: domínio da agenda, migration de geração determinística e conversão, "Repetir" no formulário, geração local e no servidor, receitas e despesas recorrentes, alertas Android, fechamento | validadas (11/11/2026; detalhe em `docs/entregas_fase5.md`) |
| 51–58 | Fase 6: investimento avulso (domínio, sincronização e atenção, "Novo investimento" em Lançamentos), investimento recorrente (migration do servidor, Drift v4, "Repetir" e Mais → Recorrências), rendimento como receita comum e regressão | implementadas e validadas (11/11/2026) |

## Lacunas encontradas (diagnóstico da Fase 3)
- Contrato de dados Web × celular só tem a porta de gravação e o modo (`lib/core/data_access.dart`); os repositórios local e remoto nascem com cada funcionalidade (Fase 4+).
- Faixa "sem conexão" demora até 1 minuto para refletir a volta da rede (intervalo do agendador).
- `user_preferences` sem RPC de gravação (Fase 7, nova migration).
- Diagnóstico da Fase 4 (detalhe em `docs/entregas_fase4.md`): servidor recusa lançamento sem período e não cria períodos para trás (Entrega 34B, nova migration); fila não respeita dependência entre registros (Entrega 35); faltam conversor BRL e data corrente na zona do usuário (Entrega 32).

## Pendências técnicas (lista-mestra: `docs/arquitetura.md` §15)
1. Validar migrations, grants, RLS e ownership no Supabase gerenciado; provisionar dev/teste/produção — Fase 8 (exige autorização explícita).
2. Backup, restauração, retenção, CSV e exclusão definitiva da conta (FKs hoje `RESTRICT`).
3. Observabilidade e Vector do Supabase local reiniciando (notificações móveis: feitas na Fase 5).
4. No app: consultas dos cinco relatórios (Fase 7).
5. Medir índices e metas de desempenho (RN043).

## Ações do responsável
- Trocar a chave secreta do Google exposta no chat.
- Testar biometria em aparelho com digital cadastrada.
- Autorizar e fornecer referências do Supabase gerenciado (Fase 8).

## Decisões abertas
- Ambientes hospedados dev/teste/produção: PROPOSTA (Fase 8).
- Política para futura alteração da zona IANA do usuário: pendente.

## Como testar no Android (máquina do responsável)
Emulador `Medium_Phone_API_37.0`, aberto sem flags gráficas; app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` e a chave publicável local. Google exige `adb reverse tcp:54321 tcp:54321`. Detalhes na memória do agente.

## Decisões da Fase 4 (10/11/2026)
D1–D13 registradas em `docs/entregas_fase4.md`. Destaques: datas passadas e futuras aceitas em receitas e despesas (RN004, RN008); períodos anteriores/futuros sob demanda com confirmação (RN002); desfazer pagamento, reativar categoria e desfazer cancelamento fora do MVP; sugestões de categorias no primeiro acesso (RN024).

## Próximo passo
Fase 7 (períodos, Dashboard e relatórios), mediante autorização. A Fase 6 está validada. As alterações da Fase 6 estão sem commit; commit só quando você pedir.
Divergências V4 e V5 (`docs/entregas_fase6.md`): resolvidas — o commit `1f97003` registra a Fase 5 como concluída e validada.
