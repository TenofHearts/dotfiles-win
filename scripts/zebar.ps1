[CmdletBinding()]
param(
    [ValidateSet('install', 'status', 'build')][string]$Action = 'status',
    [string]$ConfigPath = (Join-Path $HOME '.glzr/zebar/settings.json'),
    [string]$BuildPath,
    [string]$PackPath,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if (-not $BuildPath) { $BuildPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.test-output/menubar-build' }
$source = [IO.Path]::GetFullPath((Join-Path (Split-Path $PSScriptRoot -Parent) 'config/zebar/settings.json'))
$destination = [IO.Path]::GetFullPath($ConfigPath)
function Invoke-MenubarPack {
    param([string]$Action, [string]$BuildPath, [string]$PackPath, [switch]$DryRun)
    $repo = Split-Path $PSScriptRoot -Parent
    $custom = Join-Path $repo 'config/zebar/menubar'
    $buildRoot = [IO.Path]::GetFullPath($BuildPath).TrimEnd('\')
    $packRoot = [IO.Path]::GetFullPath($PackPath).TrimEnd('\')
    foreach ($target in @($buildRoot, $packRoot)) {
        if ($target -ieq $repo -or $repo.StartsWith($target + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $target.StartsWith($custom + '\', [StringComparison]::OrdinalIgnoreCase) -or $target -ieq $custom) {
            throw 'Build and pack destinations must not overlap the source directory or contain the repository.'
        }
    }
    if ($packRoot -ieq $buildRoot -or $buildRoot.StartsWith($packRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
        $packRoot.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Build and pack directories must not overlap.' }
    $inputs = @(Get-ChildItem -LiteralPath $custom -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](node_modules|dist)[\\/]' } | Sort-Object FullName)
    $fingerprint = ($inputs | ForEach-Object { $_.FullName.Substring($custom.Length) + ':' + (Get-FileHash $_.FullName -Algorithm SHA256).Hash }) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $sourceHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint))).Replace('-', '') }
    finally { $sha.Dispose() }
    $recordPath = Join-Path $packRoot 'dotfiles-build.json'
    if (Test-Path -LiteralPath $packRoot) {
        if (-not (Test-Path -LiteralPath $recordPath)) { throw 'Refusing to replace an unrelated pack directory.' }
        $record = Get-Content $recordPath -Raw | ConvertFrom-Json
        if ($record.pack -ne 'dotfiles-menubar') { throw 'Pack destination belongs to another widget.' }
    }
    if ($Action -eq 'status') {
        if (-not (Test-Path $recordPath)) { throw 'Menu bar has not been installed. Run -Action install.' }
        if ($record.sourceHash -ne $sourceHash) { throw 'Installed menu bar differs from source. Run -Action install.' }
        foreach ($entry in $record.files.PSObject.Properties) {
            $installed = Join-Path $packRoot $entry.Name
            if (-not (Test-Path -LiteralPath $installed -PathType Leaf) -or (Get-FileHash $installed).Hash -ne $entry.Value) { throw "Installed file differs: $($entry.Name)" }
        }
        Write-Output "OK $packRoot (standalone menu bar)"
        return
    }
    Write-Output "Build standalone menu bar: $buildRoot"
    if ($DryRun) { Write-Output "Pack: $packRoot"; return }
    New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
    foreach ($name in @('package.json', 'package-lock.json', 'index.html', 'vite.config.ts', 'tsconfig.json', 'src', 'public')) {
        Copy-Item -LiteralPath (Join-Path $custom $name) -Destination $buildRoot -Recurse -Force
    }
    Push-Location $buildRoot
    try {
        & npm.cmd ci --no-audit --no-fund
        if ($LASTEXITCODE) { throw 'Dependency installation failed.' }
        & npm.cmd run check
        if ($LASTEXITCODE) { throw 'Svelte validation failed.' }
        & npm.cmd test
        if ($LASTEXITCODE) { throw 'Menu bar tests failed.' }
        & npm.cmd run build
        if ($LASTEXITCODE) { throw 'Menu bar build failed.' }
    } finally { Pop-Location }
    $output = Join-Path $buildRoot 'dist'
    Copy-Item -LiteralPath (Join-Path $custom 'zpack.json') -Destination $output -Force
    $hashes = [ordered]@{}
    Get-ChildItem $output -Recurse -File | Where-Object Name -ne 'dotfiles-build.json' | ForEach-Object {
        $hashes[$_.FullName.Substring($output.Length + 1)] = (Get-FileHash $_.FullName).Hash
    }
    @{ pack = 'dotfiles-menubar'; sourceHash = $sourceHash; files = $hashes; builtAt = [DateTime]::UtcNow.ToString('o') } |
        ConvertTo-Json -Depth 5 | Set-Content (Join-Path $output 'dotfiles-build.json')
    if ($Action -eq 'build') { Write-Output "Built: $output"; return }
    # Verify the resolved pack path before replacing its contents.
    foreach ($target in @($packRoot)) {
        $cursor = $target
        while ($cursor) {
            $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
            if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked pack path needs review: $cursor" }
            $cursor = Split-Path $cursor -Parent
        }
    }
    if (Test-Path -LiteralPath $packRoot) { Remove-Item -LiteralPath $packRoot -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $packRoot | Out-Null
    Copy-Item -Path (Join-Path $output '*') -Destination $packRoot -Recurse -Force
    Write-Output "Installed: $packRoot. Restart Zebar to load the menu bar."
}

if (-not $PackPath) { $PackPath = Join-Path (Split-Path $destination -Parent) 'dotfiles-menubar' }
if ($Action -in @('install', 'status', 'build')) {
    Invoke-MenubarPack -Action $Action -BuildPath $BuildPath -PackPath $PackPath -DryRun:$DryRun
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
if (Test-Path -LiteralPath $destination) { Remove-Item -LiteralPath $destination -Force }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
New-Item -ItemType SymbolicLink -Path $destination -Target $source | Out-Null
