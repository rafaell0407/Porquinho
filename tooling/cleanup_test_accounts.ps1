# Apaga as contas criadas pelos testes de integração (e-mails it-N, f4-N e
# f5-N @teste.local) e todos os dados delas, pela mesma exclusão de conta do
# app (RPC delete_my_account). Só homologação ou Supabase local; nunca produção.
# Uso:
#   powershell -File tooling/cleanup_test_accounts.ps1          (homologação; pede a chave secreta)
#   powershell -File tooling/cleanup_test_accounts.ps1 -Local   (Supabase local)
# Também é chamado no fim de test_integration_homolog.ps1, com a mesma chave.
param(
  [string]$Url = 'https://fxjkulkyzpwgaeeiwbbl.supabase.co',
  [string]$PublishableKey = 'sb_publishable_gQyYjKwyJmRPCedf-LGjxA_1svDZC1X',
  [string]$Secret = '',
  [switch]$Local
)
$ErrorActionPreference = 'Stop'

if ($Local) {
  # O aviso de serviços parados vai para a saída de erro: não é falha.
  $ErrorActionPreference = 'Continue'
  $status = supabase status -o json 2>$null | ConvertFrom-Json
  $ErrorActionPreference = 'Stop'
  if (-not $status.PUBLISHABLE_KEY) { throw 'Supabase local parado: rode `supabase start`.' }
  $Url = $status.API_URL
  $PublishableKey = $status.PUBLISHABLE_KEY
  $Secret = $status.SECRET_KEY
}
# Proteção: só o Supabase local ou o projeto de homologação.
if ($Url -notmatch '^http://(127\.0\.0\.1|localhost):54321$' -and $Url -ne 'https://fxjkulkyzpwgaeeiwbbl.supabase.co') {
  throw "Endereço não permitido para limpeza: $Url (só local ou norte-homologacao)."
}
if (-not $Secret) {
  $secure = Read-Host 'Chave SECRETA da homologação (sb_secret_...)' -AsSecureString
  $Secret = [System.Net.NetworkCredential]::new('', $secure).Password
}
if (-not $Secret.StartsWith('sb_secret_')) { throw 'Chave secreta inválida (deve começar com sb_secret_).' }

$testEmail = '^(it|f4|f5)-\d+@teste\.local$'
$testPassword = 'Senha-123456'
$admin = @{ apikey = $Secret; Authorization = "Bearer $Secret" }
# O PowerShell 5.1 se apresenta como navegador ("Mozilla/5.0 ..."), e o Supabase
# hospedado recusa chave secreta vinda de navegador. Nome genérico de cliente.
$agent = 'norte-tooling'

function Get-ErrorText($err) {
  if ($err.ErrorDetails -and $err.ErrorDetails.Message) { return $err.ErrorDetails.Message }
  return $err.Exception.Message
}

# 1. Lista todos os usuários e separa os de teste.
$targets = @()
$page = 1
while ($true) {
  $resp = Invoke-RestMethod -Method Get -Headers $admin -UserAgent $agent `
    -Uri "$Url/auth/v1/admin/users?page=$page&per_page=1000"
  $users = @($resp.users)
  if ($users.Count -eq 0) { break }
  $targets += $users | Where-Object { $_.email -match $testEmail }
  if ($users.Count -lt 1000) { break }
  $page++
}
Write-Host "Contas de teste encontradas: $($targets.Count)"

# 2. Cada conta entra com a senha dos testes e se exclui (apaga todos os dados).
# O Supabase hospedado limita logins seguidos (429): espera e tenta de novo.
function Invoke-WithRateLimit([scriptblock]$call) {
  for ($attempt = 1; ; $attempt++) {
    try {
      return & $call
    } catch {
      $limited = (Get-ErrorText $_) -match 'over_request_rate_limit|"code":429'
      if (-not $limited -or $attempt -ge 10) { throw }
      Write-Host "  limite de logins do servidor; aguardando 60 s (tentativa $attempt)..."
      Start-Sleep -Seconds 60
    }
  }
}

$ok = 0
$failed = @()
$i = 0
foreach ($user in $targets) {
  $i++
  try {
    $login = Invoke-WithRateLimit {
      Invoke-RestMethod -Method Post -ContentType 'application/json' -UserAgent $agent `
        -Headers @{ apikey = $PublishableKey } `
        -Uri "$Url/auth/v1/token?grant_type=password" `
        -Body (@{ email = $user.email; password = $testPassword } | ConvertTo-Json)
    }
    $null = Invoke-WithRateLimit {
      Invoke-RestMethod -Method Post -ContentType 'application/json' -UserAgent $agent `
        -Headers @{ apikey = $PublishableKey; Authorization = "Bearer $($login.access_token)" } `
        -Uri "$Url/rest/v1/rpc/delete_my_account" `
        -Body '{"p_confirmation":"DELETE_MY_ACCOUNT"}'
    }
    $ok++
  } catch {
    $failed += "$($user.email): $(Get-ErrorText $_)"
  }
  if ($i % 25 -eq 0) { Write-Host "  $i de $($targets.Count)..." }
}

Write-Host "Apagadas: $ok. Falharam: $($failed.Count)."
foreach ($line in $failed) { Write-Host "  $line" }
if ($failed.Count -gt 0) {
  Write-Host 'As que falharam podem ser apagadas pelo SQL Editor com tooling/cleanup_test_accounts.sql.'
  exit 1
}
exit 0
