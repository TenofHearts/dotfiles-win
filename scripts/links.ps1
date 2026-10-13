# A small loader avoids Windows symlink privileges while keeping edits live.
[CmdletBinding()]
param(
    [ValidateSet('install', 'status')][string]$Action = 'status',
    [string]$ProfilePath = $PROFILE.CurrentUserCurrentHost,
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

if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source: $source" }
if (Test-Loader $destination $loader) { Write-Output 'Profile loader is already installed.'; return }
if ($destination -ieq [IO.Path]::GetFullPath($source)) { throw 'Profile destination must not be the repository source.' }
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
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
[IO.File]::WriteAllText($destination, $loader, [Text.UTF8Encoding]::new($false))
