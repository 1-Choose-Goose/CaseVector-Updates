$ErrorActionPreference = 'Stop'
$source = Join-Path $env:GITHUB_WORKSPACE 'private-source'
$tags = @(& git -C $source tag --list 'v[0-9]*' --sort=-version:refname)
if ($LASTEXITCODE -ne 0 -or $tags.Count -eq 0) {
    throw 'Private source tags could not be listed.'
}
$tag = [string]$tags[0]
Write-Host "Latest source tag candidate: $tag"
if ($tag -notmatch '^v\d+\.\d+\.\d+$') {
    throw 'No valid private source release tag was found.'
}
& git -C $source merge-base --is-ancestor $tag 'origin/main'
if ($LASTEXITCODE -ne 0) { throw 'The release tag is not on private main.' }
& git -C $source checkout --detach --quiet $tag
if ($LASTEXITCODE -ne 0) { throw 'The release tag could not be checked out.' }
$version = $tag.Substring(1)
$versionText = Get-Content -LiteralPath (Join-Path $source 'version.py') -Raw
if ($versionText -notmatch ('(?m)^APP_VERSION\s*=\s*["'']' + [regex]::Escape($version) + '["'']')) {
    throw 'The tag and application version disagree.'
}
$repositoryText = Get-Content -LiteralPath (Join-Path $source 'version.py') -Raw
if ($repositoryText -notmatch '(?m)^REPOSITORY\s*=\s*["'']1-Choose-Goose/CaseVector-Updates["'']') {
    throw 'The application update channel changed.'
}
$existing = & gh release view $tag --repo 1-Choose-Goose/CaseVector-Updates --json tagName,isDraft 2>$null
if ($LASTEXITCODE -eq 0) {
    $release = $existing | ConvertFrom-Json
    if (-not $release.isDraft) {
        "publish=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
        Write-Host "Release $tag already exists; nothing to publish."
        exit 0
    }
}
"tag=$tag" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
"publish=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Encoding utf8 -Append
Write-Host "Selected private source tag $tag."
exit 0
