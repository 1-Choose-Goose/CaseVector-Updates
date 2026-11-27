param([Parameter(Mandatory = $true)][string]$Tag)
$ErrorActionPreference = 'Stop'
if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid release tag.' }
$source = Join-Path $env:GITHUB_WORKSPACE 'private-source'
$buildLog = Join-Path $env:RUNNER_TEMP 'casevector-build.log'
Push-Location $source
try {
    & python tools/check_version.py --tag $Tag *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Version check failed. Private output withheld.' }
    & ./build_windows.ps1 -SkipInstaller -CreateUpdateArchive *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Build failed. Private output withheld.' }
    & python tools/release_notes.py "release/$Tag/release-notes.md" *> $buildLog
    if ($LASTEXITCODE -ne 0) { throw 'Release notes preparation failed. Private output withheld.' }
}
catch {
    throw 'Private source build or tests failed. Output is withheld from public logs.'
}
finally {
    Pop-Location
}
