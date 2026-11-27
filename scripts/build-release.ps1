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

    & python -m pip install --disable-pip-version-check --only-binary=:all: -r (Join-Path $source 'requirements.txt') *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Headless test dependencies failed.' }
    & python -m unittest -q `
        tests.test_updates.UpdateTests.test_install_and_rollback_preserve_old_binary_and_data `
        tests.test_updates.UpdateTests.test_release_check_selects_highest_version_not_first_release `
        tests.test_updates.UpdateTests.test_signed_package_rejects_tampering_and_wrong_architecture `
        tests.test_probe_match `
        tests.test_database_merge *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Headless release tests failed.' }
    Write-Host 'Headless release tests completed.'

    $runner = (Get-Command pwsh -ErrorAction Stop).Source
    $process = Start-Process -FilePath $runner `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-File', '.\build_windows.ps1',
                        '-SkipInstaller', '-SkipTests', '-CreateUpdateArchive') `
        -WorkingDirectory $source -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $buildLog -RedirectStandardError $errorLog
    $minutes = 0
    while (-not $process.WaitForExit(60000)) {
        $minutes++
        $stage = 'starting private build'
        $buildRoots = @(Get-ChildItem -LiteralPath $env:TEMP -Directory -Filter 'casevector-build-*' -ErrorAction SilentlyContinue)
        if ($buildRoots.Count -gt 0) {
            $buildRoot = $buildRoots | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            $stage = 'creating Python environment'
            if (Test-Path -LiteralPath (Join-Path $buildRoot.FullName 'venv\Scripts\python.exe')) {
                $stage = 'installing dependencies'
            }
            if (Test-Path -LiteralPath (Join-Path $buildRoot.FullName 'venv\Scripts\pyinstaller.exe')) {
                $stage = 'running tests'
            }
            if (Test-Path -LiteralPath (Join-Path $buildRoot.FullName 'work\updater')) {
                $stage = 'packaging updater'
            }
            if (Test-Path -LiteralPath (Join-Path $buildRoot.FullName 'work\application')) {
                $stage = 'packaging application'
            }
            if (Test-Path -LiteralPath (Join-Path $buildRoot.FullName 'smoke-app')) {
                $stage = 'checking application launch or finalizing package'
            }
        }
        Write-Host "Private build still running ($minutes minute(s)); stage: $stage; output withheld."
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
