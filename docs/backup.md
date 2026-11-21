# Backup e restauração — Norte (Entrega 77, D8)

Backup diário do Supabase de produção em repositório **privado** do GitHub, cifrado, guardado 30 dias. Arquivos no app: `tooling/backup/` (`backup.yml`, `restaurar_backup.ps1`, `reaplicar_exclusoes.sql`).

## O que é guardado
Dump (`pg_dump`, formato custom) dos esquemas `public` (todos os dados do app, inclusive `deleted_accounts`), `auth` (usuários) e `supabase_migrations`. Cifrado com AES-256 (gpg, frase simétrica). Fica como artefato do GitHub Actions por 30 dias; o arquivo aberto é apagado no mesmo passo. O fluxo falha (e o GitHub avisa por e-mail) se o dump vier sem despesas, usuários ou `deleted_accounts`.

## Montagem (responsável; o agente nunca faz push)
1. Criar um repositório **privado** só para backup (ex.: `norte-backup`).
2. Copiar `tooling/backup/backup.yml` para `.github/workflows/backup.yml` dele.
3. Em Settings → Secrets and variables → Actions, criar:
   - `BACKUP_DATABASE_URL`: string de conexão **Session pooler** do projeto de produção (Supabase → Connect). A conexão direta é só IPv6 e o GitHub não a alcança.
   - `BACKUP_PASSPHRASE`: frase longa e aleatória. **Guardar uma cópia fora do GitHub** (gerenciador de senhas): sem ela o backup não abre.
4. Actions → backup-diario → Run workflow, para a primeira rodada manual; conferir o artefato.
5. Ativar e-mail de falha de workflow nas notificações do GitHub.

## Restaurar
Perda do banco de produção, em um projeto Supabase novo:
1. Aplicar todas as migrations de `supabase/migrations/` no projeto novo (esquema vazio).
2. Baixar o artefato mais recente e conferir o `.sha256`.
3. **Antes de restaurar**, se o banco antigo ainda responder, exportar `select owner_id from public.deleted_accounts` (ids excluídos depois do backup). Se não responder, as exclusões feitas desde o backup precisam ser refeitas a partir dos pedidos dos usuários.
4. Decifrar (`gpg --decrypt`) e restaurar os dados (`pg_restore --data-only --disable-triggers`, esquemas `public` e `auth`).
5. Inserir em `public.deleted_accounts` os ids do passo 3 e rodar `tooling/backup/reaplicar_exclusoes.sql`: apaga de novo, pela `delete_my_account`, quem foi excluído depois do backup. Idempotente.
6. Conferir contagens (usuários, despesas, receitas) e testar um login. Celulares com dados mais novos reenviam o que falta pela sincronização normal.

**Ensaio (sem tocar nos dados de desenvolvimento):** `powershell -File tooling/backup/restaurar_backup.ps1 -Arquivo <arquivo>.gpg [-ExclusoesExtras ids.txt]` restaura num banco descartável do Supabase local e reaplica as exclusões.

## Verificação
Mensal e antes de cada versão publicada: baixar o backup mais recente e rodar o ensaio acima; contagens iguais às de produção (a menos do que mudou desde o backup).

## Privacidade
Os dados dos usuários ficam, cifrados, no GitHub por até 30 dias. A política de privacidade (D12, Entrega 80) deve informar isso. Quem excluir a conta some dos backups novos na hora e dos antigos em até 30 dias (e a restauração reaplica a exclusão).
