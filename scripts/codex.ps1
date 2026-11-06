[CmdletBinding()]
param(
    [ValidateSet('install', 'status')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }) 'dotfiles.config.toml'),
    [switch]$DryRun,
    [Alias('-force')][switch]$Force,
    [Parameter(ValueFromRemainingArguments)][string[]]$ExtraArguments
)
$ErrorActionPreference = 'Stop'
foreach ($argument in $ExtraArguments) {
    if ($argument -ine '--force') { throw "Unknown argument: $argument" }
    $Force = $true
}
$source = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'config/ai/codex/dotfiles.config.toml'))
$destination = [IO.Path]::GetFullPath($ConfigPath)
# CODEX_HOME (and ~/.codex) may itself be a deliberate directory junction.
$codexHomePath = [IO.Path]::GetFullPath($(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }))
if ((Split-Path $destination -Parent) -ieq $codexHomePath) {
    $homeItem = Get-Item -LiteralPath $codexHomePath -Force -ErrorAction SilentlyContinue
    if ($homeItem -and $homeItem.PSIsContainer -and $homeItem.LinkType) {
        $destination = Join-Path ($homeItem.ResolveLinkTarget($true).FullName) (Split-Path $destination -Leaf)
    }
}

if ($Action -ne 'status' -and -not $Force -and
    (Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue)) {
    Write-Output "SKIP existing target: $destination (use -Force to update)"
    return
}

function Test-CodexLink {
    param([string]$Path, [string]$Target)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    $item -and $item.LinkType -eq 'SymbolicLink' -and
        [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\') -ieq $Target.TrimEnd('\')
}

if ($Action -eq 'status') {
    if (Test-CodexLink $destination $source) { Write-Output "OK $destination -> $source" }
    else { throw "MISSING/CHANGED $destination" }
    return
}
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw 'AI configuration submodule missing. Run git submodule update --init --recursive.'
}
if (Test-CodexLink $destination $source) { Write-Output 'Codex symlink is already installed.'; return }
if ($destination -ieq $source -or $source.StartsWith($destination.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Codex destination must not contain the configuration source.'
}
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
        -not ($cursor -ieq $destination -and $item.LinkType -eq 'SymbolicLink' -and -not $item.PSIsContainer)) {
        throw "Linked path needs manual review: $cursor"
    }
    $cursor = Split-Path $cursor -Parent
}
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw 'Codex destination is not a file.'
}
Write-Output "Install Codex symlink: $destination -> $source"
if ($DryRun) { return }
if (Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue) { Remove-Item -LiteralPath $destination -Force }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
