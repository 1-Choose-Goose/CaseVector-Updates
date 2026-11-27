param([Parameter(Mandatory = $true)][string]$Tag)
$ErrorActionPreference = 'Stop'
if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid release tag.' }
$source = Join-Path $env:GITHUB_WORKSPACE 'private-source'
$buildLog = Join-Path $env:RUNNER_TEMP 'casevector-build.log'
$errorLog = Join-Path $env:RUNNER_TEMP 'casevector-build-error.log'
Push-Location $source
try {
    & python tools/check_version.py --tag $Tag *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Version check failed.' }
    Write-Host 'Private version metadata checked.'

    $runner = (Get-Command pwsh -ErrorAction Stop).Source
    $process = Start-Process -FilePath $runner `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-File', '.\build_windows.ps1',
                        '-SkipInstaller', '-CreateUpdateArchive') `
        -WorkingDirectory $source -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $buildLog -RedirectStandardError $errorLog
    $minutes = 0
    while (-not $process.WaitForExit(60000)) {
        $minutes++
        Write-Host "Private build still running ($minutes minute(s)); output withheld."
    }
    $process.Refresh()
    if ($process.ExitCode -ne 0) { throw 'Private build or tests failed.' }
    Write-Host 'Private build and tests completed.'

    & python tools/release_notes.py "release/$Tag/release-notes.md" *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Release notes preparation failed.' }
}
catch {
    throw 'Private source build or tests failed. Output is withheld from public logs.'
}
finally {
    Pop-Location
    Remove-Item -LiteralPath $buildLog, $errorLog -ErrorAction SilentlyContinue
}
