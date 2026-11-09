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
$porquinhoFirstSession = $null
$porquinhoSecondSession = $null

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

    Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'porquinho_test', '-f', (Join-Path $porquinhoProjectRoot 'supabase/tests/period_concurrency_setup.sql'))) 'prepare concurrent period fixture'

    $porquinhoFirstOutput = Join-Path $porquinhoDataDir 'period-session-first.out'
    $porquinhoFirstError = Join-Path $porquinhoDataDir 'period-session-first.err'
    $porquinhoSecondOutput = Join-Path $porquinhoDataDir 'period-session-second.out'
    $porquinhoSecondError = Join-Path $porquinhoDataDir 'period-session-second.err'
    $porquinhoFirstSql = Join-Path $porquinhoProjectRoot 'supabase/tests/period_concurrency_first_session.sql'
    $porquinhoSecondSql = Join-Path $porquinhoProjectRoot 'supabase/tests/period_concurrency_second_session.sql'

    $porquinhoFirstSession = Start-Process -FilePath $porquinhoPsql `
        -ArgumentList ($porquinhoConnection + @('-d', 'porquinho_test', '-f', $porquinhoFirstSql)) `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $porquinhoFirstOutput `
        -RedirectStandardError $porquinhoFirstError

    $porquinhoReadyDeadline = [DateTime]::UtcNow.AddSeconds(10)
    $porquinhoFirstReady = $false
    while ([DateTime]::UtcNow -lt $porquinhoReadyDeadline) {
        $porquinhoFirstSession.Refresh()
        if (Test-Path -LiteralPath $porquinhoFirstOutput) {
            $porquinhoFirstText = Get-Content -Raw -LiteralPath $porquinhoFirstOutput
            if ($null -ne $porquinhoFirstText -and $porquinhoFirstText.Contains('FIRST_PERIOD_CREATED_LOCK_HELD')) {
                $porquinhoFirstReady = $true
                break
            }
        }
        if ($porquinhoFirstSession.HasExited) {
            $porquinhoFirstDetails = if (Test-Path -LiteralPath $porquinhoFirstError) { [System.IO.File]::ReadAllText($porquinhoFirstError) } else { '' }
            throw "First concurrent period session exited early: $porquinhoFirstDetails"
        }
        Start-Sleep -Milliseconds 50
    }
    if (-not $porquinhoFirstReady) {
        throw 'First concurrent period session did not reach its transaction hold point.'
    }

    $porquinhoSecondSession = Start-Process -FilePath $porquinhoPsql `
        -ArgumentList ($porquinhoConnection + @('-d', 'porquinho_test', '-f', $porquinhoSecondSql)) `
        -WindowStyle Hidden `
        -PassThru `
        -RedirectStandardOutput $porquinhoSecondOutput `
        -RedirectStandardError $porquinhoSecondError

    $porquinhoLockWaitQuery = "SELECT pg_catalog.count(*) FROM pg_catalog.pg_stat_activity WHERE application_name = 'porquinho-period-concurrency-second' AND wait_event_type = 'Lock' AND wait_event = 'advisory';"
    $porquinhoLockWaitDeadline = [DateTime]::UtcNow.AddSeconds(10)
    $porquinhoLockWaitObserved = $false
    while ([DateTime]::UtcNow -lt $porquinhoLockWaitDeadline) {
        $porquinhoLockWaitOutput = & $porquinhoPsql @($porquinhoConnection + @('-d', 'porquinho_test', '-Atq', '-c', $porquinhoLockWaitQuery))
        if ($LASTEXITCODE -ne 0) {
            throw 'Could not inspect the waiting concurrent PostgreSQL session.'
        }
        if (($porquinhoLockWaitOutput | Select-Object -Last 1) -eq '1') {
            $porquinhoLockWaitObserved = $true
            break
        }
        $porquinhoSecondSession.Refresh()
        if ($porquinhoSecondSession.HasExited) {
            $porquinhoSecondDetails = if (Test-Path -LiteralPath $porquinhoSecondError) { [System.IO.File]::ReadAllText($porquinhoSecondError) } else { '' }
            throw "Second concurrent period session exited before waiting on the advisory lock: $porquinhoSecondDetails"
        }
        Start-Sleep -Milliseconds 50
    }
    if (-not $porquinhoLockWaitObserved) {
        throw 'Second session did not wait on the per-owner transaction advisory lock.'
    }

    $porquinhoFirstSession.WaitForExit()
    $porquinhoSecondSession.WaitForExit()
    $porquinhoFirstSession.Refresh()
    $porquinhoSecondSession.Refresh()
    $porquinhoFirstDetails = if (Test-Path -LiteralPath $porquinhoFirstError) { [System.IO.File]::ReadAllText($porquinhoFirstError) } else { '' }
    $porquinhoSecondDetails = if (Test-Path -LiteralPath $porquinhoSecondError) { [System.IO.File]::ReadAllText($porquinhoSecondError) } else { '' }
    if (-not [string]::IsNullOrWhiteSpace($porquinhoFirstDetails) -or -not [string]::IsNullOrWhiteSpace($porquinhoSecondDetails)) {
        $porquinhoFirstText = Get-Content -Raw -LiteralPath $porquinhoFirstOutput
        $porquinhoSecondText = Get-Content -Raw -LiteralPath $porquinhoSecondOutput
        throw "Concurrent period sessions reported an error. First stderr: $porquinhoFirstDetails First output: $porquinhoFirstText Second stderr: $porquinhoSecondDetails Second output: $porquinhoSecondText"
    }

    Invoke-PostgresCommand $porquinhoPsql ($porquinhoConnection + @('-d', 'porquinho_test', '-f', (Join-Path $porquinhoProjectRoot 'supabase/tests/period_concurrency_assert.sql'))) 'assert concurrent period serialization'

    Write-Output 'PASS: isolated PostgreSQL migration and schema checks.'
}
finally {
    foreach ($porquinhoSession in @($porquinhoFirstSession, $porquinhoSecondSession)) {
        if ($null -ne $porquinhoSession) {
            $porquinhoSession.Refresh()
            if (-not $porquinhoSession.HasExited) {
                $porquinhoSession.Kill()
                $porquinhoSession.WaitForExit()
            }
        }
    }

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
