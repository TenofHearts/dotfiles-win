# Exercise skip and forced replacement behavior entirely inside a temporary workspace fixture.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('.test-output/installers-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
try {
    # Exercise the main entry point, including --force forwarding and dry-run safety.
    $entry = Join-Path $fixture 'entry'
    New-Item -ItemType Directory -Path "$entry/nvim" -Force | Out-Null
    $targets = @{
        ProfilePath = "$entry/profile.ps1"; NvimPath = "$entry/nvim"
        CodexPath = "$entry/codex.toml"; GitPath = "$entry/gitconfig"
        TerminalPath = "$entry/terminal.json"; GlazeWMPath = "$entry/glazewm.yaml"
        ZebarPath = "$entry/zebar.json"
    }
    foreach ($key in $targets.Keys | Where-Object { $_ -ne 'NvimPath' }) {
        Set-Content -LiteralPath $targets[$key] $(if ($key -eq 'TerminalPath') { '{}' } else { '# existing configuration' })
    }
    $beforeEntry = @(Get-ChildItem $entry -File | Get-FileHash | Select-Object -ExpandProperty Hash) -join '|'
    $skipped = & "$root/install.ps1" @targets
    Assert (@($skipped | Where-Object { $_ -like 'SKIP existing target:*' }).Count -eq 7) 'Main installer did not skip every existing target.'
    $preview = & "$root/install.ps1" @targets --force -DryRun
    Assert (@($preview | Where-Object { $_ -like 'SKIP*' }).Count -eq 0) 'Main installer did not forward --force.'
    Assert (((@(Get-ChildItem $entry -File | Get-FileHash | Select-Object -ExpandProperty Hash) -join '|')) -eq $beforeEntry) 'Main installer changed files during skip or forced dry run.'
    Assert (@(Get-ChildItem $entry -Force).Count -eq 7) 'Main installer created artifacts during skip or dry run.'
    Remove-Item -LiteralPath $entry -Recurse -Force
    # Every installer must skip existing targets, even malformed or unrelated files.
    foreach ($name in @('links', 'nvim', 'codex', 'git', 'terminal', 'glazewm', 'zebar')) {
        $existing = Join-Path $fixture "$name-existing"
        Set-Content -LiteralPath $existing 'keep existing content'
        $beforeSkip = (Get-FileHash $existing).Hash
        $options = @{ Action = 'install' }
        $options[$(if ($name -eq 'links') { 'ProfilePath' } else { 'ConfigPath' })] = $existing
        $output = & "$root/scripts/$name.ps1" @options
        Assert (($output -join "`n") -like '*SKIP existing target*') "$name did not report a skipped target."
        Assert ((Get-FileHash $existing).Hash -eq $beforeSkip) "$name changed an existing target without Force."
        Remove-Item -LiteralPath $existing
    }
    $profile = Join-Path $fixture 'profile.ps1'
    Set-Content -LiteralPath $profile -Value '# previous profile'
    $before = (Get-FileHash $profile).Hash
    & "$root/scripts/links.ps1" -Action install -Force -ProfilePath $profile -DryRun | Out-Null
    Assert ((Get-FileHash $profile).Hash -eq $before) 'Profile dry run changed the destination.'
    & "$root/scripts/links.ps1" -Action install -Force -ProfilePath $profile | Out-Null
    & "$root/scripts/links.ps1" -Action status -ProfilePath $profile | Out-Null
    $installed = (Get-FileHash $profile).Hash
    & "$root/scripts/links.ps1" -Action install -Force -ProfilePath $profile | Out-Null
    Assert ((Get-FileHash $profile).Hash -eq $installed) 'Profile install is not idempotent.'
    $nvim = Join-Path $fixture 'nvim'
    New-Item -ItemType Directory -Path $nvim | Out-Null
    Set-Content (Join-Path $nvim 'old.lua') 'old configuration'
    & "$root/scripts/nvim.ps1" -Action install -Force -ConfigPath $nvim -DryRun | Out-Null
    Assert (Test-Path (Join-Path $nvim 'old.lua')) 'Neovim dry run changed the destination.'
    & "$root/scripts/nvim.ps1" -Action install -Force -ConfigPath $nvim | Out-Null
    & "$root/scripts/nvim.ps1" -Action status -ConfigPath $nvim | Out-Null
    & "$root/scripts/nvim.ps1" -Action install -Force -ConfigPath $nvim | Out-Null
    Assert ((Get-Item $nvim).LinkType -eq 'Junction') 'Neovim junction not installed.'
    # Inspect only the fixture root: do not recurse into the installed junction.
    Assert (@(Get-ChildItem -LiteralPath $fixture -Force).Count -eq 2) 'Unexpected installer artifacts.'
    Assert (Test-Path (Join-Path $root 'config/nvim/init.lua')) 'Neovim source was changed.'
    Write-Output 'PASS: default skip, --force forwarding, replacement, dry-run, idempotence, and artifact checks.'
} finally {
    # Delete the junction itself before removing the verified fixture directory.
    $nvim = Join-Path $fixture 'nvim'
    if ((Get-Item -LiteralPath $nvim -ErrorAction SilentlyContinue).LinkType -eq 'Junction') { [IO.Directory]::Delete($nvim) }
    $resolved = [IO.Path]::GetFullPath($fixture)
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.test-output')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped test output.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
