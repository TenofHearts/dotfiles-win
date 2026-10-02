[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win'),
    [string]$NvimPath = (Join-Path $env:LOCALAPPDATA 'nvim'),
    [switch]$SkipNvim
)
& "$PSScriptRoot/scripts/links.ps1" -Action install -ProfilePath $ProfilePath -StatePath $StatePath -DryRun:$DryRun
if (-not $SkipNvim) {
    & "$PSScriptRoot/scripts/nvim.ps1" -Action install -ConfigPath $NvimPath -StatePath $StatePath -DryRun:$DryRun
}
