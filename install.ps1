#Requires -Version 7.3
[CmdletBinding()]
param(
    [switch]$DryRun,
    [Alias('-force')][switch]$Force,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$NvimPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$SkipNvim,
    [string]$GitPath = (Join-Path $HOME '.gitconfig'),
    [string]$TerminalPath,
    [switch]$SkipGit,
    [switch]$SkipTerminal,
    [string]$GlazeWMPath = (Join-Path $HOME '.glzr/glazewm/config.yaml'),
    [switch]$SkipGlazeWM,
    [string]$ZebarPath = (Join-Path $HOME '.glzr/zebar/settings.json'),
    [switch]$SkipZebar,
    [string]$CodexPath = (Join-Path $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }) 'dotfiles.config.toml'),
    [switch]$SkipCodex,
    [Parameter(ValueFromRemainingArguments)][string[]]$ExtraArguments
)
$ErrorActionPreference = 'Stop'
foreach ($argument in $ExtraArguments) {
    if ($argument -ine '--force') { throw "Unknown argument: $argument" }
    $Force = $true
}
if (-not $SkipCodex) {
    & "$PSScriptRoot/scripts/codex.ps1" -Action install -ConfigPath $CodexPath -DryRun:$DryRun -Force:$Force
}
& "$PSScriptRoot/scripts/links.ps1" -Action install -ProfilePath $ProfilePath -DryRun:$DryRun -Force:$Force
if (-not $SkipNvim) {
    & "$PSScriptRoot/scripts/nvim.ps1" -Action install -ConfigPath $NvimPath -DryRun:$DryRun -Force:$Force
}
if (-not $SkipGit) {
    & "$PSScriptRoot/scripts/git.ps1" -Action install -ConfigPath $GitPath -DryRun:$DryRun -Force:$Force
}
if (-not $SkipTerminal) {
    & "$PSScriptRoot/scripts/terminal.ps1" -Action apply -ConfigPath $TerminalPath -DryRun:$DryRun -Force:$Force
}

if (-not $SkipGlazeWM) {
    & "$PSScriptRoot/scripts/glazewm.ps1" -Action install -ConfigPath $GlazeWMPath -DryRun:$DryRun -Force:$Force
}

if (-not $SkipZebar) {
    & "$PSScriptRoot/scripts/zebar.ps1" -Action install -ConfigPath $ZebarPath -DryRun:$DryRun -Force:$Force
}
