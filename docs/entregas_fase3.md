# Entregas da Fase 3 — plano e detalhe

Plano aprovado pelo responsável em 10/11/2026. Cada entrega é implementada, testada e validada antes da próxima. Estado vigente: `docs/estado_atual.md`.

## Decisões do planejamento (10/11/2026)
- D1: Entrega 21 (A–D) validada no emulador; Fase 2 concluída.
- D2: outra conta tentando entrar com pendências da conta anterior no aparelho → entrada bloqueada até a anterior sincronizar.
- D3: configuração de período perguntada no primeiro acesso (primeira entrega da Fase 4).
- D4: iOS fora do MVP.
- D5: Fase 3 concluída com o Supabase local; ambientes hospedados na Fase 8.
- D6: Entrega 22 (tela de conflitos) no início da Fase 4, após categorias.
- D7: `test/` mantém a estrutura que espelha `lib/`; `arquitetura.md` §17.1 corrigida.
- D8: gravação de `user_preferences` (tema) por nova função na Fase 7.

## Lacunas encontradas no diagnóstico
- Após envio aplicado, o app só remove a operação da fila e não grava a nova versão local (`sync_service.dart`, `_send`) → conflito falso na próxima edição. Entrega 26.
- Sessão expirada não limpa nem vincula o banco local ao dono (`session_controller.dart`, `_setUser`); arquivo único (`local_database_manager.dart`). Entrega 25.
- Não há download de dados do servidor. Entrega 27.
- Não existe `web/`; a Web nunca rodou como app. Entrega 29.
- Peças montadas à mão em `main.dart`; `ownerIdProvider` sem uso. Entrega 23.

## Entregas

| # | Objetivo | Depende de | Critério de aceitação |
|---|---|---|---|
| 23 | Composição pelo Riverpod: banco, sincronização, sessão e bloqueio como providers; limpar comentários da opção B | — | Comportamento idêntico; testes atuais passam; analyze limpo; login/PIN/logout iguais no emulador |
| 24 | Navegação: abas Dashboard, Lançamentos, Mais (`StatefulShellRoute`); Segurança e Sair em Mais; `lib/shared/` | 23 | Só três destinos; Segurança ausente na Web; redirecionamentos de login/bloqueio/nova senha preservados |
| 25 | Banco local ligado ao usuário (dono no armazenamento seguro); outra conta bloqueada se houver pendências da anterior (D2); sessão expirada preserva dados | 23 | Testes com 2 usuários: mesma conta reabre; outra sem pendências apaga; outra com pendências bloqueada |
| 26 | Gravação local única (registro + auditoria + fila em uma transação) e versão local após envio aplicado | 23 | Falha no meio não grava nada; versão local = servidor; duas edições seguidas sem conflito falso |
| 27A | Proposta do download (docs): leitura incremental por tabela, ordem de dependência, pendência local nunca sobrescrita (vira conflito), necessidade de nova migration | 26 | Proposta aprovada |
| 27B | Download: mecanismo genérico + preferências, configurações de período, períodos e categorias | 27A | Supabase local: aparelho novo baixa tudo; repetição não duplica; pendência local × mudança remota vira conflito; isolamento por usuário |
| 28 | Indicador de conexão/sincronização (sem dependência nova) e "Sincronizar agora" em Mais; contagem de itens que precisam de atenção | 24, 26 | Emulador em modo avião: sem conexão → volta → sincronizado; contagem de conflitos/recusas visível |
| 29 | Web somente online: criar `web/`; contrato de acesso a dados com implementação local (celular) e remota (Web); aviso sem conexão bloqueia gravação; retirar `_NoLocalDataYet` | 24, 28 | Login e navegação no Chrome; nada gravado localmente na Web |
| 31 | Fechamento: regressão no emulador e Chrome; documentos atualizados | todas | Critérios de conclusão abaixo |

A Entrega 30 (iOS) saiu do plano (D4).

## Matriz de testes
| Área | Unidade | Widget | Supabase local | Emulador | Chrome |
|---|---|---|---|---|---|
| 23 | ✓ | ✓ | — | ✓ | — |
| 24 | — | ✓ | — | ✓ | ✓ (em 29) |
| 25 | ✓ | — | — | ✓ | — |
| 26 | ✓ | — | ✓ | — | — |
| 27B | ✓ | — | ✓ | ✓ | — |
| 28 | ✓ | ✓ | — | ✓ | — |
| 29 | ✓ | — | — | — | ✓ manual |
| 31 | todos | todos | ✓ | ✓ | ✓ |

`flutter test --platform chrome` não abre nesta máquina; a verificação Web do app é manual.

## Critérios de conclusão da Fase 3
1. Três abas no Android e na Web, sem outras áreas.
2. Login, PIN, logout com pendências e recuperação de senha sem regressão no emulador.
3. Banco local nunca compartilhado entre contas (teste com 2 usuários).
4. Gravação local única pronta; nenhum conflito falso após envio.
5. Download idempotente e isolado por usuário no Supabase local.
6. Indicador de estado validado em modo avião.
7. App Web rodando no Chrome, somente online.
8. `flutter analyze` limpo, suíte completa passando, documentos atualizados.
9. Pendências do responsável (Supabase gerenciado, chave do Google, biometria real) registradas, sem bloquear a fase (D5).

## Preparação para a Fase 4 (não antecipar)
A Fase 4 abre com: primeiro acesso com escolha do período (D3) e cálculo local de períodos; categorias com gravação local única e download; Entrega 22; depois receitas, despesas e cálculo da sobra.
