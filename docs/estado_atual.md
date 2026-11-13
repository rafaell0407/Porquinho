# Estado atual — Norte

**Atualizado em:** 12/11/2026.

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
  - V2 ícone e cor nas categorias: migration `20261113000300` (aplicada só no Supabase **local**), Drift v6, sincronização e conflito levando os dois campos.
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

## Próximo passo
Validar a 76; decidir D1/D5; depois Entrega 77 (backup).

## Testar no Android (máquina do responsável)
Emulador `Medium_Phone_API_37.0`, sem flags gráficas; app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` e chave publicável local. Login Google exige `adb reverse tcp:54321 tcp:54321`.
