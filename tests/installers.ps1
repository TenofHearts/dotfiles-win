# Exercise replacement behavior entirely inside a temporary workspace fixture.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('.test-output/installers-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
try {
    $profile = Join-Path $fixture 'profile.ps1'
    Set-Content -LiteralPath $profile -Value '# previous profile'
    $before = (Get-FileHash $profile).Hash
    & "$root/scripts/links.ps1" -Action install -ProfilePath $profile -DryRun | Out-Null
    Assert ((Get-FileHash $profile).Hash -eq $before) 'Profile dry run changed the destination.'
    & "$root/scripts/links.ps1" -Action install -ProfilePath $profile | Out-Null
    & "$root/scripts/links.ps1" -Action status -ProfilePath $profile | Out-Null
    $installed = (Get-FileHash $profile).Hash
    & "$root/scripts/links.ps1" -Action install -ProfilePath $profile | Out-Null
    Assert ((Get-FileHash $profile).Hash -eq $installed) 'Profile install is not idempotent.'
    $nvim = Join-Path $fixture 'nvim'
    New-Item -ItemType Directory -Path $nvim | Out-Null
    Set-Content (Join-Path $nvim 'old.lua') 'old configuration'
    & "$root/scripts/nvim.ps1" -Action install -ConfigPath $nvim -DryRun | Out-Null
    Assert (Test-Path (Join-Path $nvim 'old.lua')) 'Neovim dry run changed the destination.'
    & "$root/scripts/nvim.ps1" -Action install -ConfigPath $nvim | Out-Null
    & "$root/scripts/nvim.ps1" -Action status -ConfigPath $nvim | Out-Null
    & "$root/scripts/nvim.ps1" -Action install -ConfigPath $nvim | Out-Null
    Assert ((Get-Item $nvim).LinkType -eq 'Junction') 'Neovim junction not installed.'
    # Inspect only the fixture root: do not recurse into the installed junction.
    Assert (@(Get-ChildItem -LiteralPath $fixture -Force).Count -eq 2) 'Unexpected installer artifacts.'
    Assert (Test-Path (Join-Path $root 'config/nvim/init.lua')) 'Neovim source was changed.'
    Write-Output 'PASS: replacement, dry-run, idempotence, and artifact checks.'
} finally {
    # Delete the junction itself before removing the verified fixture directory.
    $nvim = Join-Path $fixture 'nvim'
    if ((Get-Item -LiteralPath $nvim -ErrorAction SilentlyContinue).LinkType -eq 'Junction') { [IO.Directory]::Delete($nvim) }
    $resolved = [IO.Path]::GetFullPath($fixture)
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.test-output')).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped test output.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
