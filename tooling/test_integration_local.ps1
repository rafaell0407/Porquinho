# Roda os testes de integração com o Supabase LOCAL (nunca o gerenciado).
# Uso: powershell -File tooling/test_integration_local.ps1 [arquivos de teste...]
# Sem argumentos, roda todos de test/integration. Chaves vêm de `supabase status`.
param([string[]]$Tests = @('test/integration'))
$ErrorActionPreference = 'Continue'
$status = supabase status -o json 2>$null | ConvertFrom-Json
if (-not $status.PUBLISHABLE_KEY) { throw 'Supabase local parado: rode `supabase start`.' }
flutter test @Tests `
  "--dart-define=SUPABASE_URL=$($status.API_URL)" `
  "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($status.PUBLISHABLE_KEY)" `
  "--dart-define=SUPABASE_SECRET_KEY=$($status.SECRET_KEY)"
exit $LASTEXITCODE
