[CmdletBinding()]
param(
    [ValidateSet('install', 'status', 'restore', 'build')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $HOME '.glzr/zebar/settings.json'),
    [string]$StatePath = (Join-Path $HOME '.local/state/dotfiles-win'),
    [string]$Manifest,
    [string]$BuildPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.test-output/neosoft-build'),
    [string]$PackPath,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$source = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'config/zebar/settings.json'))
$destination = [IO.Path]::GetFullPath($ConfigPath)
function Invoke-NeosoftPack {
[CmdletBinding()]
param(
    [ValidateSet('build','install','status')][string]$Action = 'status',
    [string]$BuildPath = (Join-Path (Split-Path $PSScriptRoot -Parent) '.test-output/neosoft-build'),
    [string]$PackPath = (Join-Path $HOME '.glzr/zebar/dotfiles-neosoft'),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$custom = Join-Path $repo 'config/zebar/neosoft'
$pin = Get-Content (Join-Path $custom 'upstream.json') -Raw | ConvertFrom-Json
$buildRoot = [IO.Path]::GetFullPath($BuildPath)
$packRoot = [IO.Path]::GetFullPath($PackPath)
$source = Join-Path $buildRoot "neosoft-zebar-$($pin.revision)"
if ($packRoot -ieq $repo -or $repo.StartsWith($packRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Pack destination cannot contain the dotfiles repository.' }
if ((Test-Path -LiteralPath $packRoot) -and -not (Test-Path -LiteralPath (Join-Path $packRoot 'dotfiles-build.json'))) { throw 'Refusing to replace an unrelated directory; choose a new pack destination.' }
if ($Action -eq 'status') {
    $recordPath = Join-Path $packRoot 'dotfiles-build.json'
    if (-not (Test-Path -LiteralPath $recordPath)) { throw 'Neosoft pack has not been installed. Run -Action install.' }
    $record = Get-Content $recordPath -Raw | ConvertFrom-Json
    if ($record.revision -ne $pin.revision) { throw 'Installed upstream revision differs from dotfiles.' }
    $installedConfig = Join-Path $packRoot 'zpack.json'
    $expectedConfig = Join-Path $custom 'zpack.json'
    if (-not (Test-Path -LiteralPath $installedConfig -PathType Leaf) -or
        (Get-FileHash -LiteralPath $installedConfig -Algorithm SHA256).Hash -ne
        (Get-FileHash -LiteralPath $expectedConfig -Algorithm SHA256).Hash) {
        throw 'Installed widget configuration differs from dotfiles. Run -Action install and restart Zebar.'
    }
    Write-Output "OK $packRoot (Neosoft $($record.revision))"
    return
}
Write-Output "Build Neosoft $($pin.revision) with dotfiles adaptations"
if ($DryRun) { Write-Output "Build: $buildRoot; pack: $packRoot"; return }
# Work only in a dedicated build directory. Never delete a user supplied tree.
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$archive = Join-Path $buildRoot 'upstream.zip'
if (-not (Test-Path $archive) -or (Get-FileHash $archive -Algorithm SHA256).Hash -ine $pin.archiveSha256) {
    Invoke-WebRequest "https://codeload.github.com/blaiyz/neosoft-zebar/zip/$($pin.revision)" -OutFile $archive
}
if ((Get-FileHash $archive -Algorithm SHA256).Hash -ine $pin.archiveSha256) { throw 'Upstream archive checksum mismatch.' }
Expand-Archive -LiteralPath $archive -DestinationPath $buildRoot -Force
& node (Join-Path $custom 'patch-upstream.mjs') $source
if ($LASTEXITCODE) { throw 'Neosoft adaptation failed.' }
Copy-Item -Path (Join-Path $custom 'overlay/*') -Destination $source -Recurse -Force
if (Test-Path (Join-Path $custom 'package-lock.json')) { Copy-Item (Join-Path $custom 'package-lock.json') (Join-Path $source 'package-lock.json') -Force }
Push-Location $source
try {
    & npm.cmd ci --no-audit --no-fund
    if ($LASTEXITCODE) { throw 'Dependency installation failed.' }
    & npm.cmd run check
    if ($LASTEXITCODE) { throw 'Svelte validation failed.' }
    & npm.cmd run build
    if ($LASTEXITCODE) { throw 'Neosoft build failed.' }
} finally { Pop-Location }
$output = Join-Path $source 'build'
Copy-Item (Join-Path $custom 'zpack.json') (Join-Path $output 'zpack.json') -Force
Copy-Item (Join-Path $source 'LICENSE*') $output -Force
@{revision=$pin.revision; builtAt=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $output 'dotfiles-build.json')
if ($Action -eq 'build') { Write-Output "Built: $output"; return }
if ($packRoot -ieq $buildRoot -or $buildRoot.StartsWith($packRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Pack destination cannot contain the build directory.' }
if (Test-Path -LiteralPath $packRoot) {
    $item = Get-Item -LiteralPath $packRoot -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Refusing to replace a linked pack directory.' }
    $backup = Join-Path $HOME ".local/state/dotfiles-win/backups/neosoft-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss-fffffff'))"
    New-Item -ItemType Directory -Force (Split-Path $backup -Parent) | Out-Null
    Move-Item -LiteralPath $packRoot -Destination $backup
    Write-Output "Previous pack backup: $backup"
}
try {
    New-Item -ItemType Directory -Force -Path $packRoot | Out-Null
    Copy-Item -Path (Join-Path $output '*') -Destination $packRoot -Recurse -Force
} catch {
    Write-Output 'Installation failed; the previous pack is preserved in its backup directory.'
    throw
}
Write-Output "Installed: $packRoot. Restart Zebar to load the three pills."

}

if (-not $PackPath) { $PackPath = Join-Path (Split-Path $destination -Parent) 'dotfiles-neosoft' }
if ($Action -in @('install','status','build')) {
    Invoke-NeosoftPack -Action $Action -BuildPath $BuildPath -PackPath $PackPath -DryRun:$DryRun
    if ($Action -eq 'build') { return }
}

function Test-ZebarLink {
    param([string]$Path, [string]$Target)
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    $item -and $item.LinkType -eq 'SymbolicLink' -and
        [IO.Path]::GetFullPath([string]$item.Target).TrimEnd('\') -ieq $Target.TrimEnd('\')
}

if ($Action -eq 'status') {
    if (Test-ZebarLink $destination $source) { Write-Output "OK $destination -> $source" }
    else { throw "MISSING/CHANGED $destination" }
    return
}
if ($Action -eq 'restore') {
    if (-not $Manifest) { throw 'Restore requires -Manifest.' }
    $record = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    if ($record.kind -ne 'zebar-symlink') { throw 'Not a Zebar backup manifest.' }
    if (-not (Test-ZebarLink $record.destination $record.source)) {
        throw "Refusing to replace a changed Zebar config: $($record.destination)"
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
    throw 'Zebar config missing from the repository.'
}
if (Test-ZebarLink $destination $source) { Write-Output 'Zebar symlink is already installed.'; return }
if ($destination -ieq $source -or $source.StartsWith($destination.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Zebar destination must not contain the configuration source.'
}
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path needs manual review: $cursor" }
    $cursor = Split-Path $cursor -Parent
}
if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw 'Zebar destination is not a file.'
}
Write-Output "Install Zebar symlink: $destination -> $source"
if ($DryRun) { return }
$stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss-fffffff')
$backup = $null
$manifestDirectory = Join-Path $StatePath "backups/zebar-$stamp"
New-Item -ItemType Directory -Path $manifestDirectory -Force | Out-Null
if (Test-Path -LiteralPath $destination) { $backup = "$destination.dotfiles-backup-$stamp" }
$manifestPath = Join-Path $manifestDirectory 'manifest.json'
@{ kind = 'zebar-symlink'; destination = $destination; source = $source; backup = $backup } |
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
