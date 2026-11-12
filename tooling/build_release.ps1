# Build de produção/homologação (Entrega 75). Não publica nada em lugar nenhum.
#
# Uso:
#   powershell -File tooling/build_release.ps1 -Environment homologacao -Target aab
#   powershell -File tooling/build_release.ps1 -Environment producao -Target web
#   ... -Check   só valida a configuração, sem compilar
#
# - Lê env/<Environment>.json (modelo: env/<Environment>.example.json; o real é
#   ignorado pelo Git) e repassa com --dart-define-from-file.
# - Recusa chave secreta/service role e endereços locais fora do ambiente local.
# - Para apk/aab exige android/key.properties (assinatura de upload).
# - Versão: opcionalmente -BuildName/-BuildNumber; senão usa pubspec.yaml.
param(
    [Parameter(Mandatory = $true)][ValidateSet('local', 'homologacao', 'producao')][string]$Environment,
    [Parameter(Mandatory = $true)][ValidateSet('apk', 'aab', 'web')][string]$Target,
    [string]$BuildName,
    [int]$BuildNumber = 0,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $root

$envFile = Join-Path $root "env/$Environment.json"
if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Faltou env/$Environment.json. Copie env/$Environment.example.json e preencha."
}
$config = Get-Content -Raw -LiteralPath $envFile | ConvertFrom-Json
foreach ($key in 'SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY') {
    $value = $config.$key
    if ([string]::IsNullOrWhiteSpace($value) -or $value -like 'COLE_AQUI*' -or $value -like '*SEU-PROJETO*') {
        throw "env/$Environment.json: preencha $key."
    }
}
$names = $config.PSObject.Properties.Name
if ($names -match 'SECRET|SERVICE') { throw 'O arquivo de ambiente não pode conter chave secreta ou service role.' }
if ($config.SUPABASE_PUBLISHABLE_KEY -like 'sb_secret_*') { throw 'SUPABASE_PUBLISHABLE_KEY recebeu uma chave secreta.' }
if ($Environment -ne 'local' -and $config.SUPABASE_URL -match '127\.0\.0\.1|localhost|10\.0\.2\.2') {
    throw "Ambiente $Environment não pode apontar para o Supabase local."
}
if ($Environment -ne 'local' -and $config.SUPABASE_URL -notmatch '^https://') {
    throw "Ambiente $Environment exige HTTPS."
}

if ($Target -ne 'web') {
    if (-not (Test-Path -LiteralPath (Join-Path $root 'android/key.properties'))) {
        throw 'Faltou android/key.properties (modelo: android/key.properties.example). Sem ele o pacote sairia com a chave de debug.'
    }
}
if ($Check) { Write-Host "Configuração de $Environment/$Target válida."; exit 0 }

$flutterArgs = @('build', $Target, '--release', "--dart-define-from-file=$envFile")
if ($BuildName) { $flutterArgs += "--build-name=$BuildName" }
if ($BuildNumber -gt 0) { $flutterArgs += "--build-number=$BuildNumber" }
& flutter @flutterArgs
exit $LASTEXITCODE
