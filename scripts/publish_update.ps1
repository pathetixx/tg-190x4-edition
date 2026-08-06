[CmdletBinding()]
param(
    [string]$ReleasePath = "",
    [string]$OutputPath = "",
    [string]$Repo = "pathetixx/ayugram-updates",
    [switch]$Publish
)

$ErrorActionPreference = "Stop"

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) {
    throw "Not inside a git worktree."
}
$repoRoot = $repoRoot -replace "/", "\"

if ([string]::IsNullOrWhiteSpace($ReleasePath)) {
    $ReleasePath = Join-Path $repoRoot "out\Release"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "artifacts\updates"
}

$appExe = Join-Path $ReleasePath "AyuGram.exe"
$updaterExe = Join-Path $ReleasePath "Updater.exe"
$packerExe = Join-Path $ReleasePath "Packer.exe"

foreach ($required in @($appExe, $updaterExe, $packerExe)) {
    if (-not (Test-Path -LiteralPath $required)) {
        throw "Missing $required. Build with AYUGRAM_ENABLE_AUTOUPDATE=ON first."
    }
}

$versionFile = Join-Path $repoRoot "Telegram\build\version"
$versionText = Get-Content -LiteralPath $versionFile -Raw
$numberMatch = [regex]::Match($versionText, "(?m)^AppVersion\s+(\d+)\s*$")
$stringMatch = [regex]::Match($versionText, "(?m)^AppVersionStr\s+([^\s]+)\s*$")
if (-not $numberMatch.Success -or -not $stringMatch.Success) {
    throw "Could not read the version from $versionFile."
}
$versionNumber = [int]$numberMatch.Groups[1].Value
$versionString = $stringMatch.Groups[1].Value

$exeVersion = (Get-Item -LiteralPath $appExe).VersionInfo.FileVersion
if (-not $exeVersion.StartsWith($versionString)) {
    throw "AyuGram.exe reports $exeVersion but the tree says $versionString. Rebuild before publishing."
}

$packageName = "tx64upd$versionNumber"

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

Write-Host "Packing update $versionString ($versionNumber)..."
Push-Location $OutputPath
try {
    & $packerExe -path $appExe -path $updaterExe -target win64 -version $versionNumber | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Packer failed with exit code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}

$packagePath = Join-Path $OutputPath $packageName
if (-not (Test-Path -LiteralPath $packagePath)) {
    throw "Packer did not produce $packageName."
}

$manifest = "{`"win64`":{`"stable`":{`"released`":$versionNumber,`"link`":`"/$packageName`"}}}"
$manifestPath = Join-Path $OutputPath "current4"
[System.IO.File]::WriteAllText($manifestPath, $manifest, (New-Object System.Text.UTF8Encoding($false)))

$packageSize = [math]::Round((Get-Item -LiteralPath $packagePath).Length / 1MB, 1)
Write-Host ""
Write-Host "Package:  $packagePath ($packageSize MB)"
Write-Host "Manifest: $manifestPath"
Write-Host "Contents: $manifest"

if (-not $Publish) {
    Write-Host ""
    Write-Host "Prepared only. Re-run with -Publish to upload to $Repo."
    exit 0
}

$tag = "v$versionString"
$previousErrorAction = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    & gh release view $tag --repo $Repo *> $null
    $releaseExists = ($LASTEXITCODE -eq 0)
} finally {
    $ErrorActionPreference = $previousErrorAction
}
if ($releaseExists) {
    Write-Host "Updating existing release $tag..."
    & gh release upload $tag $packagePath $manifestPath --repo $Repo --clobber | Out-Host
} else {
    Write-Host "Creating release $tag..."
    & gh release create $tag $packagePath $manifestPath `
        --repo $Repo `
        --latest `
        --title "AyuGram $versionString" `
        --notes "Update payload for AyuGram $versionString (Windows x64)." | Out-Host
}
if ($LASTEXITCODE -ne 0) {
    throw "Publishing to $Repo failed."
}

Write-Host ""
Write-Host "Published. Clients on an older build will pick this up automatically."
