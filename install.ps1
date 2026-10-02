[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win')
)
& "$PSScriptRoot/scripts/links.ps1" -Action install -ProfilePath $ProfilePath -StatePath $StatePath -DryRun:$DryRun
