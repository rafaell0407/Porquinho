# Entregas da Fase 4 — plano e detalhe

Plano aprovado pelo responsável em 10/11/2026. Cada entrega é implementada, testada e validada antes da próxima. Estado vigente: `docs/estado_atual.md`.

## Decisões do planejamento (10/11/2026)
- D1: a Fase 4 inclui o primeiro acesso com escolha do período e a Entrega 22 (tela de conflitos).
- D2: o responsável valida a Fase 3 antes da Fase 4 — Fase 3 validada em 10/11/2026.
- D3: "hoje" calculado em `America/Sao_Paulo` com o pacote `timezone` (dependência avaliada na Entrega 32).
- D4: receitas e despesas aceitam data futura (RN004/RN008 atualizadas). O app não verifica se o valor foi de fato recebido.
- D5: a data do lançamento é informada pelo usuário (padrão hoje) e pode ser diferente de hoje.
- D6: datas anteriores ao primeiro período são aceitas; períodos anteriores e futuros são criados sob demanda, com a mesma configuração do primeiro período, após confirmação do usuário (RN002). Exige nova migration (Entrega 34B).
- D7: desfazer pagamento, reativar categoria e desfazer cancelamento ficam FORA DO MVP por ora.
- D8: renomear categoria mantém o vínculo dos lançamentos, que passam a exibir o nome atual (RN040).
- D9: na Fase 4 o Dashboard mostra somente o número da sobra do período; composição na Fase 7.
- D10: despesa pode ser cadastrada "já paga" (cadastro e pagamento na mesma gravação local, dois eventos de auditoria).
- D11: a tela de itens que precisam de atenção também funciona na Web, para conflitos abertos no servidor.
- D12: filtros de Lançamentos na Fase 4: período e tipo; categoria e status na Fase 7.
- D13: sugestões de categorias no primeiro acesso, todas marcadas e desmarcáveis, sem tratamento especial depois de criadas. Receitas: Salário, Renda extra, Rendimentos. Despesas: Moradia, Alimentação, Mercado, Transporte, Saúde, Educação, Lazer, Contas da casa, Assinaturas, Fatura do cartão. Sem subcategorias prontas.

## Lacunas encontradas no diagnóstico
- P1: o app não calcula períodos; ciclos 29–31 e bissexto sem teste no app (`arquitetura.md` §15 item 10).
- P2: sem período, o servidor recusa lançamentos (`20261109000600_cash_entry_write_rpcs.sql`, "no accounting period covers").
- P3: o servidor só cria período adjacente ao anterior; o primeiro deve começar no `effective_from` da configuração; não cria períodos para trás (`20261109000300_accounting_period_rpc.sql`). Resolvido na 34B.
- P4: a fila só bloqueia operações do mesmo registro; um lançamento pode ser enviado antes da categoria/período de que depende e ser recusado (`sync_service.dart`, `syncOnce`). Resolvido na 35.
- P5: não há conversor de BRL para centavos no Flutter (`banco_de_dados.md` §16.8.7).
- P6: não há data corrente na zona do usuário no app.
- P7: sem ações de desfazer pagamento, reativar categoria ou desfazer cancelamento (D7: fora do MVP).

## Entregas

| # | Objetivo | Depende de | Banco | Critério de aceitação |
|---|---|---|---|---|
| 32 | Domínio: BRL ↔ centavos (`BigInt`), formatação R$, data corrente em `America/Sao_Paulo` (`timezone`) | — | — | "1.234,56" → 123456; "1,234" e "-1" recusados; zero aceito; valores > 2^53 exatos; virada do dia pela zona de São Paulo |
| 33 | Domínio de períodos: mês-calendário, ciclo personalizado, dias 29–31, bissexto, período que contém uma data, sequência para frente e para trás | 32 | — | Exemplos da RN037; sem lacuna/sobreposição em 36 meses nos dois sentidos; fim igual ao calculado pela RPC (Supabase local) |
| 35 | Dependências na fila: operação que referencia categoria, subcategoria ou período espera a operação de criação deles | — | — | Categoria em falha/conflito segura o lançamento sem recusa; testes das Entregas 21, 26 e 27B continuam passando |
| 34A | Primeiro acesso: modalidade e dia inicial; período vigente e faltantes até hoje ao abrir; sem pergunta se o download trouxe configuração | 33, 35 | — | Conta nova pergunta uma vez; conta já configurada não pergunta; offline no celular; Web via RPC |
| 34B | Períodos anteriores e futuros sob demanda, com confirmação ("Criar os períodos de julho a outubro?") | 34A | Nova migration (criação para trás, mesma configuração) | Sem lacuna/sobreposição; concorrência serializada; suíte PostgreSQL e Supabase local; confirmação evita criação acidental em massa |
| 36 | Categorias em Mais: listar por tipo (ativas/inativas), criar, renomear, desativar; sugestões do primeiro acesso (D13); versões local e remota | 34A, 35 | — | Tipo imutável; inativa fora de novos lançamentos; offline e sincronizada; isolada por usuário |
| 37 | Subcategorias opcionais | 36 | — | Exige categoria ativa; validações iguais às da RPC |
| 22 | Itens que precisam de atenção: conflitos (manter aparelho / servidor / editar) e recusas (motivo; descartar só por decisão do usuário); também na Web (D11) | 36 | — | Resolução gera nova versão e auditoria; criação e período só aceitam servidor; nada descartado em silêncio |
| 38 | Cálculo da sobra no domínio e consulta de totais por período | 33 | — | Recebida entra; cancelado sai; despesa pendente entra; pagar não altera; variável sem valor não entra; mudar data move o valor; recálculo ≤ 300 ms (RN043) |
| 39 | Receita avulsa: cadastrar, editar, cancelar; lista por período em Lançamentos | 34B, 36, 38 | — | Período pela data de recebimento (passada ou futura); editar data move o período; registro + auditoria + fila na mesma transação; salvar ≤ 500 ms |
| 40 | Despesa avulsa: cadastrar (vencimento opcional, "já paga" — D10), editar, pagar, cancelar | 39 | — | Nasce pendente; pagar registra data sem alterar a sobra; vencimento não muda período; pendente fica no período original |
| 41 | Sobra no Dashboard (D9), navegação anterior/próximo e filtros período/tipo (D12) | 38–40 | — | Só a sobra, nenhum "saldo"; editar período antigo recalcula aquele período |
| 42 | Fechamento: equivalência local × servidor no Supabase local, regressão no emulador e no Chrome, documentos | todas | — | Critérios de conclusão abaixo |

**Ordem:** 32 → 33 → 35 → 34A → 34B → 36 → 37 → 22 → 38 → 39 → 40 → 41 → 42.

## Matriz de testes
| Entrega | Unidade | Widget | Supabase local | PostgreSQL | Emulador | Chrome |
|---|---|---|---|---|---|---|
| 32, 33 | ✓ | — | ✓ (33) | — | — | — |
| 35 | ✓ | — | ✓ | — | — | — |
| 34A | ✓ | ✓ | ✓ | — | ✓ (modo avião) | ✓ |
| 34B | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 36, 37 | ✓ | ✓ | ✓ (2 usuários) | — | ✓ | ✓ |
| 22 | ✓ | ✓ | ✓ | — | ✓ | ✓ |
| 38 | ✓ (+ desempenho) | — | — | — | — | — |
| 39, 40 | ✓ | ✓ | ✓ | — | ✓ (modo avião) | ✓ |
| 41 | ✓ | ✓ | — | — | ✓ | ✓ |
| 42 | todos | todos | ✓ | ✓ | ✓ | ✓ |

## Riscos
- Validação local diferente da RPC → lançamento "salvo" e depois recusado. Mitigação: replicar validações e testar paridade.
- Dupla contagem ao mudar data ou pagar. Mitigação: sobra sempre derivada dos registros.
- Dois aparelhos configurando o primeiro período offline → conflito de período (só aceita servidor). Mitigação: baixar antes de perguntar (34A).
- Alteração da fila (35) pode afetar o envio validado na Fase 3. Mitigação: reexecutar testes 21, 26 e 27B.
- Datas futuras ou muito antigas podem gerar muitos períodos. Mitigação: confirmação (34B).

## Critérios de conclusão da Fase 4
1. Primeiro acesso cria o período certo (29–31, bissexto), sem lacunas; períodos anteriores e futuros sob demanda com confirmação.
2. Categorias e subcategorias: criar, renomear, desativar no celular (offline) e na Web, isoladas por usuário; sugestões do primeiro acesso.
3. Receitas e despesas avulsas: cadastrar, editar, pagar, cancelar, com auditoria e fila em cada ação.
4. Sobra correta em todos os casos da 38; totais iguais entre local e servidor no Supabase local.
5. Pagar nunca altera a sobra; cancelar sempre remove; mudar data move para o período correto.
6. Nenhuma recusa por ordem de envio; conflitos resolvidos pela tela da 22 (celular e Web).
7. Metas RN043 medidas para salvar, listar e recalcular.
8. `flutter analyze` limpo, suíte completa passando, regressão no emulador e no Chrome, documentos atualizados.

## Situação da implementação (11/11/2026)

Entregas 32, 33, 35, 34A, 34B, 36, 37, 22, 38, 39, 40, 41 e 42 implementadas na ordem do plano; **nenhuma validada pelo responsável ainda**.

| # | Resultado | Testes executados |
|---|---|---|
| 32 | `core/domain`: parser/formatador BRL em `BigInt` (recusa `1,234`, `-1`, vazio; zero aceito; limite de 64 bits), data civil e relógio `America/Sao_Paulo` (pacote `timezone`) | unidade |
| 33 | `PeriodCalendar`: período que contém a data, seguinte, anterior e transição de configuração | unidade (36 meses nos dois sentidos, dias 1/15/20/28–31, bissexto) + paridade com a RPC no Supabase local |
| 35 | Fila com `depends_on`: dependente espera a criação ainda na fila, sem recusa | unidade; testes das Entregas 21, 26 e 27B continuam passando |
| 34A | Escolha do período no primeiro acesso; períodos faltantes até hoje ao abrir; conta já configurada (baixada do servidor) não pergunta | unidade, widget, Supabase local |
| 34B | Migration `20261111000200` (`create_earlier_accounting_period`) + pergunta de confirmação ("Criar os 3 períodos de agosto de 2026 a outubro de 2026?"); limite de 240 períodos por confirmação | PostgreSQL (suíte completa), unidade, widget, paridade no Supabase local |
| 36, 37 | Mais > Categorias: criar, renomear, desativar categorias e subcategorias; sugestões do primeiro acesso | unidade, widget |
| 22 | Mais > Itens que precisam de atenção (e faixa no topo): manter a minha, manter a do servidor, editar; recusas com motivo, tentar de novo e descartar (com confirmação) | unidade, widget |
| 38 | `computePeriodTotals` e consulta por período (local e Web); 5.000 lançamentos somados em menos de 300 ms | unidade |
| 39, 40 | Receita e despesa avulsas: cadastrar, editar, pagar, cancelar, "já paga"; lista por período com filtro Todos/Receitas/Despesas | unidade, widget, Supabase local (celular e Web) |
| 41 | Dashboard com só a sobra e navegação entre períodos | widget |
| 42 | Fluxo completo no Supabase local: celular offline → sincronização → totais iguais no servidor e em aparelho novo; Web contra o servidor; isolamento entre dois usuários; download em várias páginas | integração |

**Suítes executadas em 11/11/2026:** `flutter analyze` (sem alertas); `flutter test` (241 passaram, 12 ignorados por serem de integração/plataforma); integração no Supabase local (todas passaram); suíte PostgreSQL (passou); `flutter build web` (compilou).

**Não executado:** regressão manual no emulador Android (modo avião) e no Chrome; `flutter test --platform chrome` não carrega testes neste ambiente (falha também nos testes da Fase 3).

### Decisões tomadas na implementação (confirmar na validação)
- Nome de categoria/subcategoria: obrigatório, até 60 caracteres, duplicados permitidos (o servidor só exige nome).
- Lançamento cancelado não pode mais ser editado, pago ou cancelado (coerente com D7); o servidor permitiria.
- Descrição de lançamento: até 120 caracteres.
- Sugestões de categorias aparecem uma vez, logo depois da escolha do período; depois disso, só criando categorias em Mais.
- Período criado para trás herda a configuração do primeiro e não altera a data de início dela.
- Conflito de criação (ex.: mesmo período criado em dois aparelhos) só aceita "manter a do servidor"; o registro local é substituído e os lançamentos passam a apontar para o do servidor.
- Descartar uma recusa de criação apaga o registro local e as demais operações dele; descartar uma recusa de edição restaura o registro a partir do servidor no próximo download.
- Editar a versão final de um conflito: nome (categorias) ou valor e descrição (lançamentos).
- Datas exibidas em dd/MM/aaaa e interface em português (localização `pt-BR` adicionada).

### Roteiro sugerido de validação
1. Conta nova: escolher período (testar ciclo dia 31) → aceitar as sugestões de categorias.
2. Criar receita e despesa; conferir a sobra no Dashboard; pagar a despesa (sobra não muda); cancelar (sobra muda).
3. Lançar com data de meses atrás: confirmar a criação dos períodos; editar a data e ver o valor mudar de período.
4. Modo avião: criar categoria + lançamento; reconectar e conferir na Web.
5. Editar a mesma categoria no celular (offline) e na Web; reconectar e resolver em "Itens que precisam de atenção".

## Registrado fora do escopo
- `estado_atual.md`/`entregas_fase3.md` datam a aprovação da 27A em 11/11/2026, posterior à data atual.
- ~~`arquitetura.md` §17.1 prevê `features/entries/`; o código usa `features/transactions/`~~ — alinhado na Entrega 39 (tela em `transactions/`, regras em `entries/`; §17.1 atualizada).
