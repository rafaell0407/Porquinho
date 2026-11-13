# Estado atual — Norte

**Atualizado em:** 12/11/2026.

## Fase
- Fases 1–7: CONCLUÍDAS e validadas (detalhe em `historico/`).
- **Fase 8** (sincronização completa, qualidade e publicação — `entregas_fase8.md`): EM EXECUÇÃO.
  - Validadas: 69–74 e 75 parcial (falta D1).
  - 76: feita exceto SMTP, aguardando validação (homologação `norte-homologacao`, 19 migrations, 33 testes de integração passando).
  - Restam: 75 final, 77–82 (ver `pendencias.md` §E).
- Plataformas: Android (offline) e Web (somente online). iOS fora do MVP.

## Entrega avulsa (12/11/2026) — aguardando validação
Criar categoria direto no formulário de lançamento ("+ Nova categoria", receita/despesa; não no investimento). Subcategoria no formulário ficou fora (M5, aguarda aprovação).

## Entrega 79 — parcial (12/11/2026), aguardando validação
Feito: tratamento global de erros, sem valores nos registros. O restante (produção, SMTP, monitoramento externo) depende das Entregas 77/78, de domínio e de autorização.

## Próximo passo
Validar a 76; decidir D1/D5; depois Entrega 77 (backup).

## Testar no Android (máquina do responsável)
Emulador `Medium_Phone_API_37.0`, sem flags gráficas; app com `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` e chave publicável local. Login Google exige `adb reverse tcp:54321 tcp:54321`.
