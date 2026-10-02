# A small loader avoids Windows symlink privileges while keeping edits live.
[CmdletBinding()]
param(
    [ValidateSet('install', 'status', 'restore')][string]$Action = 'status',
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win'),
    [string]$Manifest,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Join-Path $root 'config/powershell/Microsoft.PowerShell_profile.ps1'
$destination = [IO.Path]::GetFullPath($ProfilePath)
$escapedSource = $source.Replace("'", "''")
$loader = "# Managed by dotfiles-win. Edit the configuration in the repository.`n. '$escapedSource'`n"

function Test-Loader {
    param([string]$Path, [string]$Content)
    (Test-Path -LiteralPath $Path -PathType Leaf) -and
        ([IO.File]::ReadAllText($Path) -ceq $Content)
}

if ($Action -eq 'status') {
    if (Test-Loader $destination $loader) { Write-Output "OK $destination" }
    else { throw "MISSING/CHANGED $destination" }
    return
}

if ($Action -eq 'restore') {
    if (-not $Manifest) { throw 'Restore requires -Manifest.' }
    $record = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    if ((Test-Path -LiteralPath $record.destination) -and
        -not (Test-Loader $record.destination $record.loader)) {
        throw "Refusing to overwrite a changed profile: $($record.destination)"
    }
    if ($record.backup -and -not (Test-Path -LiteralPath $record.backup -PathType Leaf)) {
        throw "Backup missing: $($record.backup)"
    }
    Write-Output "Restore $($record.destination)"
    if ($DryRun) { return }
    if ($record.backup) {
        Copy-Item -LiteralPath $record.backup -Destination $record.destination -Force
    } elseif (Test-Path -LiteralPath $record.destination) {
        Remove-Item -LiteralPath $record.destination
    }
    return
}

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source: $source" }
if (Test-Loader $destination $loader) { Write-Output 'Profile loader is already installed.'; return }
# Refuse linked paths rather than accidentally writing into another checkout.
$cursor = $destination
while ($cursor) {
    if (Test-Path -LiteralPath $cursor) {
        $item = Get-Item -LiteralPath $cursor -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Linked path needs manual review: $cursor"
        }
    }
    $cursor = Split-Path $cursor -Parent
}
if ((Test-Path -LiteralPath $destination) -and
    -not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw 'Profile destination is not a file.' }
Write-Output "Install profile loader: $destination -> $source"
if ($DryRun) { return }
$backupDirectory = Join-Path $StatePath ('backups/' + [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fffffff'))
New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
$backup = $null
if (Test-Path -LiteralPath $destination) {
    $backup = Join-Path $backupDirectory 'profile.ps1'
    Copy-Item -LiteralPath $destination -Destination $backup
}
$manifestPath = Join-Path $backupDirectory 'manifest.json'
@{ destination = $destination; backup = $backup; loader = $loader } |
    ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
try {
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($destination, $loader, [Text.UTF8Encoding]::new($false))
} catch {
    if ($backup) { Copy-Item -LiteralPath $backup -Destination $destination -Force }
    elseif (Test-Path -LiteralPath $destination -PathType Leaf) { Remove-Item -LiteralPath $destination }
    throw
}
Write-Output "Backup manifest: $manifestPath"
