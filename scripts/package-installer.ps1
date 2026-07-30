[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,
    [Parameter(Mandatory = $true)]
    [string]$ReleaseDir,
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [Parameter(Mandatory = $true)]
    [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$ReleaseDir = (Resolve-Path -LiteralPath $ReleaseDir).Path
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

$candidates = @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe')
)
$iscc = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $iscc) {
    throw 'Inno Setup 6 compiler (ISCC.exe) was not found.'
}

$setupScript = Join-Path $SourceRoot 'Telegram\build\setup.iss'
if (-not (Test-Path -LiteralPath $setupScript -PathType Leaf)) {
    throw "setup.iss is missing: $setupScript"
}

$arguments = @(
    '/Qp',
    "/DMyAppVersion=$Version",
    "/DMyAppVersionFull=$Version",
    '/DMyBuildTarget=win64',
    "/DReleasePath=$ReleaseDir",
    $setupScript
)

Write-Host "Packaging with $iscc"
& $iscc @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
}

$installerName = "ayusetup-x64.$Version.exe"
$installer = Join-Path $ReleaseDir $installerName
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Expected installer was not produced: $installer"
}

$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
Copy-Item -LiteralPath $installer -Destination (Join-Path $OutputDir $installerName) -Force
Set-Content -LiteralPath (Join-Path $OutputDir "$installerName.sha256") -Value "$hash  $installerName" -Encoding ascii

Write-Host "Installer SHA-256: $hash"
Write-Host "Packaged $installerName"
