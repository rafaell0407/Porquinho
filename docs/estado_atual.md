# Estado atual — Norte

**Atualizado em:** 14/11/2026.

## Fase
- Fases 1–7: CONCLUÍDAS e validadas (detalhe em `historico/`).
- **Fase 8** (sincronização completa, qualidade e publicação — `entregas_fase8.md`): EM EXECUÇÃO.
  - Validadas: 69–74 e 75 parcial (falta D1).
  - 76: feita exceto SMTP, aguardando validação (homologação `norte-homologacao`, 19 migrations, 33 testes de integração passando).
  - Restam: 75 final, 77–82 (ver `pendencias.md` §E).
- Plataformas: Android (offline) e Web (somente online). iOS fora do MVP.

## Renovação visual (12/11/2026)
Direção aprovada: Menta (cor) + Inter (fonte), claro e escuro, categorias com ícone e cor. Página de referência: https://claude.ai/artifact/3fe4gLefj1U3voHDRq6cA6 (privada).
- **V1–V5 feitas (12/11/2026), aguardando validação no emulador, claro e escuro** (`pendencias.md` §V e R5):
  - V1 tema central (`lib/app/theme/norte_theme.dart`), fonte Inter embutida.
  - V2 ícone e cor nas categorias: migration `20261113000300` (aplicada no Supabase local e em `norte-homologacao`), Drift v6, sincronização e conflito levando os dois campos.
  - V3 Dashboard; V4 Lançamentos (lista por dia, ícone/cor da categoria) e formulário (valor grande, seletor de categoria); V5 Categorias (editor com ícone/cor), seletor de categoria e menu Mais; barra de abas em pílula.
- Testes: `flutter analyze` sem problemas; suíte completa (inclui migração Drift v5→v6), 13 testes SQL e integração contra o Supabase local passaram.

## Evolução visual da Dashboard (12/11/2026) — aguardando validação
Layout da imagem de referência: seletor de período em pílula + botão "+" (abre o mesmo menu de novo lançamento), dinheiro livre com "R$" menor, barra segmentada (receitas/despesas/investimentos, proporcional), legenda com valores, card de atenção (só com itens; abre `/atencao`) e card "A receber (ainda não conta)" com as receitas pendentes reais. Rótulo "Nov 2026" vira intervalo de datas quando o período é ciclo. Barra inferior: aba selecionada com texto em Menta. Sem mudança de regra, banco ou rotas.

## Entrega avulsa (12/11/2026) — aguardando validação
Criar categoria direto no formulário de lançamento ("+ Nova categoria", receita/despesa; não no investimento). Subcategoria no formulário ficou fora (M5, aguarda aprovação).

## Formulário de lançamento no layout da referência (13/11/2026) — aguardando validação
Cabeçalho com título centralizado e botão fechar, seletor de tipo em pílula (só em lançamento novo; troca despesa/receita/investimento), valor grande, campos em linhas com divisor, "Repetir" como lista de opções (Não se repete / Todo mês / Todo período), texto explicativo por tipo e botão "Salvar despesa/receita/investimento" fixo embaixo. Sem mudança de regra, banco ou sincronização.

## Entrega 79 — parcial (12/11/2026), aguardando validação
Feito: tratamento global de erros, sem valores nos registros. O restante (produção, SMTP, monitoramento externo) depende das Entregas 77/78, de domínio e de autorização.

## Reestruturação de períodos (13/11/2026) — P2–P7 feitas, aguardando validação
Aprovada pelo responsável: configuração única trocável a qualquer momento (vale para todos os períodos), período calculado por datas, repetição só "Todo mês" com último dia útil em dia inexistente. Plano em `pendencias.md` §P (P1 validada).
- **O que mudou para o usuário:** não existe mais "Criar os períodos…?"; qualquer data tem período. Mais → Período troca a configuração na hora, com aviso de que totais de períodos antigos podem mudar. As setas navegam do lançamento mais antigo ao mais distante. "Repetir" oferece só "Todo mês"; dia 29–31 em mês sem esse dia cai no último dia útil do mês (vencimento junto). Modelos antigos "Todo período" ficaram desativados.
- **Servidor (Supabase local e `norte-homologacao`):** migrations `20261113000400` (relatório por datas), `0500` (recorrência só mensal + dia útil), `0600` (configuração única `period_settings`, vínculo opcional, RPCs sem período), `0700` (remove tabelas de período, vínculos e RPCs antigas).
- **Celular:** Drift v8 (v7: `period_settings`; v8: sem tabelas/vínculos de período), migrações testadas com dados.
- **Rede de segurança (P4):** antes de remover qualquer coisa, soma pelo período gravado = soma pelas datas em todos os períodos (celular, servidor e 4.439 lançamentos reais do banco local); nenhuma diferença.
- **Testes:** `flutter analyze` sem problemas; 1.086 testes do app; suíte SQL completa (inclui 360 casos compartilhados da data mensal); 31 de integração com o Supabase local; catálogo de segurança no Supabase local.

## Nova barra inferior (13/11/2026) — aguardando validação
Barra em pílula (formato aprovado após comparar com a versão retangular), com Adicionar (+, círculo elevado no centro) abrindo o mesmo menu de novo lançamento da Dashboard; Categorias segue em Mais. O item Relatórios foi substituído por Ferramentas (ver abaixo). Ajuste de 13/11: o "+" estava colado na barra e sobre o rótulo; agora fica elevado acima da borda, com "Adicionar" abaixo (conferido no emulador, tema escuro). Sem mudança de regra financeira, banco ou sincronização.

## Menu "O que você quer registrar?" (13/11/2026) — aguardando validação
O menu do "+" virou bottom sheet com cartões (Despesa, Receita, Investimento), alça no topo e cantos arredondados, no layout da referência. Mesmas chaves e fluxos de antes. Sem "Transferência" (contas fora do MVP) e sem "Ver todos os atalhos" (não existe no app). Arquivo: `lib/features/transactions/transactions_screen.dart`.

## Aba Ferramentas (13–14/11/2026) — validada pelo responsável em 14/11/2026
- **Para o usuário:** a barra inferior ficou Home, Ferramentas, Adicionar (+), Lançamentos e Mais; Ferramentas é aba de verdade (fica selecionada, inclusive dentro de Relatórios). A tela tem título, subtítulo, Personalizar, busca, "Suas ferramentas" (cartões em 2 colunas no celular, 1 em tela estreita) e "Outras ferramentas" (botão +, agrupadas por categoria quando houver mais de uma; filtro por categoria idem). Área "Em destaque" só aparece se alguma ferramenta for marcada como destaque (hoje nenhuma). Personalizar: arrastar para ordenar, remover, adicionar e "Restaurar padrão" com confirmação. Ícone de informação em toda ferramenta (para que serve, como funciona, premissas, aviso). Ferramentas que pedirem explicação antes do primeiro uso mostram a tela com "Continuar" e "Não mostrar novamente" (por ferramenta).
- **Relatórios:** os cinco relatórios viraram a ferramenta "Relatórios" (padrão em Suas ferramentas, explicação sob demanda), mesma tela e mesmos cálculos; rota `/relatorios` mantida. Saiu do menu Mais (evita atalho duplicado).
- **Persistência:** `user_preferences.tools` pelo repositório de preferências já existente. Celular: banco local + fila (Drift v9, migração testada). Web: RPCs direto. Lista: última gravação vence (decisão do responsável, 13/11/2026); "Não mostrar novamente" se soma entre aparelhos. Migration `20261113000800` (RPCs `set_tool_selection`, `dismiss_tool_intro`) aplicada no Supabase local e em `norte-homologacao` (14/11/2026, pelo responsável).
- **Sem mudança** de regra financeira, cálculo, lançamentos ou escopo; nenhuma ferramenta fictícia.
- **Testes:** `flutter analyze` sem problemas; suíte completa 1.128 passando (31 de integração pulados); suíte SQL completa com o novo `rpc_tool_preferences_test.sql` e catálogo de segurança. Web (`--platform chrome`) não roda neste ambiente (T9).

## Próximo passo
Validar P2–P7 no emulador e na Web (P8; roteiro T7). Homologação só com autorização (R2). Fase 8 (76, D1/D5, 77) retoma depois.

## Testar no Android (máquina do responsável)
Emulador `Medium_Phone_API_37.0`, sem flags gráficas; app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` e chave publicável local. Login Google exige `adb reverse tcp:54321 tcp:54321`.
