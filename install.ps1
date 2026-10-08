#Requires -Version 7.3
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win'),
    [string]$NvimPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$SkipNvim,
    [string]$GitPath = (Join-Path $HOME '.gitconfig'),
    [string]$TerminalPath,
    [switch]$SkipGit,
    [switch]$SkipTerminal
)
$ErrorActionPreference = 'Stop'
& "$PSScriptRoot/scripts/links.ps1" -Action install -ProfilePath $ProfilePath -StatePath $StatePath -DryRun:$DryRun
if (-not $SkipNvim) {
    & "$PSScriptRoot/scripts/nvim.ps1" -Action install -ConfigPath $NvimPath -StatePath $StatePath -DryRun:$DryRun
}
if (-not $SkipGit) {
    & "$PSScriptRoot/scripts/git.ps1" -Action install -ConfigPath $GitPath -DryRun:$DryRun
}
if (-not $SkipTerminal) {
    & "$PSScriptRoot/scripts/terminal.ps1" -Action apply -ConfigPath $TerminalPath -DryRun:$DryRun
}
