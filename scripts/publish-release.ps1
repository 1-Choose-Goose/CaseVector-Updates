param([Parameter(Mandatory = $true)][string]$Tag)
$ErrorActionPreference = 'Stop'
if ($Tag -notmatch '^v\d+\.\d+\.\d+$') { throw 'Invalid release tag.' }
$folder = Join-Path $env:GITHUB_WORKSPACE "private-source/release/$Tag"
$names = @('CaseVector-Windows-x64.zip', 'CaseVector-Windows-x64.zip.sha256', 'release-manifest.json', 'release-manifest.sig')
foreach ($name in $names) {
    if (-not (Test-Path -LiteralPath (Join-Path $folder $name) -PathType Leaf)) {
        throw "Missing release file: $name"
    }
}
$files = @($names | ForEach-Object { Join-Path $folder $_ })
$notes = Join-Path $folder 'release-notes.md'
if (-not (Test-Path -LiteralPath $notes -PathType Leaf)) { throw 'Missing release notes.' }
$existing = & gh release view $Tag --repo 1-Choose-Goose/CaseVector-Updates --json isDraft 2>$null
if ($LASTEXITCODE -eq 0) {
    $release = $existing | ConvertFrom-Json
    if (-not $release.isDraft) { throw 'Release has already been published.' }
    & gh release edit $Tag --repo 1-Choose-Goose/CaseVector-Updates --title "CaseVector $($Tag.Substring(1))" --notes-file $notes
    if ($LASTEXITCODE -ne 0) { throw 'GitHub draft update failed.' }
} else {
    & gh release create $Tag --repo 1-Choose-Goose/CaseVector-Updates --target main --title "CaseVector $($Tag.Substring(1))" --notes-file $notes --draft
    if ($LASTEXITCODE -ne 0) { throw 'GitHub draft creation failed.' }
}
& gh release upload $Tag @files --repo 1-Choose-Goose/CaseVector-Updates --clobber
if ($LASTEXITCODE -ne 0) { throw 'GitHub asset upload failed.' }
& gh release edit $Tag --repo 1-Choose-Goose/CaseVector-Updates --draft=false
if ($LASTEXITCODE -ne 0) { throw 'GitHub release publication failed.' }
