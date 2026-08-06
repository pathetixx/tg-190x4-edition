[CmdletBinding()]
param(
    [string]$ReleasePath = "",
    [string]$OutputPath = "",
    [switch]$EnableAutoUpdate
)

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if ([string]::IsNullOrWhiteSpace($ReleasePath)) {
    $ReleasePath = Join-Path $repoRoot "out\Release"
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot "artifacts"
}
$ReleasePath = (Resolve-Path $ReleasePath).Path
$OutputPath = [IO.Path]::GetFullPath($OutputPath)

$versionLine = Get-Content (Join-Path $repoRoot "Telegram\build\version") |
    Where-Object { $_ -match '^AppVersionStr\s+([^\s]+)$' } |
    Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^AppVersionStr\s+([^\s]+)$') {
    throw "Could not read AppVersionStr."
}
$version = $Matches[1]

$exePath = Join-Path $ReleasePath "TG190x4.exe"
$updaterPath = Join-Path $ReleasePath "Updater.exe"
if (-not (Test-Path -LiteralPath $exePath)) {
    throw "Missing $exePath"
}
if ($EnableAutoUpdate -and -not (Test-Path -LiteralPath $updaterPath)) {
    throw "Auto-update packaging was requested, but Updater.exe is missing."
}

$iscc = @(
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles} "Inno Setup 6\ISCC.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 5\ISCC.exe"),
    (Join-Path ${env:LocalAppData} "Programs\Inno Setup 6\ISCC.exe")
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $iscc) {
    throw "ISCC.exe was not found. Install Inno Setup 6 before packaging."
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
$portableRoot = Join-Path $OutputPath "portable"
if (Test-Path -LiteralPath $portableRoot) {
    Remove-Item -LiteralPath $portableRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $portableRoot -Force | Out-Null
Copy-Item -LiteralPath $exePath -Destination $portableRoot -Force
if ($EnableAutoUpdate) {
    Copy-Item -LiteralPath $updaterPath -Destination $portableRoot -Force
}
$modulesPath = Join-Path $ReleasePath "modules"
if (Test-Path -LiteralPath $modulesPath) {
    Copy-Item -LiteralPath $modulesPath -Destination $portableRoot -Recurse -Force
}

$autoUpdateValue = if ($EnableAutoUpdate) { "1" } else { "0" }
$isccArguments = @(
    "/DMyAppVersion=$version",
    "/DMyAppVersionFull=$version",
    "/DMyBuildTarget=win64",
    "/DMyEnableAutoUpdate=$autoUpdateValue",
    "/DReleasePath=$ReleasePath",
    (Join-Path $repoRoot "Telegram\build\setup.iss")
)
& $iscc @isccArguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE."
}

$installerPath = Join-Path $ReleasePath "ayusetup-x64.$version.exe"
if (-not (Test-Path -LiteralPath $installerPath)) {
    throw "Installer was not produced: $installerPath"
}

$portableZip = Join-Path $OutputPath "TG190x4-portable-x64-$version.zip"
if (Test-Path -LiteralPath $portableZip) {
    Remove-Item -LiteralPath $portableZip -Force
}
Compress-Archive -Path (Join-Path $portableRoot "*") -DestinationPath $portableZip -CompressionLevel Optimal
$installerArtifact = Join-Path $OutputPath "TG190x4-setup-x64-$version.exe"
Copy-Item -LiteralPath $installerPath -Destination $installerArtifact -Force

$hashFiles = Get-ChildItem -LiteralPath $OutputPath -File |
    Where-Object { $_.Name -match '^TG190x4-(portable|setup)-x64-.*\.(zip|exe)$' }
$hashLines = foreach ($file in $hashFiles) {
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    "$hash  $($file.Name)"
}
Set-Content -LiteralPath (Join-Path $OutputPath "SHA256SUMS.txt") -Value $hashLines -Encoding ascii
Remove-Item -LiteralPath $portableRoot -Recurse -Force

Get-ChildItem -LiteralPath $OutputPath -File | Select-Object Name, Length
