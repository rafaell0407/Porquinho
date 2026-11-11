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
| 23 | Composição pelo Riverpod | **próxima** |
| 24 | Navegação Dashboard / Lançamentos / Mais | planejada |
| 25 | Banco local ligado ao usuário | planejada |
| 26 | Gravação local única e versão após envio | planejada |
| 27A/27B | Download dos dados do servidor | planejada |
| 28 | Indicador de conexão e sincronização | planejada |
| 29 | Web somente online | planejada |
| 31 | Fechamento da Fase 3 | planejada |

## Lacunas encontradas (diagnóstico da Fase 3)
- Versão local não é atualizada após envio aplicado → conflito falso na próxima edição (Entrega 26).
- Sessão expirada não vincula/limpa o banco local; outra conta usaria o mesmo arquivo (Entrega 25).
- Sem download de dados do servidor (Entrega 27).
- Sem pasta `web/`; app Web nunca executado (Entrega 29).
- `user_preferences` sem RPC de gravação (Fase 7, nova migration).

## Pendências técnicas (lista-mestra: `docs/arquitetura.md` §15)
1. Validar migrations, grants, RLS e ownership no Supabase gerenciado; provisionar dev/teste/produção — Fase 8 (exige autorização explícita).
2. Backup, restauração, retenção, CSV e exclusão definitiva da conta (FKs hoje `RESTRICT`).
3. Observabilidade, notificações móveis e Vector do Supabase local reiniciando.
4. No app: ciclos 29–31 e ano bissexto (Fase 4), alertas após o fim do período, consultas dos cinco relatórios.
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
Entrega 23 (composição pelo Riverpod), após autorização do responsável.
