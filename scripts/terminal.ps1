#Requires -Version 7.3
[CmdletBinding()]
param(
    [ValidateSet('install', 'apply', 'status')][string]$Action = 'status',
    [string]$ConfigPath,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
if (-not $ConfigPath) {
    # Stable Store, Preview Store, and unpackaged installations. Never pick an
    # arbitrary installation when more than one has settings.
    $candidates = @(
        'Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json'
        'Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json'
        'Microsoft/Windows Terminal/settings.json'
    ) | ForEach-Object { Join-Path $env:LOCALAPPDATA $_ } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    if (@($candidates).Count -ne 1) {
        throw 'Open Terminal once to create settings, or specify -ConfigPath (required for multiple installations or portable mode).'
    }
    $ConfigPath = @($candidates)[0]
}
$source = Join-Path (Split-Path $PSScriptRoot -Parent) 'config/windows-terminal/settings.json'
$shared = Get-Content -LiteralPath $source -Raw | ConvertFrom-Json -AsHashtable
if ($shared -isnot [Collections.IDictionary]) { throw 'Shared settings must be a JSON object.' }
# Keep shell discovery, profiles and default-shell selection outside dotfiles.
$allowed = @('alwaysOnTop', 'centerOnLaunch', 'copyFormatting', 'copyOnSelect',
    'launchMode', 'theme', 'profiles', 'actions', 'keybindings', 'schemes', 'themes',
    'initialCols', 'initialRows', 'tabWidthMode', 'showTabsInTitlebar', 'confirmCloseAllTabs')
foreach ($key in $shared.Keys) {
    if ($key -notin $allowed) { throw "Unsupported shared setting: $key" }
}
if ($shared.Contains('profiles')) {
    if ($shared.profiles -isnot [Collections.IDictionary] -or
        @($shared.profiles.Keys | Where-Object { $_ -ne 'defaults' }).Count -gt 0 -or
        $shared.profiles.defaults -isnot [Collections.IDictionary]) {
        throw 'Shared profiles may contain only a defaults object.'
    }
    $appearance = @('colorScheme', 'font', 'opacity', 'useAcrylic', 'padding',
        'cursorShape', 'cursorHeight', 'foreground', 'background', 'selectionBackground',
        'antialiasingMode', 'scrollbarState', 'intenseTextStyle', 'adjustIndistinguishableColors')
    foreach ($key in $shared.profiles.defaults.Keys) {
        if ($key -notin $appearance) { throw "Unsupported shared profile default: $key" }
    }
}
foreach ($spec in @(@('actions', 'id'), @('schemes', 'name'), @('themes', 'name'))) {
    $arrayName, $identity = $spec
    if (-not $shared.Contains($arrayName)) { continue }
    if ($shared[$arrayName] -isnot [array]) { throw "$arrayName must be an array." }
    $seen = @{}
    foreach ($entry in $shared[$arrayName]) {
        if ($entry -isnot [Collections.IDictionary] -or -not $entry[$identity]) {
            throw "Shared $arrayName entries require $identity."
        }
        if ($seen.ContainsKey([string]$entry[$identity])) { throw "Duplicate shared $arrayName $identity." }
        $seen[[string]$entry[$identity]] = $true
        if ($arrayName -eq 'actions' -and $entry.Contains('keys')) {
            throw 'Put shared shortcuts in keybindings, not actions.'
        }
    }
}
$destination = [IO.Path]::GetFullPath($ConfigPath)
if ($destination -ieq [IO.Path]::GetFullPath($source)) { throw 'Destination must not be the shared source file.' }
$cursor = $destination
while ($cursor) {
    $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Linked path needs manual review: $cursor" }
    $cursor = Split-Path $cursor -Parent
}
$exists = Test-Path -LiteralPath $destination
if ($exists -and -not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Destination is not a file: $destination" }
$original = if ($exists) { [IO.File]::ReadAllText($destination) } else { '' }
# PowerShell 7 accepts JSON comments and trailing commas. Rewriting produces
# ordinary JSON.
$local = if ($exists) {
    $original | ConvertFrom-Json -AsHashtable
} else { [ordered]@{} }
if ($local -isnot [Collections.IDictionary]) { throw 'Local settings must be a JSON object.' }
$script:changes = [Collections.Generic.List[string]]::new()

function Test-SameValue {
    param($Left, $Right)
    ($Left | ConvertTo-Json -Depth 100 -Compress) -ceq ($Right | ConvertTo-Json -Depth 100 -Compress)
}

function Merge-Object {
    param([Collections.IDictionary]$Target, [Collections.IDictionary]$Overlay, [string]$Prefix)
    foreach ($key in $Overlay.Keys) {
        $path = if ($Prefix) { "$Prefix.$key" } else { $key }
        if ($Target.Contains($key) -and $Target[$key] -is [Collections.IDictionary] -and
            $Overlay[$key] -is [Collections.IDictionary]) {
            Merge-Object $Target[$key] $Overlay[$key] $path
        } elseif (-not $Target.Contains($key) -or -not (Test-SameValue $Target[$key] $Overlay[$key])) {
            $Target[$key] = $Overlay[$key]
            $script:changes.Add($path)
        }
    }
}

function Merge-NamedArray {
    param($Existing, $Overlay, [string]$Identity, [string]$Name)
    $result = [Collections.Generic.List[object]]::new()
    foreach ($entry in $Existing) { $result.Add($entry) }
    foreach ($entry in $Overlay) {
        $matchingIndexes = @(0..($result.Count - 1) | Where-Object {
            $_ -ge 0 -and $_ -lt $result.Count -and
            $result[$_] -is [Collections.IDictionary] -and $result[$_][$Identity] -ceq $entry[$Identity]
        })
        if ($matchingIndexes.Count -gt 1) { throw "Duplicate local $Name $Identity`: $($entry[$Identity])" }
        if ($matchingIndexes.Count -eq 1) {
            Merge-Object $result[$matchingIndexes[0]] $entry "$Name[$($entry[$Identity])]"
        } else {
            $result.Add($entry)
            $script:changes.Add("$Name[$($entry[$Identity])]")
        }
    }
    $result.ToArray()
}

function Get-KeyIdentity {
    param([string]$Keys)
    # Treat modifier order and case as equivalent.
    (($Keys.ToLowerInvariant().Split('+') | ForEach-Object { $_.Trim() } | Sort-Object) -join '+')
}

if ($shared.Contains('keybindings')) {
    if ($shared.keybindings -isnot [array]) { throw 'keybindings must be an array.' }
    $managedKeys = @{}
    foreach ($binding in $shared.keybindings) {
        if ($binding -isnot [Collections.IDictionary] -or -not $binding.id -or -not $binding.keys) {
            throw 'Shared keybindings require id and keys.'
        }
        foreach ($key in @($binding.keys)) {
            $identity = Get-KeyIdentity $key
            if ($managedKeys.ContainsKey($identity)) { throw "Duplicate shared shortcut: $key" }
            $managedKeys[$identity] = $true
        }
    }
    # Preserve the other shortcuts in bindings with an array of keys. Legacy
    # actions can also carry keys; remove only shared chords from those actions.
    foreach ($name in @('actions', 'keybindings')) {
        $result = [Collections.Generic.List[object]]::new()
        foreach ($entry in $local[$name]) {
            if ($entry -is [Collections.IDictionary] -and $entry.Contains('keys')) {
                $remaining = @($entry.keys | Where-Object { -not $managedKeys.ContainsKey((Get-KeyIdentity $_)) })
                if ($remaining.Count -ne @($entry.keys).Count) {
                    if ($name -eq 'actions') { $script:changes.Add('actions.keys') }
                    if ($remaining.Count -eq 0) {
                        if ($name -eq 'keybindings') { continue }
                        $entry.Remove('keys') | Out-Null
                    } else { $entry.keys = if ($remaining.Count -eq 1) { $remaining[0] } else { $remaining } }
                }
            }
            $result.Add($entry)
        }
        if ($name -eq 'keybindings') {
            foreach ($entry in $shared.keybindings) { $result.Add($entry) }
            if (-not (Test-SameValue $local[$name] $result.ToArray())) { $script:changes.Add('keybindings') }
        }
        if ($local.Contains($name) -or $name -eq 'keybindings') { $local[$name] = $result.ToArray() }
    }
}
foreach ($key in $shared.Keys) {
    if ($key -eq 'keybindings') { continue }
    if ($key -in @('actions', 'schemes', 'themes')) {
        $identity = if ($key -eq 'actions') { 'id' } else { 'name' }
        $local[$key] = @(Merge-NamedArray $local[$key] $shared[$key] $identity $key)
    } else { Merge-Object $local ([ordered]@{ $key = $shared[$key] }) '' }
}
if ($script:changes.Count -eq 0) { Write-Output "OK $destination"; return }
if ($Action -eq 'status') { throw "MISSING/CHANGED shared settings: $($script:changes -join ', ')" }
Write-Output "Update shared settings: $(($script:changes | Select-Object -Unique) -join ', ')"
$content = ($local | ConvertTo-Json -Depth 100) + "`n"
$null = $content | ConvertFrom-Json -AsHashtable
if ($DryRun) { return }
if ($exists -ne (Test-Path -LiteralPath $destination) -or
    ($exists -and [IO.File]::ReadAllText($destination) -cne $original)) { throw 'Terminal settings changed during preparation; run again.' }
New-Item -ItemType Directory -Path (Split-Path $destination -Parent) -Force | Out-Null
$temporary = "$destination.dotfiles-$([Guid]::NewGuid().ToString('N')).tmp"
try {
    [IO.File]::WriteAllText($temporary, $content, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temporary, $destination, $true)
} finally {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary }
}
