[CmdletBinding()]
param(
    [string]$Remote = "",
    [string]$Ref = "",
    [switch]$LatestStable,
    [switch]$Apply,
    [switch]$NoFetch
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param([string[]]$Arguments)
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $result = & git @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($result -join "`n")"
    }
    return (($result | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}

function Test-GitRef {
    param([string]$Candidate)
    & git rev-parse --verify "$Candidate^{commit}" *> $null
    return ($LASTEXITCODE -eq 0)
}

$repoRoot = Invoke-Git @("rev-parse", "--show-toplevel")
Set-Location $repoRoot

$configPath = Join-Path $repoRoot "upstream.json"
$config = if (Test-Path -LiteralPath $configPath) {
    Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
} else {
    [pscustomobject]@{}
}

if ([string]::IsNullOrWhiteSpace($Remote)) {
    $Remote = if ($config.remote) { [string]$config.remote } else { "upstream" }
}
if ([string]::IsNullOrWhiteSpace($Ref) -and -not $LatestStable) {
    $Ref = if ($config.integrationRef) { [string]$config.integrationRef } else { "dev" }
}

$status = & git status --porcelain
if ($Apply -and $status) {
    throw "The worktree is not clean. Commit or stash changes before applying an upstream merge."
}

if (-not $NoFetch) {
    Invoke-Git @("fetch", "--prune", $Remote, "--tags") | Out-Host
}

if ($LatestStable) {
    $tagLines = & git ls-remote --tags --refs $Remote "refs/tags/v*"
    $tags = foreach ($line in $tagLines) {
        $match = [regex]::Match($line, "refs/tags/(v(\d+)\.(\d+)(?:\.(\d+))?)$")
        if ($match.Success) {
            [pscustomobject]@{
                Tag = $match.Groups[1].Value
                Major = [int]$match.Groups[2].Value
                Minor = [int]$match.Groups[3].Value
                Patch = if ($match.Groups[4].Success) { [int]$match.Groups[4].Value } else { 0 }
            }
        }
    }
    $latest = $tags | Sort-Object Major, Minor, Patch -Descending | Select-Object -First 1
    if (-not $latest) {
        throw "No stable upstream tag was found on $Remote."
    }
    $Ref = $latest.Tag
}

if ([string]::IsNullOrWhiteSpace($Ref)) {
    throw "An upstream ref is required."
}

$candidates = @()
if ($Ref -match "^refs/") {
    $candidates += $Ref
} elseif ($Ref -match "^v?\d+\.\d+") {
    $tag = if ($Ref.StartsWith("v")) { $Ref } else { "v$Ref" }
    $candidates += "refs/tags/$tag"
} else {
    $candidates += "$Remote/$Ref"
}

$target = $candidates | Where-Object { Test-GitRef $_ } | Select-Object -First 1
if (-not $target) {
    throw "Could not resolve upstream ref '$Ref'."
}

$targetSha = Invoke-Git @("rev-parse", "$target^{commit}")
$currentSha = Invoke-Git @("rev-parse", "HEAD")
$currentBranch = Invoke-Git @("branch", "--show-current")
$ahead = Invoke-Git @("rev-list", "--count", "$currentSha..$targetSha")
$behind = Invoke-Git @("rev-list", "--count", "$targetSha..$currentSha")

Write-Host "Current branch: $currentBranch"
Write-Host "Current commit: $currentSha"
Write-Host "Upstream ref:   $target"
Write-Host "Upstream commit: $targetSha"
Write-Host "Commits only upstream: $ahead"
Write-Host "Commits only fork:     $behind"

if (-not $Apply) {
    Write-Host "Preview only. Use -Apply after reviewing the range."
    exit 0
}

Invoke-Git @("config", "rerere.enabled", "true") | Out-Null
$prefix = if ($config.syncBranchPrefix) { [string]$config.syncBranchPrefix } else { "sync/upstream" }
$slug = ($Ref -replace "[^A-Za-z0-9._-]", "-").Trim("-")
$syncBranch = "$prefix/$slug"
if (& git show-ref --verify --quiet "refs/heads/$syncBranch") {
    throw "Sync branch '$syncBranch' already exists. Review or remove it before retrying."
}

Invoke-Git @("switch", "-c", $syncBranch) | Out-Host
$mergeOutput = & git merge --no-ff --no-edit --no-commit $target 2>&1
if ($LASTEXITCODE -ne 0) {
    $conflicts = & git diff --name-only --diff-filter=U
    & git merge --abort 2>&1 | Out-Null
    & git switch $currentBranch 2>&1 | Out-Null
    & git branch -D $syncBranch 2>&1 | Out-Null
    throw "Upstream merge has conflicts in: $($conflicts -join ', ')"
}

$verify = & python tools/verify_private_fork.py 2>&1
if ($LASTEXITCODE -ne 0) {
    & git merge --abort 2>&1 | Out-Null
    & git switch $currentBranch 2>&1 | Out-Null
    & git branch -D $syncBranch 2>&1 | Out-Null
    throw "Fork invariant verification failed:`n$($verify -join "`n")"
}

Invoke-Git @("commit", "-m", "build: sync Telegram upstream $Ref") | Out-Host
Write-Host "Created $syncBranch. Review the merge and open a pull request when ready."
