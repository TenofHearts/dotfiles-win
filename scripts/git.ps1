#Requires -Version 7.3
[CmdletBinding()]
param(
    [ValidateSet('install', 'status')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $HOME '.gitconfig'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = [IO.Path]::GetFullPath((Join-Path $root 'config/git/config'))
$ignore = [IO.Path]::GetFullPath((Join-Path $root 'config/git/ignore'))
foreach ($path in @($source, $ignore)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing source: $path" }
}
$destination = [IO.Path]::GetFullPath($ConfigPath)
if ($destination -ieq $source -or $destination -ieq $ignore) { throw 'Destination must not be a shared source file.' }
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path needs manual review: $cursor" }
    $cursor = Split-Path $cursor -Parent
}
$exists = Test-Path -LiteralPath $destination
if ($exists -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Destination is not a file: $destination" }
$local = if ($exists) { [IO.File]::ReadAllText($destination) } else { '' }
$includes = @()
$localIgnore = @()
if ($exists) {
    $includes = @(git config --file $destination --no-includes --path --get-all include.path)
    if ($LASTEXITCODE -notin @(0, 1)) { throw 'Unable to parse local Git configuration.' }
    $localIgnore = @(git config --file $destination --no-includes --path --get core.excludesFile)
    if ($LASTEXITCODE -notin @(0, 1)) { throw 'Unable to read local Git ignore setting.' }
}
$included = $false
foreach ($path in $includes) {
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path (Split-Path $destination -Parent) $path }
    if ([IO.Path]::GetFullPath($path) -ieq $source) { $included = $true }
}
if ($included -and $localIgnore.Count -gt 0) {
    Write-Output "OK $destination includes $source"
    if ($localIgnore[0].Replace('\', '/') -ine $ignore.Replace('\', '/')) {
        Write-Output "Local core.excludesFile takes precedence: $($localIgnore[0])"
    }
    return
}
if ($Action -eq 'status') { throw "MISSING shared Git include or global ignore setting: $destination" }
# Only prepend missing defaults. Git CLI edits and all existing local sections
# are preserved, including settings inserted into these sections by Git itself.
$prefix = ''
if (-not $included) {
    $quotedSource = $source.Replace('\', '/').Replace('"', '\"')
    $prefix += "[include]`n    path = `"$quotedSource`"`n"
}
if ($localIgnore.Count -eq 0) {
    $quotedIgnore = $ignore.Replace('\', '/').Replace('"', '\"')
    $prefix += "[core]`n    excludesFile = `"$quotedIgnore`"`n"
} else { Write-Output 'Preserving existing local core.excludesFile.' }
Write-Output "Apply Git preferences: $destination"
if ($DryRun) { return }
if ($exists -ne (Test-Path -LiteralPath $destination) -or
    ($exists -and [IO.File]::ReadAllText($destination) -cne $local)) { throw 'Git config changed during preparation; run again.' }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
$temporary = "$destination.dotfiles-$([Guid]::NewGuid().ToString('N')).tmp"
try {
    [IO.File]::WriteAllText($temporary, $prefix + $local, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $destination, $true)
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
