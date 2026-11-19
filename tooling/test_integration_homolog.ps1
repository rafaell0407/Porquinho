# Roda os testes de integração contra o Supabase de HOMOLOGAÇÃO (nunca produção).
# Uso: powershell -File tooling/test_integration_homolog.ps1 [-Tests arquivos...]
# A chave secreta é pedida no terminal (não fica em arquivo, histórico nem chat).
# Os testes criam usuários de teste (e-mails aleatórios) no projeto de homologação;
# ao final eles são apagados (tooling/cleanup_test_accounts.ps1).
param(
  [string[]]$Tests = @('test/integration'),
  [string]$Url = 'https://fxjkulkyzpwgaeeiwbbl.supabase.co',
  [string]$PublishableKey = 'sb_publishable_gQyYjKwyJmRPCedf-LGjxA_1svDZC1X',
  [string[]]$Defines = @(),
  [switch]$KeepTestData
)
$ErrorActionPreference = 'Continue'
if ($Url -match 'localhost|127\.0\.0\.1|10\.0\.2\.2') { throw 'Use test_integration_local.ps1 para o ambiente local.' }
$secure = Read-Host 'Chave SECRETA da homologação (sb_secret_...)' -AsSecureString
$secret = [System.Net.NetworkCredential]::new('', $secure).Password
if (-not $secret.StartsWith('sb_secret_')) { throw 'Chave secreta inválida (deve começar com sb_secret_).' }
flutter test @Tests `
  "--dart-define=SUPABASE_URL=$Url" `
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$PublishableKey" `
  "--dart-define=SUPABASE_SECRET_KEY=$secret" @Defines
$code = $LASTEXITCODE
# Apaga as contas de teste criadas (e de rodadas anteriores) para o banco de
# homologação não crescer a cada rodada (T10). -KeepTestData pula a limpeza.
if (-not $KeepTestData) {
  & "$PSScriptRoot/cleanup_test_accounts.ps1" -Url $Url -PublishableKey $PublishableKey -Secret $secret
}
$secret = $null
exit $code
