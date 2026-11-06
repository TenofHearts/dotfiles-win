# Exercise Codex linking without touching live settings.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('.test-output/codex-' + [Guid]::NewGuid().ToString('N'))
$destination = Join-Path $fixture 'dotfiles.config.toml'
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
try {
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    Set-Content $destination 'previous profile'
    Set-Content (Join-Path $fixture 'config.toml') '# local configuration'
    Set-Content (Join-Path $fixture 'auth.json') 'local credentials'
    $localHash = (Get-FileHash (Join-Path $fixture 'config.toml')).Hash
    $authHash = (Get-FileHash (Join-Path $fixture 'auth.json')).Hash
    $before = (Get-FileHash $destination).Hash
    & "$root/scripts/codex.ps1" -Action install -ConfigPath $destination -DryRun | Out-Null
    Assert ((Get-FileHash $destination).Hash -eq $before) 'Dry run changed the profile.'
    & "$root/scripts/codex.ps1" -Action install -ConfigPath $destination | Out-Null
    & "$root/scripts/codex.ps1" -Action status -ConfigPath $destination | Out-Null
    & "$root/scripts/codex.ps1" -Action install -ConfigPath $destination | Out-Null
    Assert ((Get-Item $destination).LinkType -eq 'SymbolicLink') 'Profile is not linked.'
    # Repair both existing and dangling links left by a submodule layout change.
    $oldSource = Join-Path $fixture 'old-profile.toml'
    Set-Content $oldSource 'old shared profile'
    foreach ($dangling in @($false, $true)) {
        [IO.File]::Delete($destination)
        New-Item -ItemType SymbolicLink -Path $destination -Target $oldSource | Out-Null
        if ($dangling) { Remove-Item -LiteralPath $oldSource }
        & "$root/scripts/codex.ps1" -Action install -ConfigPath $destination -DryRun | Out-Null
        Assert ((Get-Item -LiteralPath $destination -Force).Target -eq $oldSource) 'Dry run replaced a stale link.'
        & "$root/scripts/codex.ps1" -Action install -ConfigPath $destination | Out-Null
        & "$root/scripts/codex.ps1" -Action status -ConfigPath $destination | Out-Null
        if (-not $dangling) { Assert ((Get-Content $oldSource) -eq 'old shared profile') 'Link repair modified the previous target.' }
    }
    Assert ((Get-FileHash (Join-Path $fixture 'config.toml')).Hash -eq $localHash) 'Local configuration changed.'
    Assert ((Get-FileHash (Join-Path $fixture 'auth.json')).Hash -eq $authHash) 'Credentials changed.'
    $rejected = $false
    try { & "$root/scripts/codex.ps1" -Action install -ConfigPath "$root/config/ai/codex/dotfiles.config.toml" | Out-Null } catch { $rejected = $_.Exception.Message -like '*configuration source*' }
    Assert $rejected 'Source overlap was not rejected.'
    # Extract only the wrapper to avoid initializing interactive profile tools.
    $ast = [System.Management.Automation.Language.Parser]::ParseFile("$root/config/powershell/Microsoft.PowerShell_profile.ps1", [ref]$null, [ref]$null)
    $wrapper = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'codex' }, $true)
    Assert ($null -ne $wrapper) 'Codex wrapper missing.'
    & {
        function Get-Command { [pscustomobject]@{ Source = { $args } } }
        . ([scriptblock]::Create($wrapper.Extent.Text))
        $forwarded = @(codex exec 'argument with spaces' --help)
        Assert (($forwarded -join '|') -eq '--profile|dotfiles|exec|argument with spaces|--help') 'Wrapper lost or changed arguments.'
    }
    Write-Output 'PASS: Codex dry run, link repair, idempotence, local data preservation, overlap protection, and argument forwarding.'
} finally {
    if ((Get-Item -LiteralPath $destination -Force -ErrorAction SilentlyContinue).LinkType -eq 'SymbolicLink') { [IO.File]::Delete($destination) }
    $resolved = [IO.Path]::GetFullPath($fixture)
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.test-output')).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped test output.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
