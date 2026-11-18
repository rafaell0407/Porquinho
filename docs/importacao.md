# Importação de dados (CSV) — especificação

**Status:** RF030 e RN046–RN055 APROVADOS pelo responsável em 18/11/2026, com as decisões D16–D31 (§18). Plano IM0–IM10 aceito (§17). **IM0 (esta documentação) feita em 18/11/2026; desenvolvimento PENDENTE de autorização** e, pela D31, só depois de validar Relatórios (RL), Gestão de Faturas (F6–F9) e Períodos (P8). Acompanhamento: `pendencias.md` §IM.

## 1. Para que serve
Trazer para o Norte o histórico de lançamentos que o usuário tem em outro lugar (planilha própria, extrato, outro app ou uma exportação do próprio Norte), com revisão antes de gravar e possibilidade de desfazer o que não foi mexido depois.

## 2. Escopo e limites
- Só na Web, só CSV. Fica em **Mais → Importar dados (CSV)**; não é ferramenta do catálogo. No celular aparece a mesma orientação da Exportação.
- **Um único arquivo CSV por importação** (lote = um arquivo). O arquivo pode ser de um tipo só ou misto (coluna de tipo com receitas, despesas, investimentos e categorias).
- Arquivos exportados pelo Norte (4 separados) são importados um por vez; as categorias dos lançamentos são resolvidas pelo nome, então o arquivo de categorias é opcional. O que entrou numa importação aparece como existente na seguinte.
- Importa todo o histórico do arquivo. Nada financeiro é gravado antes da confirmação final; até lá tudo fica no navegador.
- Sem mudança de regra financeira: as linhas viram lançamentos comuns, pelas mesmas RPCs e regras de sempre (RN005, RN008–RN023, RN038, RN045). Nenhuma coluna nova nos lançamentos; Drift e sincronização do celular não mudam.
- Fora: outros formatos (xlsx, OFX), vários arquivos por importação, integração bancária, reativar categoria (M3), desfazer o desfazer.

## 3. Situação atual (diagnóstico de 18/11/2026)
- **Exportação** (`lib/features/export/csv_export.dart`, `export_screen.dart`): 4 arquivos UTF-8 com BOM, vírgula, RFC 4180, `\r\n`. Cabeçalhos:
  - receitas: `id,descricao,valor_centavos,status,data_recebimento,categoria,subcategoria,recorrente,data_prevista,criado_em,atualizado_em`;
  - despesas: `id,descricao,valor_centavos,status,data_competencia,vencimento,data_pagamento,categoria,subcategoria,recorrente,data_prevista,criado_em,atualizado_em`;
  - investimentos: `id,valor_centavos,data,status,recorrente,data_prevista,criado_em,atualizado_em` (status `active/cancelled`);
  - categorias: `id,tipo,nome,ativa,categoria_pai_id,categoria_pai`.
  Categoria sai pelo nome; status com o nome interno; cancelados também saem. Leitura paginada de 1.000 em 1.000 (sem o limite A1).
- **A exportação não é backup completo:** não traz os modelos de recorrência (nem o id da série), ícone e cor das categorias, versão e auditoria. Textos que começam com `= + - @` ganham apóstrofo, que não dá para distinguir na volta.
- **Servidor:** toda gravação por RPC `SECURITY DEFINER` com versão, auditoria e repetição segura (`applied_sync_operations`). Receita avulsa só nasce `received` (pendente exige modelo); despesa nasce `pending` e só fica paga com `pay` + `paid_on`; categoria precisa estar ativa e ser do tipo certo; `amount_centavos >= 0`. Versão desatualizada gera registro em `sync_conflicts` (Itens de atenção).
- **Recorrências:** `create_recurrence_from_entry` / `create_investment_recurrence_from_entry` aceitam lançamento novo (versão 0) ou transformam um avulso existente (versão > 0) na primeira ocorrência, com `starts_on` = data do lançamento e dia de referência = dia dessa data. `generate_due_recurrence_occurrences` percorre todos os modelos ativos do usuário até hoje, sem duplicar.

## 4. Reaproveitamento
`parseBrlToCentavos`, `formatBrl`, `CalendarDate`, `UserClock`, `PeriodCalendar`, `RecurrenceCalendar` (mesma regra do servidor, tabela de 360 casos), `SupabaseExportSource` (leitura paginada para duplicidades), modelo `js_interop` de `file_download_web.dart` para escolher arquivo (sem dependência nova), `crypto` (SHA-256), RPCs de gravação existentes chamadas por dentro das RPCs de importação, ids determinísticos por md5.

## 5. Divergências identificadas e como foram resolvidas
| # | Divergência | Resolução |
|---|---|---|
| V1 | `requisitos.md` §3.2 punha importação fora do MVP | Exceção aprovada (RF030, 18/11/2026) |
| V2 | CSV do Norte não traz o modelo nem o id da série | Séries detectadas e confirmadas como em qualquer arquivo (RN051); melhoria da exportação é a M8 |
| V3 | Receita pendente e despesa variável sem valor não existem avulsas | Só como âncora de série confirmada (D18, RN049) |
| V4 | Lançamento com categoria desativada | Outra, nenhuma ou nova; nunca reativar (D19, RN050) |
| V5 | Dia de referência = dia da âncora | Usa o dia da âncora, com aviso quando difere do dia habitual da série; servidor não muda (D20) |
| V6 | Atrasadas descontam do dinheiro livre ao gerar | Prévia obrigatória com efeito por período (RN052) |
| V7 | Despesa importada pendente com vencimento gera alertas em massa | "Marcar como pagas" explícito; vencimento só se mapeado (D21) |
| V8 | Extratos trazem negativos; RN045 recusa | Recusar; regra explícita opcional por arquivo (D22) |
| V9 | Bancos exportam em Windows-1252 | Opção explícita (D23) |
| V10 | Desfazer pela RPC com versão antiga geraria conflito falso | RPC própria trava e confere a versão antes (RN055) |
| V11 | Geração percorre todos os modelos | Aceito (é o mesmo de abrir o app); resultado mostra só os do lote |
| V12 | RN006: "não detecta duplicidade" | A detecção é aviso restrito à importação (RN053); nota na RN006 |
| V13 | D15 (guarda de histórico) aberta | Cada linha gera auditoria e registro de repetição; considerar na D15 |
| V14 | Fase 8 e validações em curso | Começa depois de RL, GF e P8 (D31) |

## 6. Fluxo de telas
1. **Início:** histórico de importações e "Nova importação". Avisa se há importação interrompida ("Retomar" ou "Desfazer o que entrou").
2. **Arquivo:** escolher **um** arquivo. Lido no navegador; mostra encoding, separador, número de linhas e se é arquivo do Norte. Se o mesmo arquivo (hash) já foi importado e não desfeito, avisa.
3. **Colunas:** associar cabeçalhos a campos; formato do valor (centavos inteiros, reais com vírgula, reais com ponto) e da data (ISO, DD/MM/AAAA, MM/DD/AAAA). Colunas sem uso listadas como ignoradas. Arquivo do Norte vem associado pelo cabeçalho exato; o usuário confirma.
4. **Classificação:** tipo do arquivo inteiro ou associação dos valores da coluna de tipo; associação de status ("Pago" → pago); "marcar despesas como pagas" (D21); regra de negativos, se houver (D22).
5. **Categorias:** para cada nome, por tipo: usar existente (sugestão por nome), criar ou ficar sem. Mesmo esquema para subcategorias.
6. **Recorrências:** séries sugeridas, cada uma com caixa desmarcada; âncora, fixo/variável, prévia das atrasadas (datas, valores, efeito por período, receitas que ficam pendentes) e aviso de dia (D20).
7. **Duplicidades:** grupos (dentro do arquivo, contra o banco, arquivo já importado) com "Importar mesmo assim" ou "Ignorar" por grupo e ações em massa explícitas. Só avança com todos decididos.
8. **Validação e prévia:** rejeitadas com motivo; totais por tipo e por período (dinheiro livre antes e depois); aviso de arquivo grande (D24).
9. **Confirmação:** "Importar N lançamentos, criar X categorias e Y recorrências".
10. **Processamento:** progresso por bloco; se cair, continua sem duplicar; fechar a aba deixa a importação interrompida.
11. **Resultado:** criados, ignorados, rejeitados, cancelados não importados e ocorrências geradas; links para Lançamentos e Recorrências.
12. **Detalhe da importação:** "Desfazer…" com prévia do que será cancelado e do que será preservado, confirmação e resultado.

## 7. Validação (no cliente e repetida no servidor)
- **Leitura:** UTF-8 estrito (BOM removido); Windows-1252 só por escolha explícita quando o UTF-8 falhar; separador `,` ou `;` detectado e trocável; RFC 4180 (aspas, `""`, quebra de linha dentro de campo, CRLF/LF). Linha com número de campos diferente do cabeçalho: rejeitada. Linha vazia: ignorada e contada.
- **Valor:** formato declarado; até 2 casas; negativo rejeitado (salvo regra D22); zero aceito; até 64 bits; "1.234" ambíguo bloqueia até escolha; `valor_centavos` do Norte lido como inteiro; nunca `double`.
- **Data:** formato declarado; coluna inteira que serve como DD/MM e MM/DD bloqueia até escolha; ano com 2 dígitos rejeitado; data inexistente rejeitada; data com hora usa só a data, com aviso, sem conversão de fuso.
- **Receita:** valor e data de recebimento obrigatórios; entra recebida; data passada ou futura.
- **Despesa:** valor e competência obrigatórios; vencimento opcional; paga exige data de pagamento válida; "parcial" ou valor pago diferente do valor: rejeitada; pagamento futuro ou anterior à competência aceito com aviso (D28).
- **Investimento:** só valor e data; demais colunas ignoradas com aviso.
- **Categoria:** tipo igual ao do lançamento; investimento sem categoria; subcategoria exige categoria.
- **Cancelados** (status cancelado no arquivo): não importados, contados no resultado (D17).

## 8. Duplicidades
- **Dentro do arquivo:** linhas iguais em tipo, data de competência, valor, descrição normalizada e categoria; mesmo `id` do Norte repetido.
- **Contra o banco:** mesmo tipo, data de competência e valor; descrição como critério secundário. Arquivo do Norte: mesmo `id` já existente é sinal forte. Leitura paginada, sem o limite de 1.000.
- **Arquivo já importado:** mesmo SHA-256 numa importação não desfeita.
- Nada é ignorado automaticamente; nenhuma opção pré-marcada; ação em massa só por clique explícito. Reenvio técnico não duplica (§12).

## 9. Recorrências
- **Detecção (só sugestão, só no arquivo atual):** agrupa por tipo, descrição normalizada e categoria; pelo menos **3 meses seguidos**, uma ocorrência por mês, dia consistente com **tolerância de até 3 dias** e ajuste de fim de mês/dia útil (D29). Fixo se todos os valores iguais; variável se não. Investimento sempre fixo, com o valor da âncora.
- **Âncora:** o lançamento mais recente da série; os anteriores ficam avulsos. Dia de referência = dia da âncora, com aviso quando difere do dia habitual (D20).
- **Gravação pelo mecanismo existente:**
  - âncora recebida ou paga: cria o avulso (`create`, depois `pay` se pago) e chama `create_recurrence_from_entry` com a versão atual;
  - âncora receita pendente ou despesa variável sem valor (arquivo do Norte): `create_recurrence_from_entry` com versão 0;
  - investimento: `create_investment_recurrence_from_entry`.
- **Atrasadas:** ao fim da importação, uma chamada a `generate_due_recurrence_occurrences`. A prévia usa `RecurrenceCalendar.monthlyUntil(âncora, hoje)` sem o mês da âncora. Receitas geradas ficam pendentes; despesas fixas e investimentos contam ao gerar; variáveis ficam sem valor até o usuário informar. Âncora futura não gera atrasadas.

## 10. Histórico e desfazer condicional
- **Inalterado:** item criado pela importação com versão atual = versão gravada logo após a importação; ocorrência gerada por modelo da importação com versão 1 e status inicial.
- **Ordem:** (1) desativa modelos inalterados (modelo alterado fica, com todas as suas ocorrências — D25); (2) cancela ocorrências geradas inalteradas; (3) cancela lançamentos inalterados, incluindo a âncora; (4) desativa categorias e subcategorias criadas pela importação, inalteradas e sem uso por lançamento ou modelo não cancelado.
- Sem prazo (D25). Nada é apagado. Pagamentos, recebimentos, edições e cancelamentos posteriores são preservados. Cada ação passa pela RPC existente (auditoria normal). Resultado item a item: cancelado, desativado, preservado-alterado, preservado-em-uso. Não pode ser desfeito (M3). Edição no celular durante o desfazer segue o fluxo normal de conflitos.

## 11. Estrutura de dados (uma migration nova)
```
import_batches (owner_id, id, status: processing|completed|interrupted|undone|partially_undone,
  file_name TEXT, file_sha256 TEXT, file_size_bytes BIGINT, file_rows INT,
  plan JSONB (decisões do usuário, sem conteúdo financeiro bruto), plan_hash TEXT,
  total_chunks INT, item_count INT, summary JSONB, undo_summary JSONB, version,
  created_at, completed_at, undone_at)  PK (owner_id, id)
import_batch_chunks (owner_id, batch_id, chunk_index, content_hash, item_count, applied_at)
  PK (owner_id, batch_id, chunk_index)
import_batch_items (owner_id, batch_id, entity_type, entity_id,
  role: created|anchor|template|category|subcategory, version_after_import BIGINT,
  source_row INT, undo_outcome TEXT NULL, undo_reason TEXT NULL)
  PK (owner_id, batch_id, entity_type, entity_id); índice (owner_id, entity_type, entity_id)
```
- RLS de leitura própria; sem DML para clientes. `delete_my_account` inclui as 3 tabelas. Catálogo de segurança cobre as RPCs novas.
- O arquivo não é guardado; ficam nome (D27), hash, tamanho, linhas e decisões, suficientes para retomar com o mesmo arquivo.

## 12. RPCs, transações, idempotência e retomada
| RPC | Função |
|---|---|
| `import_begin_batch(op, batch_id, file, plan, plan_hash, total_chunks, item_count)` | Cria a importação. Uma em processamento por usuário. Recusa hash já importado sem confirmação explícita no plano |
| `import_apply_chunk(op, batch_id, chunk_index, items)` | Uma transação por bloco (até ~250 itens). Chama as RPCs existentes com operação derivada `md5(batch|item|etapa)`; registra itens com a versão final. Item com falha: **bloco inteiro volta**, importação interrompida, linha indicada (divergência sinalizada, nunca corrigida em silêncio). Confere que o id não existe (nunca cai no caminho de conflito) |
| `import_finish_batch(op, batch_id)` | Confere todos os blocos, chama `generate_due_recurrence_occurrences`, monta o resumo (atrasadas só dos modelos da importação), conclui e audita |
| `import_undo_preview(batch_id)` | Só leitura: o que seria cancelado e preservado |
| `import_undo_batch(op, batch_id, limit)` | `FOR UPDATE` + conferência de versão antes de chamar a RPC existente; processa em partes; repetível sem efeito duplicado |

Itens aceitos no bloco: `category`, `subcategory`, `income`, `expense` (com `paid_on` opcional), `investment`, `series` (âncora + modelo).
- Ids de entidade: UUID determinístico de `(batch_id, linha)`; série e modelo de `(batch_id, série)`; operação de `(batch_id, item, etapa)`. Reenvio devolve a resposta guardada; conteúdo diferente com a mesma chave é recusado.
- **Retomar:** escolher de novo o mesmo arquivo; hash e `plan_hash` iguais → continua do primeiro bloco não aplicado; diferentes → só desfazer o que entrou (D26).
- **Limites (D24):** sem limite fixo de linhas; arquivo grande mostra aviso (tempo estimado) antes de confirmar; nunca corta em silêncio. Leitura em partes, cedendo a vez à tela, com progresso.

## 13. Segurança e privacidade
Arquivo lido só no navegador; ao servidor vão itens interpretados e metadados, nada de conteúdo bruto (nem em logs). `auth.uid()`, `search_path` vazio, `EXECUTE` só para `authenticated`; teste A×B (B não lê nem desfaz a importação de A). Textos importados são dados; o escape de fórmula da exportação continua valendo. Nome do arquivo guardado (D27), protegido por RLS e apagado com a conta.

## 14. Pastas e arquivos (previsão)
```
lib/features/import/
  import_texts.dart
  domain/  csv_reader.dart, text_decoding.dart, column_mapping.dart, norte_formats.dart,
           value_parsing.dart, date_parsing.dart, row_classification.dart, import_models.dart,
           row_validation.dart, category_resolution.dart, series_detection.dart,
           backfill_preview.dart, duplicate_detection.dart, import_plan.dart
  data/    import_repository.dart, remote_import_repository.dart, file_picker.dart (+ _web/_stub)
  application/ import_controller.dart, import_runner.dart
  screens/ import_home_screen.dart, import_wizard_screen.dart, import_result_screen.dart,
           import_batch_screen.dart
  widgets/
supabase/migrations/2026MMDD000100_import_batches.sql
supabase/tests/rpc_import_test.sql
test/features/import/... · test/integration/import_*_test.dart
```
Rotas `/importar` e `/importar/<id>`; item novo em Mais. Ao implementar: `mapa_app.md`, `banco_de_dados.md`, `arquitetura.md`.

## 15. Testes
| Camada | Casos |
|---|---|
| Leitura | BOM, `,`/`;`, aspas, `""`, quebra dentro de campo, CRLF/LF, campos a mais/menos, UTF-8 inválido, Windows-1252 explícito, arquivo vazio |
| Valor | três formatos, "1.234" ambíguo, 3 casas, negativo (com e sem regra D22), zero, 64 bits, centavos do Norte exatos |
| Data | ISO, DD/MM, MM/DD, coluna ambígua, 29/02, ano com 2 dígitos, data com hora |
| Regras | status por tipo, cancelados ignorados, pago sem data, "marcar como pagas", investimento com colunas extras, tipo da categoria, apóstrofo do Norte |
| Séries e prévia | detecção (fim de mês, dia útil, lacunas, tolerância 3 dias), âncora, aviso de dia, prévia = `monthly_recurrence_cases.json`, âncora futura, efeito por período |
| Duplicidades | dentro do arquivo, contra o banco, `id` do Norte, hash repetido |
| Plano | ids determinísticos, mesmo plano para as mesmas decisões |
| SQL | começar/aplicar/terminar; reenvio; conteúdo diferente; bloco inválido volta inteiro; categoria desativada; atrasadas uma vez; desfazer inalterado × alterado × em uso; desfazer repetido; isolamento A×B; catálogo de segurança; exclusão de conta |
| Integração (Supabase local) | arquivo grande (ex.: 20 mil linhas, sem corte em 1.000); queda e retomada; celular baixa e não duplica a geração; edição no celular durante o desfazer vira conflito normal; totais Drift = `get_range_report` |
| Tela | cada etapa, bloqueios, prévia, progresso, resultado, desfazer; claro e escuro; celular e Web (T9 ainda bloqueia `--platform chrome`) |

## 16. Critérios de aceitação
- Um arquivo por importação. Nenhuma gravação antes da confirmação; falha no meio não deixa bloco pela metade.
- Centavos do Norte exatos; nenhum valor passa por `double`. Data ou valor ambíguo nunca interpretado sem escolha.
- Receita avulsa recebida; despesa pendente ou paga com data; investimento só valor e data; cancelados não importados.
- Categoria desativada nunca reativada; investimento sem categoria.
- Recorrência só com confirmação; âncora = último da série; atrasadas da prévia = as geradas pelo servidor.
- Duplicidades nunca ignoradas sem decisão; reenvio não duplica.
- Desfazer cancela só o inalterado, informa o preservado, sem conflito falso.
- Totais iguais no celular e no servidor; isolamento por usuário testado.

## 17. Plano de entregas (uma por vez, cada uma para validação)
| ID | Entrega |
|---|---|
| IM0 | Documentação: RF030, RN046–RN055, esta spec, `pendencias.md` §IM — **feita 18/11/2026** |
| IM1 | Domínio: leitura (encoding, separador, RFC 4180) e formatos do Norte |
| IM2 | Domínio: colunas, valores, datas, classificação, regras e linhas rejeitadas |
| IM3 | Domínio: categorias e duplicidades |
| IM4 | Domínio: séries, âncora, prévia das atrasadas e plano (ids e blocos) |
| IM5 | Servidor: migration, `begin/apply_chunk/finish`, testes SQL (só Supabase local) |
| IM6 | Servidor: `undo_preview/undo_batch`, testes SQL |
| IM7 | Dados e aplicação na Web: escolha do arquivo, repositório, blocos, retomada, integração local |
| IM8 | Telas das etapas 1–9 |
| IM9 | Processamento, resultado, histórico e desfazer; item em Mais; conferência no navegador |
| IM10 | Homologação, só com autorização (R2) |

## 18. Decisões (aceitas pelo responsável em 18/11/2026)
| ID | Assunto | Decisão |
|---|---|---|
| D16 | RF030, RN046–RN055 e exceção ao §3.2 | Aprovados |
| — | Quantidade de arquivos | **Um único CSV por importação** (pode ser misto) |
| D17 | Linhas canceladas | Não importadas; contadas no resultado |
| D18 | Receita pendente / despesa variável sem valor | Só como âncora de série confirmada; fora disso, rejeitadas com motivo |
| D19 | Categoria desativada | Outra, nenhuma ou nova com o mesmo nome; nunca reativar |
| D20 | Dia de referência | Dia da âncora, com aviso; sem mudança no servidor |
| D21 | Despesas do histórico | Opção explícita "marcar como pagas" (data = coluna escolhida ou data do lançamento); vencimento só se mapeado |
| D22 | Valores negativos | Recusados; regra explícita opcional por arquivo ("negativos são despesas", valor absoluto) |
| D23 | Windows-1252 | Opção explícita quando o UTF-8 falhar |
| D24 | Limites | Sem limite fixo; aviso de arquivo grande antes de confirmar; nunca corta em silêncio |
| D25 | Desfazer | Sem prazo; modelo alterado preserva todas as suas ocorrências |
| D26 | Bloco que falha | Bloco atômico; importação interrompida com retomar (mesmo arquivo) ou desfazer |
| D27 | Nome do arquivo | Guardado no histórico |
| D28 | Pagamento futuro ou anterior à competência | Aceito com aviso |
| D29 | Detecção de série | 3 meses seguidos, tolerância de 3 dias, ajuste de fim de mês |
| D30 | Exportação fiel (id da série, ícone, cor; arquivo único combinado) | Melhoria separada (M8), só com aprovação |
| D31 | Quando começar | Depois de validar RL, GF e P8 |
