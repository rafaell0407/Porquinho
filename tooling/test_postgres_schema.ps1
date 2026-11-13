$ErrorActionPreference = 'Stop'

function Invoke-PostgresCommand {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Step
    )

    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "PostgreSQL step failed: $Step (exit $LASTEXITCODE)."
    }
}

$porquinhoPgBin = Split-Path -Parent (Get-Command initdb.exe -ErrorAction Stop).Source
$porquinhoProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$porquinhoTempRoot = [System.IO.Path]::GetTempPath()
$porquinhoDataDir = Join-Path $porquinhoTempRoot ("porquinho-pgtest-" + [guid]::NewGuid().ToString('N'))
$porquinhoPortProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$porquinhoServerStarted = $false

try {
    $porquinhoPortProbe.Start()
    $porquinhoPort = $porquinhoPortProbe.LocalEndpoint.Port
    $porquinhoPortProbe.Stop()

    $null = New-Item -ItemType Directory -Path $porquinhoDataDir
    Invoke-PostgresCommand (Join-Path $porquinhoPgBin 'initdb.exe') @(
        '-D', $porquinhoDataDir,
        '--no-locale',
        '-E', 'UTF8',
        '--auth-local=trust',
        '--auth-host=trust',
        '--username=postgres',
        '--no-sync'
    ) 'initialize temporary cluster'

    Invoke-PostgresCommand (Join-Path $porquinhoPgBin 'pg_ctl.exe') @(
        '-D', $porquinhoDataDir,
        '-l', (Join-Path $porquinhoDataDir 'server.log'),
        '-o', "-h 127.0.0.1 -p $porquinhoPort",
        '-w', 'start'
    ) 'start temporary PostgreSQL server'
    $porquinhoServerStarted = $true

    $porquinhoPsql = Join-Path $porquinhoPgBin 'psql.exe'
    $porquinhoConnection = @('-h', '127.0.0.1', '-p', "$porquinhoPort", '-U', 'postgres', '-v', 'ON_ERROR_STOP=1')
    Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'postgres', '-c', 'CREATE DATABASE porquinho_test;')) 'create test database'
    Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'porquinho_test', '-f', (Join-Path $porquinhoProjectRoot 'supabase/tests/bootstrap_local.sql'))) 'prepare local Supabase Auth stand-in'

    $porquinhoMigrations = Get-ChildItem -LiteralPath (Join-Path $porquinhoProjectRoot 'supabase/migrations') -Filter '*.sql' -File | Sort-Object Name
    if ($porquinhoMigrations.Count -eq 0) {
        throw 'No PostgreSQL migrations were found.'
    }
    foreach ($porquinhoMigration in $porquinhoMigrations) {
        Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'porquinho_test', '-f', $porquinhoMigration.FullName)) "apply $($porquinhoMigration.Name)"
    }

    $porquinhoTests = Get-ChildItem -LiteralPath (Join-Path $porquinhoProjectRoot 'supabase/tests') -Filter '*_test.sql' -File | Sort-Object Name
    if ($porquinhoTests.Count -eq 0) {
        throw 'No PostgreSQL acceptance tests were found.'
    }
    foreach ($porquinhoTest in $porquinhoTests) {
        Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'porquinho_test', '-f', $porquinhoTest.FullName)) "run $($porquinhoTest.Name)"
    }

    Write-Output 'PASS: isolated PostgreSQL migration and schema checks.'
}
finally {
    if ($porquinhoPortProbe.Server.IsBound) {
        $porquinhoPortProbe.Stop()
    }

    if ($porquinhoServerStarted) {
        & (Join-Path $porquinhoPgBin 'pg_ctl.exe') -D $porquinhoDataDir -m fast -w stop
        if ($LASTEXITCODE -ne 0) {
            Write-Warning 'Temporary PostgreSQL server did not stop cleanly.'
        }
    }

    $porquinhoTempRootResolved = [System.IO.Path]::GetFullPath($porquinhoTempRoot)
    $porquinhoDataDirResolved = [System.IO.Path]::GetFullPath($porquinhoDataDir)
    $porquinhoTempPrefix = $porquinhoTempRootResolved.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    $porquinhoDataDirName = [System.IO.Path]::GetFileName($porquinhoDataDirResolved)
    if (-not $porquinhoDataDirResolved.StartsWith($porquinhoTempPrefix, [System.StringComparison]::OrdinalIgnoreCase) -or $porquinhoDataDirName -notmatch '^porquinho-pgtest-[0-9a-f]{32}$') {
        throw 'Refusing to remove a path outside this script temporary directory.'
    }
    if (Test-Path -LiteralPath $porquinhoDataDirResolved) {
        Remove-Item -LiteralPath $porquinhoDataDirResolved -Recurse -Force
    }
}
