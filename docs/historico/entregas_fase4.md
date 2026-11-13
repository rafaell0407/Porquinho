# Fase 4 — Categorias e lançamentos avulsos (registro compacto)

**Status:** CONCLUÍDA e VALIDADA pelo responsável em 11/11/2026 (Entregas 32–42, incluindo a 22). Estado vigente: `docs/estado_atual.md`. Regras: `docs/regras_negocio.md`; escopo: `docs/requisitos.md`.

## Entregas (ordem de execução: 32 → 33 → 35 → 34A → 34B → 36 → 37 → 22 → 38 → 39 → 40 → 41 → 42)
| # | Resultado |
|---|---|
| 32 | `core/domain`: BRL ↔ centavos em `BigInt` (recusa `1,234` e `-1`; zero aceito; limite de 64 bits), data civil e relógio `America/Sao_Paulo` (pacote `timezone`) |
| 33 | `PeriodCalendar`: período que contém a data, seguinte, anterior e transição de configuração; paridade com a RPC no Supabase local |
| 35 | Fila com `depends_on`: dependente espera a criação ainda na fila, sem recusa |
| 34A | Escolha de modalidade e dia inicial no primeiro acesso; períodos faltantes até hoje ao abrir; conta já configurada (baixada) não pergunta |
| 34B | Migration `20261111000200` (`create_earlier_accounting_period`) + confirmação ("Criar os 3 períodos de agosto de 2026 a outubro de 2026?"); limite de 240 períodos por confirmação |
| 36, 37 | Mais → Categorias e subcategorias: criar, renomear, desativar; sugestões do primeiro acesso |
| 22 | Mais → Itens que precisam de atenção (e faixa no topo): manter a minha / a do servidor / editar; recusas com motivo, tentar de novo e descartar (com confirmação); também na Web |
| 38 | `computePeriodTotals` e consulta por período (local e Web); 5.000 lançamentos em < 300 ms (RN043) |
| 39, 40 | Receita e despesa avulsas: cadastrar, editar, pagar, cancelar, "já paga"; lista por período com filtro Todos/Receitas/Despesas |
| 41 | Dashboard só com a sobra e navegação entre períodos |
| 42 | Fechamento: fluxo celular offline → sincronização → totais iguais no servidor e em aparelho novo; Web; isolamento entre dois usuários |

## Decisões (10/11/2026, APROVADAS)
| # | Decisão |
|---|---|
| D1 | A fase inclui primeiro acesso com escolha do período e a Entrega 22 |
| D2 | Responsável valida a Fase 3 antes (validada em 10/11) |
| D3 | "Hoje" em `America/Sao_Paulo` com o pacote `timezone` |
| D4 | Receitas e despesas aceitam data futura (RN004/RN008); o app não verifica se o valor foi recebido |
| D5 | Data do lançamento informada pelo usuário (padrão hoje) |
| D6 | Datas anteriores ao primeiro período aceitas; períodos anteriores e futuros criados sob demanda, com a configuração do primeiro e após confirmação (RN002); exigiu a migration da 34B |
| D7 | Desfazer pagamento, reativar categoria e desfazer cancelamento: FORA DO MVP por ora |
| D8 | Renomear categoria mantém o vínculo; lançamentos exibem o nome atual (RN040) |
| D9 | Dashboard só com o número da sobra (composição na Fase 7) |
| D10 | Despesa pode ser cadastrada "já paga" (mesma gravação, dois eventos de auditoria) |
| D11 | Tela de atenção também na Web, para conflitos abertos no servidor |
| D12 | Filtros de Lançamentos: período e tipo; categoria e status na Fase 7 |
| D13 | Sugestões de categorias no primeiro acesso, todas marcadas e desmarcáveis, sem tratamento especial depois. Receitas: Salário, Renda extra, Rendimentos. Despesas: Moradia, Alimentação, Mercado, Transporte, Saúde, Educação, Lazer, Contas da casa, Assinaturas, Fatura do cartão. Sem subcategorias prontas |

## Decisões de implementação (11/11/2026, confirmadas na validação)
- Nome de categoria/subcategoria: obrigatório, até 60 caracteres, duplicados permitidos. Descrição de lançamento: até 120 caracteres.
- Lançamento cancelado não pode mais ser editado, pago ou cancelado (coerente com D7; o servidor permitiria).
- Sugestões de categorias aparecem uma vez, após a escolha do período; depois só criando em Mais.
- Período criado para trás herda a configuração do primeiro e não altera o início dela.
- Conflito de criação (ex.: mesmo período criado em dois aparelhos) só aceita "manter a do servidor"; o registro local é substituído e os lançamentos passam a apontar para o do servidor.
- Descartar recusa de criação apaga o registro local e as demais operações dele; descartar recusa de edição restaura o registro do servidor no próximo download.
- Editar a versão final de um conflito: nome (categorias) ou valor e descrição (lançamentos).
- Datas em dd/MM/aaaa; interface em português (`pt-BR`).

## Lacunas do diagnóstico (todas resolvidas)
Sem período o servidor recusava lançamentos e não criava períodos para trás (34B); a fila não respeitava dependências (35); faltavam conversor BRL e data na zona do usuário (32); o app não calculava períodos (33).

## Testes e limitações
- 11/11/2026: `flutter analyze` limpo; `flutter test` 241 passaram (12 ignorados de integração/plataforma); integração no Supabase local, suíte PostgreSQL e `flutter build web` passaram.
- `flutter test --platform chrome` não carrega testes nesta máquina (vale desde a Fase 3); regressão Web é manual.
- Registrado fora do escopo e já resolvido: `arquitetura.md` §17.1 alinhada (tela em `features/transactions/`, regras em `features/entries/`).
