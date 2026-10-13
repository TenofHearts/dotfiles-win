[CmdletBinding()]
param(
    [ValidateSet('install', 'status')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $HOME '.glzr/glazewm/config.yaml'),
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
if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
