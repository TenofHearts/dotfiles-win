[CmdletBinding()]
param(
    [ValidateSet('install', 'status')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'config/nvim'))
$destination = [IO.Path]::GetFullPath($ConfigPath)

function Test-NvimLink {
    param([string]$Path, [string]$Target)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    $item -and $item.LinkType -eq 'Junction' -and
        [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\') -ieq $Target.TrimEnd('\')
}

if ($Action -eq 'status') {
    if (Test-NvimLink $destination $source) { Write-Output "OK $destination -> $source" }
    else { throw "MISSING/CHANGED $destination" }
    return
}
if (-not (Test-Path -LiteralPath (Join-Path $source 'init.lua') -PathType Leaf)) {
    throw 'Neovim submodule missing. Run git submodule update --init --recursive.'
}
if (Test-NvimLink $destination $source) { Write-Output 'Neovim junction is already installed.'; return }
if ($destination -ieq $source -or $source.StartsWith($destination.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $destination.StartsWith($source.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Neovim destination must not overlap the submodule.'
}
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path needs manual review: $cursor" }
    $cursor = Split-Path $cursor -Parent
}
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Container)) {
    throw 'Neovim destination is not a directory.'
}
Write-Output "Install Neovim junction: $destination -> $source"
if ($DryRun) { return }
if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Recurse -Force }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
