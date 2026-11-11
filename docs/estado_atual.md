# Estado atual — Porquinho

**Atualizado em:** 11/11/2026. Ponto de partida de cada sessão. Detalhe das entregas: `docs/entregas_fase2.md` a `docs/entregas_fase7.md`. Histórico de decisões: `docs/historico/decisoes.md`.

## Fase
- Fase 1 (documentação): CONCLUÍDA em 08/11/2026.
- Fase 2 (modelagem física e base técnica): CONCLUÍDA em 10/11/2026 (Entregas 1–21).
- Fase 3 (estrutura Flutter e base offline): CONCLUÍDA em 10/11/2026 (Entregas 23–31 validadas pelo responsável).
- Fase 4 (categorias e lançamentos avulsos): CONCLUÍDA em 11/11/2026 (Entregas 32–42, `docs/entregas_fase4.md`, validadas pelo responsável).
- Fase 5 (recorrências): CONCLUÍDA em 11/11/2026 (Entregas 43–50, `docs/entregas_fase5.md`, validadas pelo responsável). 
- Fase 6 (investimentos simples e rendimentos manuais): CONCLUÍDA em 11/11/2026 (Entregas 51–58, `docs/entregas_fase6.md`; a 54 foi removida por D3; validadas pelo responsável; commit `3560366`). Fase 8: NÃO INICIADA.
- Fase 7 (períodos, Dashboard e relatórios, `docs/entregas_fase7.md`): EM VALIDAÇÃO em 11/11/2026. Feitas 59A, 59–66 e 68; **67 (assistente inicial) ADIADA**; gráficos (D9) aguardando aprovação da biblioteca. Nada commitado.
- Plataformas do MVP: Android e Web (iOS fora do MVP — decisão de 10/11/2026). Web somente online.

## Entregas (detalhe em cada arquivo de fase)
| Fase | Entregas | Arquivo | Observação |
|---|---|---|---|
| 2 | 1–21 | `entregas_fase2.md` | Entregas 3, 4, 7B–8 sem validação registrada; biometria só em testes automáticos |
| 3 | 22(→Fase 4), 23–31 | `entregas_fase3.md` | Validadas |
| 4 | 22, 32–42 | `entregas_fase4.md` | Validadas |
| 5 | 43–50 | `entregas_fase5.md` | Validadas |
| 6 | 51–58 (54 removida) | `entregas_fase6.md` | Validadas |
| 7 | 59–68 (+59A) | `entregas_fase7.md` | Implementada exceto 67; aguarda validação |

## Lacunas conhecidas
- Contrato de dados Web × celular tem só a porta de gravação e o modo (`lib/core/data_access.dart`); repositórios local e remoto nascem com cada funcionalidade.
- Faixa "sem conexão" demora até 1 minuto para refletir a volta da rede.
- Onboarding (Entrega 67): migration e RPC `set_onboarding_step` já existem no servidor; falta Drift v5 (coluna local) — `drift_schemas/` está bloqueada por permissão.
- Listas de lançamentos da Web limitadas a 1.000 linhas por consulta (`remote_table_reader.dart`); as somas serão resolvidas na Fase 7 (D11).

## Pendências técnicas (lista-mestra: `docs/arquitetura.md` §15)
1. Validar migrations, grants, RLS e ownership no Supabase gerenciado; provisionar dev/teste/produção — Fase 8 (exige autorização explícita).
2. Backup, restauração, retenção, CSV e exclusão definitiva da conta (FKs hoje `RESTRICT`).
3. Observabilidade e Vector do Supabase local reiniciando (notificações móveis: feitas na Fase 5).
4. Relatórios 4 e 5 sem biblioteca de gráficos (D9 pendente de aprovação).
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

## Próximo passo
Validar a Fase 7; decidir Entrega 67 (liberar `drift_schemas/`) e a biblioteca de gráficos. Commits só quando você pedir.
