#Requires -Version 7.3
[CmdletBinding()]
param(
    [ValidateSet('dotfiles', 'development')][string[]]$Group = @('dotfiles', 'development'),
    [string[]]$Only,
    [switch]$InstallMissing,
    [switch]$Upgrade,
    [switch]$DryRun,
    [string]$ExportDirectory
)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false
$catalog = (Get-Content (Join-Path $PSScriptRoot '../config/packages/catalog.json') -Raw | ConvertFrom-Json).packages
$selected = @($catalog | Where-Object { $_.group -in $Group -and (-not $Only -or $_.name -in $Only) })
if ($Only) {
    foreach ($name in $Only) {
        if ($name -notin $selected.name) { throw "Unknown package or excluded group: $name" }
    }
}
if (-not $IsWindows) { throw 'WinGet requires Windows.' }

# Native exports describe the selection, not this machine's full application list.
if ($ExportDirectory) {
    $null = New-Item -ItemType Directory -Path $ExportDirectory -Force
    $export = [ordered]@{
        '$schema' = 'https://aka.ms/winget-packages.schema.2.0.json'
        Sources = @(@{
            SourceDetails = @{ Argument = 'https://cdn.winget.microsoft.com/cache'; Identifier = 'Microsoft.Winget.Source_8wekyb3d8bbwe'; Name = 'winget'; Type = 'Microsoft.PreIndexed.Package' }
            Packages = @($selected | Where-Object winget | ForEach-Object { @{ PackageIdentifier = $_.winget } })
        })
    }
    $export | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $ExportDirectory 'winget.json') -Encoding utf8
    Write-Output "Exported winget.json to $ExportDirectory"
    if (-not ($InstallMissing -or $Upgrade)) { return }
}

function Find-LocalTool($Package) {
    foreach ($name in $Package.commands) {
        $command = Get-Command $name -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($command) { return $command.Source }
    }
    if ($IsWindows) {
        if ($Package.uninstallName) {
            $keys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
                'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*')
            $installed = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -match $Package.uninstallName } | Select-Object -First 1
            if ($installed) {
                if ($installed.InstallLocation) { return $installed.InstallLocation }
                return "Installed app: $($installed.DisplayName)"
            }
        }
        foreach ($path in $Package.windowsPaths) {
            $expanded = [Environment]::ExpandEnvironmentVariables($path)
            if (Test-Path -LiteralPath $expanded) { return $expanded }
        }
        if ($Package.appx) {
            $app = Get-AppxPackage -Name $Package.appx -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($app) { return $app.InstallLocation }
        }
        if ($Package.font) {
            foreach ($key in @('HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts', 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts')) {
                $fonts = Get-ItemProperty $key -ErrorAction SilentlyContinue
                if ($fonts -and @($fonts.PSObject.Properties.Name | Where-Object { $_ -like "$($Package.font)*" }).Count) { return 'Windows font registry' }
            }
        }
    }
    return $null
}

# Keep inventory/default and dry runs offline. Query package-manager ownership only
# when the caller explicitly asks to install or upgrade.
$mutating = ($InstallMissing -or $Upgrade) -and -not $DryRun
if ($mutating -and -not (Get-Command winget -ErrorAction SilentlyContinue)) { throw 'WinGet is not installed/on PATH. Install it first.' }

$failed = @()
$results = foreach ($package in $selected) {
    $id = $package.winget
    $localPath = Find-LocalTool $package
    $available = [bool]$id
    $present = [bool]$localPath
    $owned = $false
    if ($mutating -and $available) {
        $null = & winget list --id $id --exact --source winget --accept-source-agreements --disable-interactivity 2>&1
        # APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND is the only absence result.
        if ($LASTEXITCODE -eq 0) { $owned = $true }
        elseif ($LASTEXITCODE -ne -1978335212) { throw "Cannot determine WinGet ownership of $id (exit $LASTEXITCODE); refusing to assume it is missing." }
        $present = $present -or $owned
    }
    $action = if ($present) { 'Present' } else { 'Missing' }
    if (-not $available) { $action = if ($present) { 'Present (manual)' } else { 'Manual installation required' } }
    elseif ($Upgrade -and $present) { $action = if ($DryRun) { 'Would check upgrade ownership' } elseif ($owned) { 'Upgrade' } else { 'Skip upgrade (not manager-owned)' } }
    elseif ($InstallMissing -and -not $present) { $action = if ($DryRun) { 'Would install if manager also reports missing' } else { 'Install' } }
    if ($action -in @('Install', 'Upgrade')) {
        $verb = $action.ToLowerInvariant()
        $arguments = @($verb, '--id', $id, '--exact', '--source', 'winget', '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity')
        Write-Host "winget $($arguments -join ' ')"
        & winget @arguments | Out-Host
        $code = $LASTEXITCODE
        # WinGet reports no applicable update as a nonzero success-equivalent.
        if ($code -ne 0 -and -not ($action -eq 'Upgrade' -and $code -eq -1978335189)) {
            $failed += $package.name
            $action = "Failed ($code)"
        }
    }
    [pscustomobject]@{ Name = $package.name; Group = $package.group; Status = $action; Package = $id; Location = $localPath; Note = $package.note }
}
$results
if ($failed.Count) { throw "Package operations failed: $($failed -join ', ')" }
