[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,
    [string]$LockFile = (Join-Path $PSScriptRoot '../integration/source-lock.json')
)

$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$lock = Get-Content -LiteralPath $LockFile -Raw | ConvertFrom-Json

function Read-SourceFile([string]$RelativePath) {
    $path = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required source file is missing: $RelativePath"
    }
    return [System.IO.File]::ReadAllText($path)
}

function Assert-Contains([string]$RelativePath, [string]$Needle) {
    $content = Read-SourceFile $RelativePath
    if (-not $content.Contains($Needle)) {
        throw "Missing required marker in ${RelativePath}: $Needle"
    }
}

function Assert-NotContains([string]$RelativePath, [string]$Needle) {
    $content = Read-SourceFile $RelativePath
    if ($content.Contains($Needle)) {
        throw "Forbidden marker remains in ${RelativePath}: $Needle"
    }
}

Push-Location $SourceRoot
try {
    $head = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read source HEAD.' }
    if ($head -ne $lock.commit) {
        throw "Source HEAD mismatch. Expected $($lock.commit), got $head"
    }

    $submoduleStatus = @(git submodule status --recursive)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect submodules.' }
    $badSubmodules = @($submoduleStatus | Where-Object { $_ -match '^[\-+U]' })
    if ($badSubmodules.Count -gt 0) {
        throw "Submodules are missing or do not match the pinned source commit:`n$($badSubmodules -join "`n")"
    }
}
finally {
    Pop-Location
}

Assert-Contains 'Telegram/SourceFiles/core/version.h' "AppId = `"$($lock.ayuGramAppId)`""
Assert-Contains 'Telegram/SourceFiles/core/version.h' 'AppName = "AyuGram Desktop"'
Assert-Contains 'Telegram/SourceFiles/core/version.h' 'AppFile = "AyuGram"'
Assert-Contains 'Telegram/SourceFiles/core/version.h' "AppVersionStr = `"$($lock.telegramDesktopVersion)`""
Assert-NotContains 'Telegram/SourceFiles/core/version.h' 'AppName = "Telegram Desktop"'
Assert-NotContains 'Telegram/SourceFiles/core/version.h' 'AppFile = "Telegram"'

Assert-Contains 'Telegram/build/setup.iss' '#define MyAppExeName "AyuGram.exe"'
Assert-Contains 'Telegram/build/setup.iss' 'Source: "{#ReleasePath}\{#MyAppExeName}"'
Assert-Contains 'Telegram/build/setup.iss' 'UninstallDisplayIcon={app}\{#MyAppExeName}'
Assert-NotContains 'Telegram/build/setup.iss' 'Source: "{#ReleasePath}\Telegram.exe"'
Assert-NotContains 'Telegram/build/setup.iss' 'SignTool=sha256'

Assert-Contains 'Telegram/Resources/winrc/Telegram.rc' 'VALUE "CompanyName", "Radolyn Labs"'
Assert-Contains 'Telegram/Resources/winrc/Telegram.rc' 'VALUE "ProductName", "AyuGram Desktop"'
Assert-Contains 'Telegram/Resources/winrc/Updater.rc' 'VALUE "FileDescription", "AyuGram Desktop Updater"'

$appx = Read-SourceFile 'Telegram/Resources/uwp/AppX/AppxManifest.xml'
if ($appx.Contains('TelegramMessengerLLP.TelegramDesktop')) {
    Write-Warning 'AppX manifest still uses Telegram Store identity. This workflow must not publish AppX/MSIX.'
}

Write-Host "Verified source $head for AyuGram $($lock.telegramDesktopVersion)."
