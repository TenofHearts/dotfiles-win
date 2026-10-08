#Requires -Version 7.3
# Exercises real configuration scripts against isolated files, never live settings.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$fixture = Join-Path $root ('.test-output/configs-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path "$fixture/scripts", "$fixture/config/git", "$fixture/config/windows-terminal" -Force | Out-Null
Copy-Item "$root/scripts/git.ps1", "$root/scripts/terminal.ps1" -Destination "$fixture/scripts"
Copy-Item "$root/config/git/*" -Destination "$fixture/config/git"
$shared = Get-Content "$root/config/windows-terminal/settings.json" -Raw | ConvertFrom-Json -AsHashtable
$shared.schemes = @(@{ name = 'TestScheme'; background = '#123456' })
$shared.themes = @(@{ name = 'TestTheme'; window = @{ applicationTheme = 'dark' } })
$shared | ConvertTo-Json -Depth 100 | Set-Content "$fixture/config/windows-terminal/settings.json"
$script:checks = 0
function Assert {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Hash {
    param([string]$Path)
    (Get-FileHash -LiteralPath $Path).Hash
}
function Assert-Throws {
    param([scriptblock]$Operation, [string]$Pattern)
    $caught = $null
    try { & $Operation | Out-Null } catch { $caught = $_.Exception.Message }
    Assert ($caught -like $Pattern) "Expected failure matching $Pattern; got $caught"
}
$gitPath = "$fixture/gitconfig"
$originalGit = "# local settings`r`n[user]`r`n name = Local User`r`n email = local@example.test`r`n[core]`r`n pager = cat`r`n[http]`r`n proxy = http://localhost:1234`r`n"
[IO.File]::WriteAllText($gitPath, $originalGit, [Text.UTF8Encoding]::new($true))
$originalHash = Hash $gitPath
& "$fixture/scripts/git.ps1" -Action install -ConfigPath $gitPath -DryRun | Out-Null
Assert ((Hash $gitPath) -eq $originalHash) 'Git dry run changed files.'
& "$fixture/scripts/git.ps1" -Action install -ConfigPath $gitPath | Out-Null
& "$fixture/scripts/git.ps1" -Action status -ConfigPath $gitPath | Out-Null
Assert ([IO.File]::ReadAllText($gitPath).EndsWith($originalGit, [StringComparison]::Ordinal)) 'Original Git settings changed.'
Assert ((git config --file $gitPath --includes --get user.name) -eq 'Local User') 'Git identity changed.'
Assert ((git config --file $gitPath --includes --get core.pager) -eq 'cat') 'Git local override lost.'
Assert ((git config --file $gitPath --includes --get alias.st) -eq 'status -sb') 'Git include not active.'
Assert ((git config --file $gitPath --includes --get core.excludesFile) -eq "$fixture/config/git/ignore".Replace('\', '/')) 'Git ignore path incorrect.'
$installedHash = Hash $gitPath
& "$fixture/scripts/git.ps1" -Action install -ConfigPath $gitPath | Out-Null
Assert ((Hash $gitPath) -eq $installedHash) 'Git install is not idempotent.'
$sharedHash = Hash "$fixture/config/git/config"
git config --file $gitPath core.editor fixture-editor
if ($LASTEXITCODE -ne 0) { throw 'Git CLI edit failed.' }
Assert ((Hash "$fixture/config/git/config") -eq $sharedHash) 'Git CLI edit changed the tracked source.'
$editedHash = Hash $gitPath
& "$fixture/scripts/git.ps1" -Action install -ConfigPath $gitPath | Out-Null
& "$fixture/scripts/git.ps1" -Action status -ConfigPath $gitPath | Out-Null
Assert ((Hash $gitPath) -eq $editedHash -and (git config --file $gitPath --includes --get core.editor) -eq 'fixture-editor') 'Reinstallation lost a Git CLI edit.'
git config --file "$fixture/config/git/config" alias.last 'log -1 --oneline'
Assert ((git config --file $gitPath --includes --get alias.last) -eq 'log -1 --oneline') 'Shared Git edit did not take effect immediately.'
Assert-Throws { & "$fixture/scripts/git.ps1" -Action install -ConfigPath "$fixture/config/git/config" } '*shared source*'

$emptyPath = [IO.Path]::GetFullPath("$fixture/empty-gitconfig")
[IO.File]::WriteAllBytes($emptyPath, [byte[]]@())
& "$fixture/scripts/git.ps1" -Action install -ConfigPath $emptyPath | Out-Null
Assert ((git config --file $emptyPath --includes --get alias.st) -eq 'status -sb') 'Empty file setup failed.'

$ignoreRepo = "$fixture/ignore-check"
New-Item -ItemType Directory -Path $ignoreRepo | Out-Null
git init --quiet $ignoreRepo
if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize ignore fixture.' }
Push-Location $ignoreRepo
try {
    $ignored = @('.venv/pyvenv.cfg', 'venv/bin/python', '__pycache__/module.pyc', '.pytest_cache/cache',
        '.env', '.env.production', '.codex/session.json', '.claude/settings.local.json', '.agents/cache')
    foreach ($path in $ignored) {
        $null = git -c "core.excludesFile=$root/config/git/ignore" check-ignore --no-index -- $path
        Assert ($LASTEXITCODE -eq 0) "Not ignored: $path"
    }
    foreach ($path in @('AGENTS.md', 'CLAUDE.md', '.env.example', '.env.sample', 'pyproject.toml', 'uv.lock')) {
        $null = git -c "core.excludesFile=$root/config/git/ignore" check-ignore --no-index -- $path
        Assert ($LASTEXITCODE -eq 1) "Should remain trackable: $path"
    }
} finally { Pop-Location }

foreach ($distro in @('Ubuntu', 'Debian')) {
    $terminalPath = [IO.Path]::GetFullPath("$fixture/$distro.json")
    $local = [ordered]@{
        defaultProfile = "local-$distro"
        disabledProfileSources = @('Windows.Terminal.Azure')
        profiles = @{
            defaults = @{ font = @{ size = 17 }; historySize = 4321 }
            list = @(@{ name = $distro; guid = "local-$distro"; commandline = "wsl.exe -d $distro"; font = @{ size = 20 } })
        }
        actions = @(
            @{ id = 'Local.find'; command = 'find'; keys = @('c+ctrl', 'ctrl+f') }
            @{ id = 'Local.newTab'; command = 'newTab' }
        )
        keybindings = @(
            @{ id = 'Local.copy'; keys = @('CTRL+C', 'ctrl+shift+c') }
            @{ id = 'Local.newTab'; keys = 'ctrl+shift+t' }
        )
        schemes = @(@{ name = 'LocalScheme'; background = '#abcdef' }, @{ name = 'TestScheme'; background = '#000000' })
        themes = @(@{ name = 'LocalTheme'; window = @{ applicationTheme = 'light' } })
    }
    # JSONC, including a trailing comma, must survive semantically.
    $text = '// local settings' + "`r`n" + (($local | ConvertTo-Json -Depth 100) -replace '\}\s*$', ',}')
    [IO.File]::WriteAllText($terminalPath, $text)
    $originalHash = Hash $terminalPath
    & "$fixture/scripts/terminal.ps1" -Action apply -ConfigPath $terminalPath -DryRun | Out-Null
    Assert ((Hash $terminalPath) -eq $originalHash) 'Terminal dry run changed file.'
    & "$fixture/scripts/terminal.ps1" -Action apply -ConfigPath $terminalPath | Out-Null
    $merged = Get-Content $terminalPath -Raw | ConvertFrom-Json -AsHashtable
    Assert ($merged.defaultProfile -eq "local-$distro" -and $merged.profiles.list[0].commandline -eq "wsl.exe -d $distro") 'Local shell profile changed.'
    Assert ($merged.disabledProfileSources[0] -eq 'Windows.Terminal.Azure') 'Profile discovery configuration changed.'
    Assert ($merged.profiles.defaults.font.size -eq 17 -and $merged.profiles.defaults.font.face -eq '0xProto Nerd Font' -and $merged.profiles.defaults.historySize -eq 4321) 'Recursive defaults merge failed.'
    Assert ($merged.profiles.list[0].font.size -eq 20) 'Per-profile override changed.'
    Assert (@($merged.keybindings | Where-Object keys -eq 'ctrl+c').Count -eq 1) 'Shared shortcut missing.'
    Assert (@($merged.keybindings | Where-Object keys -eq 'ctrl+shift+c').Count -eq 1 -and @($merged.keybindings | Where-Object keys -eq 'ctrl+shift+t').Count -eq 1) 'Local shortcuts lost.'
    Assert (($merged.actions | Where-Object id -eq 'Local.find').keys -eq 'ctrl+f') 'Legacy multi-key action merge failed.'
    Assert ($merged.schemes.Count -eq 2 -and ($merged.schemes | Where-Object name -eq 'TestScheme').background -eq '#123456' -and $merged.themes.Count -eq 2) 'Named array merge failed.'
    $installedHash = Hash $terminalPath
    & "$fixture/scripts/terminal.ps1" -Action apply -ConfigPath $terminalPath | Out-Null
    & "$fixture/scripts/terminal.ps1" -Action status -ConfigPath $terminalPath | Out-Null
    Assert ((Hash $terminalPath) -eq $installedHash) 'Terminal merge is not idempotent.'
}
$shared.profiles.list = @(@{ name = 'Do not distribute' })
$shared | ConvertTo-Json -Depth 100 | Set-Content "$fixture/config/windows-terminal/settings.json"
Assert-Throws { & "$fixture/scripts/terminal.ps1" -Action apply -ConfigPath "$fixture/Ubuntu.json" } '*only a defaults*'
Assert (@(Get-ChildItem -LiteralPath $fixture -Recurse -Filter manifest.json).Count -eq 0) 'Unexpected backup manifest.'
Assert (@(Get-ChildItem -LiteralPath $fixture -Recurse -Filter '*.tmp').Count -eq 0) 'Temporary files were not removed.'
$resolvedFixture = (Resolve-Path -LiteralPath $fixture).Path
$fixtureRoot = [IO.Path]::GetFullPath((Join-Path $root '.test-output')).TrimEnd('\') + '\'
if (-not $resolvedFixture.StartsWith($fixtureRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped test output directory.' }
Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
Write-Output "PASS: $script:checks checks. Test fixtures removed."
