# Estado atual — Porquinho

**Atualizado em:** 10/11/2026. Ponto de partida de cada sessão. Detalhe das entregas: `docs/entregas_fase2.md` e `docs/entregas_fase3.md`. Histórico de decisões: `docs/historico/decisoes.md`.

## Fase
- Fase 1 (documentação): CONCLUÍDA em 08/11/2026.
- Fase 2 (modelagem física e base técnica): CONCLUÍDA em 10/11/2026 (Entregas 1–21).
- Fase 3 (estrutura Flutter e base offline): EM EXECUÇÃO — planejamento aprovado em 10/11/2026. Fases 4 a 8: NÃO INICIADAS.
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
| 22 | Tela de resolução de conflitos | planejada para o início da Fase 4 |
| 23 | Composição pelo Riverpod | validada |
| 24 | Navegação Dashboard / Lançamentos / Mais | implementada; aguarda sua validação |
| 25 | Banco local ligado ao usuário (D2) | implementada; aguarda sua validação |
| 26 | Gravação local única e versão após envio | implementada; aguarda sua validação |
| 27A | Proposta do download | aprovada em 11/11/2026 (escopo ampliado: tudo) |
| 27B | Download dos dados do servidor (Drift v3) | implementada; aguarda sua validação |
| 28 | Indicador de conexão e sincronização | implementada; aguarda sua validação |
| 29 | Web somente online | implementada (compila); falta rodar no Chrome |
| 31 | Fechamento da Fase 3 | testes automáticos ok; falta sua regressão no emulador e no Chrome |

## Lacunas encontradas (diagnóstico da Fase 3)
- Contrato de dados Web × celular só tem a porta de gravação e o modo (`lib/core/data_access.dart`); os repositórios local e remoto nascem com cada funcionalidade (Fase 4+).
- Faixa "sem conexão" demora até 1 minuto para refletir a volta da rede (intervalo do agendador).
- `user_preferences` sem RPC de gravação (Fase 7, nova migration).

## Pendências técnicas (lista-mestra: `docs/arquitetura.md` §15)
1. Validar migrations, grants, RLS e ownership no Supabase gerenciado; provisionar dev/teste/produção — Fase 8 (exige autorização explícita).
2. Backup, restauração, retenção, CSV e exclusão definitiva da conta (FKs hoje `RESTRICT`).
3. Observabilidade, notificações móveis e Vector do Supabase local reiniciando.
4. No app: ciclos 29–31 e ano bissexto (Fase 4), alertas após o fim do período, consultas dos cinco relatórios.
5. Medir índices e metas de desempenho (RN043).

## Ações do responsável
- Validar as Entregas 24, 25, 26, 27B, 28, 29 e 31 (roteiro em `docs/entregas_fase3.md`, seção "Roteiro de validação").
- Trocar a chave secreta do Google exposta no chat.
- Testar biometria em aparelho com digital cadastrada.
- Autorizar e fornecer referências do Supabase gerenciado (Fase 8).

## Decisões abertas
- Ambientes hospedados dev/teste/produção: PROPOSTA (Fase 8).
- Política para futura alteração da zona IANA do usuário: pendente.

## Como testar no Android (máquina do responsável)
Emulador `Medium_Phone_API_37.0`, aberto sem flags gráficas; app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` e a chave publicável local. Google exige `adb reverse tcp:54321 tcp:54321`. Detalhes na memória do agente.

## Próximo passo
Sua validação das Entregas 24–31 (roteiro em `docs/entregas_fase3.md`). Depois, fechar a Fase 3 e iniciar a Fase 4.
