[CmdletBinding()]
param(
    [ValidateSet('install', 'status', 'restore')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $HOME '.glzr/glazewm/config.yaml'),
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win'),
    [string]$Manifest,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'config/glazewm/config.yaml'))
$destination = [IO.Path]::GetFullPath($ConfigPath)

function Test-GlazeWMLink {
    param([string]$Path, [string]$Target)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    $item -and $item.LinkType -eq 'SymbolicLink' -and
        [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\') -ieq $Target.TrimEnd('\')
}

if ($Action -eq 'status') {
    if (Test-GlazeWMLink $destination $source) { Write-Output "OK $destination -> $source" }
    else { throw "MISSING/CHANGED $destination" }
    return
}
if ($Action -eq 'restore') {
    if (-not $Manifest) { throw 'Restore requires -Manifest.' }
    $record = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    if ($record.kind -ne 'glazewm-symlink') { throw 'Not a GlazeWM backup manifest.' }
    if (-not (Test-GlazeWMLink $record.destination $record.source)) {
        throw "Refusing to replace a changed GlazeWM config: $($record.destination)"
    }
    if ($record.backup -and -not (Test-Path -LiteralPath $record.backup -PathType Leaf)) {
        throw "Backup missing: $($record.backup)"
    }
    Write-Output "Restore $($record.destination)"
    if ($DryRun) { return }
    # Delete the symlink itself; keep the repository file.
    [IO.File]::Delete($record.destination)
    if ($record.backup) { Move-Item -LiteralPath $record.backup -Destination $record.destination }
    return
}
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw 'GlazeWM config missing from the repository.'
}
if (Test-GlazeWMLink $destination $source) { Write-Output 'GlazeWM symlink is already installed.'; return }
if ($destination -ieq $source -or $source.StartsWith($destination.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'GlazeWM destination must not contain the configuration source.'
}
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path needs manual review: $cursor" }
    $cursor = Split-Path $cursor -Parent
}
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw 'GlazeWM destination is not a file.'
}
Write-Output "Install GlazeWM symlink: $destination -> $source"
if ($DryRun) { return }
$stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fffffff')
$backup = $null
$manifestDirectory = Join-Path $StatePath "backups/glazewm-$stamp"
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
if (Test-Path -LiteralPath $destination) { $backup = "$destination.dotfiles-backup-$stamp" }
$manifestPath = Join-Path $manifestDirectory 'manifest.json'
@{ kind = 'glazewm-symlink'; destination = $destination; source = $source; backup = $backup } |
    ConvertTo-Json | Set-Content -LiteralPath $manifestPath -Encoding UTF8
if ($backup) { Move-Item -LiteralPath $destination -Destination $backup }
try {
    New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
    New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
} catch {
    if ($backup) { Move-Item -LiteralPath $backup -Destination $destination }
    throw
}
Write-Output "Backup manifest: $manifestPath"
