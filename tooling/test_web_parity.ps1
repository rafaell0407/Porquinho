$ErrorActionPreference = 'Stop'

# T8: paridade de BRL e datas na Web × PostgreSQL, rodando NO NAVEGADOR contra
# o Supabase LOCAL (nunca o gerenciado).
#
# O Supabase recusa a chave secreta vinda do navegador, então a conta de teste
# é criada aqui (fora do navegador, como nos testes de integração) e o teste
# recebe só e-mail, senha e a chave publicável. Nada fica no repositório.
#
# Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tooling/test_web_parity.ps1

$porquinhoProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# `supabase status` avisa serviços parados na saída de erro; não é falha.
$ErrorActionPreference = 'Continue'
$status = supabase status -o json 2>$null | ConvertFrom-Json
$ErrorActionPreference = 'Stop'
if (-not $status.PUBLISHABLE_KEY) { throw 'Supabase local parado: rode `supabase start`.' }
if ($status.API_URL -notmatch '^http://(127\.0\.0\.1|localhost)[:/]') {
    throw "Recusado: $($status.API_URL) não é o Supabase local."
}

$porquinhoEmail = "web-parity-$([guid]::NewGuid().ToString('N').Substring(0, 12))@teste.local"
$porquinhoPassword = "Senha-$([guid]::NewGuid().ToString('N').Substring(0, 12))"
$porquinhoHeaders = @{
    apikey        = $status.SECRET_KEY
    Authorization = "Bearer $($status.SECRET_KEY)"
}
$porquinhoBody = @{ email = $porquinhoEmail; password = $porquinhoPassword; email_confirm = $true } |
    ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "$($status.API_URL)/auth/v1/admin/users" `
    -Headers $porquinhoHeaders -ContentType 'application/json' -Body $porquinhoBody | Out-Null
Write-Host "Conta de teste local: $porquinhoEmail"

Push-Location $porquinhoProjectRoot
try {
    & flutter test --platform chrome test/integration_web/web_money_parity_test.dart `
        "--dart-define=SUPABASE_URL=$($status.API_URL)" `
        "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($status.PUBLISHABLE_KEY)" `
        "--dart-define=WEB_TEST_EMAIL=$porquinhoEmail" `
        "--dart-define=WEB_TEST_PASSWORD=$porquinhoPassword"
    if ($LASTEXITCODE -ne 0) { throw "Teste de paridade Web falhou (exit $LASTEXITCODE)." }
} finally {
    Pop-Location
}
