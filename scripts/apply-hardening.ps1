[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
$Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Replace-Exact {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$OldText,
        [Parameter(Mandatory = $true)][string]$NewText
    )

    $path = Join-Path $SourceRoot $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required source file is missing: $RelativePath"
    }

    $content = [System.IO.File]::ReadAllText($path)
    $count = ([regex]::Matches($content, [regex]::Escape($OldText))).Count
    if ($count -ne 1) {
        throw "Expected exactly one match in ${RelativePath}, found $count. Upstream changed and the patch must be reviewed."
    }

    $updated = $content.Replace($OldText, $NewText)
    [System.IO.File]::WriteAllText($path, $updated, $Utf8NoBom)
    Write-Host "Patched $RelativePath"
}

Replace-Exact 'Telegram/SourceFiles/core/version.h' `
    'constexpr auto AppId = "{53F49750-6209-4FBF-9CA8-7A333C87D1ED}"_cs;' `
    'constexpr auto AppId = "{53F49750-6209-4FBF-9CA8-7A333C87D666}"_cs;'
Replace-Exact 'Telegram/SourceFiles/core/version.h' `
    'constexpr auto AppNameOld = "Telegram Win (Unofficial)"_cs;' `
    'constexpr auto AppNameOld = "AyuGram for Windows"_cs;'
Replace-Exact 'Telegram/SourceFiles/core/version.h' `
    'constexpr auto AppName = "Telegram Desktop"_cs;' `
    'constexpr auto AppName = "AyuGram Desktop"_cs;'
Replace-Exact 'Telegram/SourceFiles/core/version.h' `
    'constexpr auto AppFile = "Telegram"_cs;' `
    'constexpr auto AppFile = "AyuGram"_cs;'

Replace-Exact 'Telegram/build/setup.iss' `
    'UninstallDisplayIcon={app}\Telegram.exe' `
    'UninstallDisplayIcon={app}\{#MyAppExeName}'
Replace-Exact 'Telegram/build/setup.iss' `
    'Source: "{#ReleasePath}\Telegram.exe"; DestDir: "{app}"; Flags: ignoreversion' `
    'Source: "{#ReleasePath}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion'
Replace-Exact 'Telegram/build/setup.iss' `
    'SignTool=sha256' `
    '; SignTool is intentionally disabled for unsigned CI artifacts.'

Replace-Exact 'Telegram/Resources/winrc/Telegram.rc' `
    'VALUE "CompanyName", "Telegram FZ-LLC"' `
    'VALUE "CompanyName", "Radolyn Labs"'
Replace-Exact 'Telegram/Resources/winrc/Telegram.rc' `
    'VALUE "FileDescription", "Telegram Desktop"' `
    'VALUE "FileDescription", "AyuGram Desktop"'
Replace-Exact 'Telegram/Resources/winrc/Telegram.rc' `
    'VALUE "ProductName", "Telegram Desktop"' `
    'VALUE "ProductName", "AyuGram Desktop"'

Replace-Exact 'Telegram/Resources/winrc/Updater.rc' `
    'VALUE "CompanyName", "Telegram FZ-LLC"' `
    'VALUE "CompanyName", "Radolyn Labs"'
Replace-Exact 'Telegram/Resources/winrc/Updater.rc' `
    'VALUE "FileDescription", "Telegram Desktop Updater"' `
    'VALUE "FileDescription", "AyuGram Desktop Updater"'
Replace-Exact 'Telegram/Resources/winrc/Updater.rc' `
    'VALUE "ProductName", "Telegram Desktop"' `
    'VALUE "ProductName", "AyuGram Desktop"'

Write-Host 'AyuGram hardening patch applied successfully.'
