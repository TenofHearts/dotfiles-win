#Requires -Version 7.3
# Package managers are mocked: these checks never install or download software.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scriptPath = Join-Path $root 'scripts/packages.ps1'
$fixture = Join-Path $root ('.test-output/packages-' + [Guid]::NewGuid().ToString('N'))
$global:packageTestCalls = [Collections.Generic.List[string]]::new()
$global:packageTestPresent = $false
$global:packageTestOwned = $false
$global:packageTestListError = 0
$global:packageTestOperationError = 0
$checks = 0
function Assert($Condition, $Message) {
    if (-not $Condition) { throw $Message }
    $script:checks++
}
function Get-Command {
    [CmdletBinding()]
    param([string]$Name, $CommandType)
    if ($Name -eq 'fzf') {
        if ($global:packageTestPresent) { [pscustomobject]@{ Source = 'fixture/fzf' } }
        return
    }
    Microsoft.PowerShell.Core\Get-Command @PSBoundParameters
}
function winget {
    $global:packageTestCalls.Add('winget ' + ($args -join ' '))
    if ($args[0] -eq 'list') {
        $global:LASTEXITCODE = if ($global:packageTestListError) { $global:packageTestListError } elseif ($global:packageTestOwned) { 0 } else { -1978335212 }
    } else { $global:LASTEXITCODE = $global:packageTestOperationError }
}
try {
    $result = & $scriptPath -Only fzf
    Assert ($result.Status -eq 'Missing') 'Offline inventory should show the missing executable.'
    Assert ($global:packageTestCalls.Count -eq 0) 'Default inventory contacted a package manager.'
    $result = & $scriptPath -Only fzf -InstallMissing -Upgrade -DryRun
    Assert ($global:packageTestCalls.Count -eq 0) 'Dry run contacted a package manager.'
    $result = & $scriptPath -Only fzf -InstallMissing
    Assert (@($global:packageTestCalls | Where-Object { $_ -like 'winget install --id junegunn.fzf --exact*' }).Count -eq 1) 'Missing package was not installed exactly once.'

    $global:packageTestCalls.Clear()
    $result = & $scriptPath -Only fzf -Upgrade
    Assert (@($global:packageTestCalls | Where-Object { $_ -like 'winget install*' -or $_ -like 'winget upgrade*' }).Count -eq 0) 'Upgrade-only installed a missing tool.'

    $global:packageTestPresent = $true
    $global:packageTestCalls.Clear()
    $result = & $scriptPath -Only fzf -InstallMissing -Upgrade
    Assert ($result.Status -eq 'Skip upgrade (not manager-owned)') 'Unmanaged tool was not preserved.'
    Assert ($global:packageTestCalls.Count -eq 1) 'An unmanaged tool was installed or upgraded.'

    $global:packageTestOwned = $true
    $global:packageTestPresent = $false
    $global:packageTestCalls.Clear()
    $result = & $scriptPath -Only fzf -InstallMissing
    Assert ($result.Status -eq 'Present') 'Manager-owned package absent from PATH was treated as missing.'
    Assert ($global:packageTestCalls.Count -eq 1) 'Manager-owned package was reinstalled.'
    $global:packageTestOperationError = -1978335189
    $result = & $scriptPath -Only fzf -Upgrade
    Assert ($result.Status -eq 'Upgrade') 'No-applicable-update result was treated as failure.'
    $global:packageTestOperationError = 0

    $global:packageTestListError = 123
    $global:packageTestCalls.Clear()
    $threw = $false
    try { & $scriptPath -Only fzf -InstallMissing | Out-Null } catch { $threw = $true }
    Assert $threw 'Ownership-query failure should stop installation.'
    Assert ($global:packageTestCalls.Count -eq 1) 'Failed ownership lookup triggered an install.'
    $global:packageTestListError = 0

    & $scriptPath -Group dotfiles -ExportDirectory $fixture | Out-Null
    $export = Get-Content (Join-Path $fixture 'winget.json') -Raw | ConvertFrom-Json
    Assert (@($export.Sources[0].Packages).Count -eq 12) 'Dotfiles group export has the wrong packages.'
    Assert ('junegunn.fzf' -in $export.Sources[0].Packages.PackageIdentifier) 'fzf missing from export.'
    $threw = $false
    try { & $scriptPath -Only 'Unknown package' | Out-Null } catch { $threw = $true }
    Assert $threw 'Unknown package selection did not fail.'
    Write-Output "PASS: $checks package checks; no real package operations."
} finally {
    # Restore test-local mocks and delete only the verified fixture directory.
    Remove-Item Function:\Get-Command, Function:\winget
    if (Test-Path -LiteralPath $fixture) {
        $resolved = [IO.Path]::GetFullPath($fixture)
        $allowed = [IO.Path]::GetFullPath((Join-Path $root '.test-output')) + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($allowed, [StringComparison]::OrdinalIgnoreCase)) { throw 'Fixture escaped test output.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
    Remove-Variable packageTestCalls,packageTestPresent,packageTestOwned,packageTestListError,packageTestOperationError -Scope Global
}
