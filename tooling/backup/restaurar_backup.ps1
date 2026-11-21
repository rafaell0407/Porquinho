# Entrega 77: restaura um backup cifrado (norte-AAAAMMDD-HHMM.dump.gpg) num
# banco de DESTINO e reaplica as exclusões de conta. Só trabalha com o Supabase
# local (container Docker supabase_db_*), em um banco novo e descartável por
# padrão, para ensaiar a restauração sem tocar nos dados do desenvolvimento.
# Restaurar em produção segue o roteiro de docs/backup.md (decisão do responsável).
#
# Uso:
#   powershell -File tooling/backup/restaurar_backup.ps1 -Arquivo norte-....dump.gpg
#   (pede a frase do backup; use -ExclusoesExtras ids.txt para ids excluídos depois do backup)
param(
  [Parameter(Mandatory = $true)][string]$Arquivo,
  [string]$Frase = '',
  [string]$ExclusoesExtras = '',
  [string]$BancoDestino = 'restauracao_teste',
  [string]$Container = ''
)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Arquivo)) { throw "Arquivo não encontrado: $Arquivo" }
if ($BancoDestino -eq 'postgres') { throw 'Destino "postgres" é o banco de desenvolvimento: use um banco novo.' }
if (-not $Container) {
  $Container = (docker ps --filter 'name=supabase_db_' --format '{{.Names}}' | Select-Object -First 1)
}
if (-not $Container) { throw 'Container do Supabase local não encontrado: rode `supabase start`.' }

# 1. Decifra (gpg do Git for Windows serve).
$gpg = (Get-Command gpg -ErrorAction SilentlyContinue).Source
if (-not $gpg) { $gpg = 'C:\Program Files\Git\usr\bin\gpg.exe' }
if (-not (Test-Path $gpg)) { throw 'gpg não encontrado.' }
if (-not $Frase) {
  $secure = Read-Host 'Frase do backup' -AsSecureString
  $Frase = [System.Net.NetworkCredential]::new('', $secure).Password
}
$dump = [System.IO.Path]::ChangeExtension((Resolve-Path $Arquivo).Path, $null).TrimEnd('.')
if (Test-Path $dump) { Remove-Item $dump -Force }
# Frase em arquivo temporário sem quebra de linha (o pipe do PowerShell acrescentaria CR/LF).
$fraseArq = [System.IO.Path]::GetTempFileName()
try {
  [System.IO.File]::WriteAllText($fraseArq, $Frase)
  & $gpg --batch --yes --pinentry-mode loopback --passphrase-file $fraseArq --decrypt --output $dump (Resolve-Path $Arquivo).Path
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao decifrar (frase errada ou arquivo corrompido).' }
} finally {
  Remove-Item $fraseArq -Force -ErrorAction SilentlyContinue
}

try {
  # 2. Banco novo + restauração (esquemas public e auth; o dump é de esquema e dados).
  docker cp $dump "${Container}:/tmp/restaura.dump"
  docker exec $Container psql -U supabase_admin -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS $BancoDestino WITH (FORCE)" -c "CREATE DATABASE $BancoDestino"
  # Extensões que o Supabase já traz no banco padrão; o dump as referencia.
  docker exec $Container psql -U supabase_admin -d $BancoDestino -v ON_ERROR_STOP=1 -c 'CREATE SCHEMA IF NOT EXISTS extensions' -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions' -c 'CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\" WITH SCHEMA extensions'
  # Erros de objetos do Supabase (ex.: funções do auth que já existem) são esperados e listados; o que importa é a conferência abaixo.
  $ErrorActionPreference = 'Continue'
  docker exec $Container pg_restore -U supabase_admin -d $BancoDestino --no-owner --no-privileges /tmp/restaura.dump 2>&1 | Select-Object -Last 15
  $ErrorActionPreference = 'Stop'

  # 3. Exclusões feitas depois do backup.
  if ($ExclusoesExtras) {
    foreach ($id in (Get-Content $ExclusoesExtras | Where-Object { $_ -match '^[0-9a-fA-F-]{36}$' })) {
      docker exec $Container psql -U supabase_admin -d $BancoDestino -v ON_ERROR_STOP=1 -c "INSERT INTO public.deleted_accounts (owner_id) VALUES ('$id') ON CONFLICT DO NOTHING"
    }
  }
  Get-Content (Join-Path $PSScriptRoot 'reaplicar_exclusoes.sql') -Raw | docker exec -i $Container psql -U supabase_admin -d $BancoDestino -v ON_ERROR_STOP=1

  # 4. Conferência: contagens.
  docker exec $Container psql -U supabase_admin -d $BancoDestino -c "SELECT (SELECT count(*) FROM auth.users) AS usuarios, (SELECT count(*) FROM public.expense_entries) AS despesas, (SELECT count(*) FROM public.deleted_accounts) AS excluidas"
  Write-Host "Restauração concluída no banco '$BancoDestino' (descartável)."
} finally {
  Remove-Item $dump -Force -ErrorAction SilentlyContinue
  docker exec $Container rm -f /tmp/restaura.dump | Out-Null
}
