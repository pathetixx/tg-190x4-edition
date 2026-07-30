[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDir,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$ReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$exe = Join-Path $ReleaseDir 'AyuGram.exe'
$updater = Join-Path $ReleaseDir 'Updater.exe'
$telegramExe = Join-Path $ReleaseDir 'Telegram.exe'

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "AyuGram.exe was not produced in $ReleaseDir"
}
if (-not (Test-Path -LiteralPath $updater -PathType Leaf)) {
    throw "Updater.exe was not produced in $ReleaseDir"
}
if (Test-Path -LiteralPath $telegramExe -PathType Leaf) {
    throw 'Telegram.exe exists in the release directory. The fork identity regressed.'
}

$exeInfo = (Get-Item -LiteralPath $exe).VersionInfo
$updaterInfo = (Get-Item -LiteralPath $updater).VersionInfo

if ($exeInfo.ProductName -ne 'AyuGram Desktop') {
    throw "Unexpected ProductName: $($exeInfo.ProductName)"
}
if ($exeInfo.FileDescription -ne 'AyuGram Desktop') {
    throw "Unexpected FileDescription: $($exeInfo.FileDescription)"
}
if (-not $exeInfo.FileVersion.StartsWith($Version)) {
    throw "Unexpected AyuGram.exe version: $($exeInfo.FileVersion), expected $Version"
}
if ($updaterInfo.FileDescription -ne 'AyuGram Desktop Updater') {
    throw "Unexpected updater description: $($updaterInfo.FileDescription)"
}
if (-not $updaterInfo.FileVersion.StartsWith($Version)) {
    throw "Unexpected Updater.exe version: $($updaterInfo.FileVersion), expected $Version"
}

$exeHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
$updaterHash = (Get-FileHash -LiteralPath $updater -Algorithm SHA256).Hash.ToLowerInvariant()

$smokeRoot = Join-Path $env:RUNNER_TEMP 'ayugram-smoke-profile'
Remove-Item -LiteralPath $smokeRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $smokeRoot | Out-Null

Write-Host 'Starting isolated AyuGram smoke test...'
$process = Start-Process -FilePath $exe -ArgumentList @('-many', '-workdir', $smokeRoot) -WorkingDirectory $smokeRoot -PassThru
Start-Sleep -Seconds 15

if ($process.HasExited) {
    if ($process.ExitCode -ne 0) {
        throw "AyuGram exited during smoke test with code $($process.ExitCode)."
    }
    Write-Host 'AyuGram exited cleanly during smoke test.'
}
else {
    Stop-Process -Id $process.Id -Force
    $process.WaitForExit()
    Write-Host 'AyuGram stayed alive for 15 seconds; process stopped after successful smoke window.'
}

$manifest = [ordered]@{
    version = $Version
    executable = 'AyuGram.exe'
    productName = $exeInfo.ProductName
    fileDescription = $exeInfo.FileDescription
    fileVersion = $exeInfo.FileVersion
    productVersion = $exeInfo.ProductVersion
    exeSha256 = $exeHash
    updaterSha256 = $updaterHash
    smokeTestSeconds = 15
    generatedAtUtc = [DateTime]::UtcNow.ToString('o')
}

$manifestPath = Join-Path $OutputDir 'artifact-manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding utf8

Copy-Item -LiteralPath $exe -Destination (Join-Path $OutputDir 'AyuGram.exe') -Force
Copy-Item -LiteralPath $updater -Destination (Join-Path $OutputDir 'Updater.exe') -Force

$modules = Join-Path $ReleaseDir 'modules'
if (Test-Path -LiteralPath $modules -PathType Container) {
    Copy-Item -LiteralPath $modules -Destination (Join-Path $OutputDir 'modules') -Recurse -Force
}

Write-Host "AyuGram.exe SHA-256: $exeHash"
Write-Host "Updater.exe SHA-256: $updaterHash"
Write-Host "Artifact validation passed for AyuGram $Version."
