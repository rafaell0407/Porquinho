$ErrorActionPreference = 'Stop'

# Suíte de testes no navegador (flutter test --platform chrome).
#
# Na Web o Flutter compila todos os arquivos pedidos num único app, então um
# arquivo só de celular (@TestOn('vm'): Drift nativo, SQLite, dart:io) quebra a
# compilação de todos. Este script passa só os arquivos que valem para a Web:
# fora de test/integration e sem @TestOn('vm').
#
# Pré-requisito (T9): duas correções locais no Flutter 3.47.9 — ver
# docs/arquitetura.md, seção de testes na Web.
#
# Uso: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tooling/test_web.ps1 [arquivos...]

$porquinhoProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $porquinhoProjectRoot
try {
    if ($args.Count -gt 0) {
        $porquinhoFiles = $args
    } else {
        $porquinhoFiles = Get-ChildItem -Path test -Recurse -Filter '*_test.dart' |
            Where-Object { $_.FullName -notmatch '[\\/]test[\\/]integration[\\/]' } |
            Where-Object { -not (Select-String -Path $_.FullName -Pattern "^@TestOn\('vm'\)" -Quiet) } |
            ForEach-Object { Resolve-Path -Relative $_.FullName }
    }
    Write-Host "Testes na Web: $(@($porquinhoFiles).Count) arquivo(s)."
    & flutter test --platform chrome @porquinhoFiles
    if ($LASTEXITCODE -ne 0) {
        throw "flutter test --platform chrome falhou (exit $LASTEXITCODE)."
    }
} finally {
    Pop-Location
}
