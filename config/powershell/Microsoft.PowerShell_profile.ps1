$dotfilesProfileFile = Get-Item -LiteralPath $PSCommandPath -Force
$dotfilesProfileDirectory = $PSScriptRoot
if ($dotfilesProfileFile.LinkType -eq 'SymbolicLink') {
    $dotfilesProfileDirectory = Split-Path ($dotfilesProfileFile.ResolveLinkTarget($true).FullName) -Parent
}
$dotfilesRoot = Split-Path (Split-Path $dotfilesProfileDirectory -Parent) -Parent
$localProfile = Join-Path $HOME '.config/powershell/profile.local.ps1'
# Load private paths before initializing tools.
if (Test-Path -LiteralPath $localProfile) { . $localProfile }
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config (Join-Path $dotfilesRoot 'config/oh-my-posh/theme.omp.json') | Invoke-Expression
}
# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
if (-not $env:FNM_DIR) { $env:FNM_DIR = "D:\Program\fnm" }
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --use-on-cd | Out-String | Invoke-Expression
}

function ga {
    git add @args
}
function gca {
    git commit -a @args
}
function gpu {
    git push @args
}
function gpl {
    git pull @args
}
function glg {
    git log --graph --decorate @args
} 
function cact {
    conda activate @args
}
function cdac {
    conda deactivate
}

Set-Alias ll ls 

Set-Alias which where.exe

if (Get-Command uv -ErrorAction SilentlyContinue) {
    (& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
}
if (Get-Command uvx -ErrorAction SilentlyContinue) {
    (& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression
}

$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"

if (-not $env:UV_CACHE_DIR) { $env:UV_CACHE_DIR = "D:\Program\uv\cache" }
if (-not $env:UV_PYTHON_INSTALL_DIR) { $env:UV_PYTHON_INSTALL_DIR = "D:\Program\uv\python" }
if (-not $env:UV_TOOL_DIR) { $env:UV_TOOL_DIR = "D:\Program\uv\tools" }
if (-not $env:UV_TOOL_BIN_DIR) { $env:UV_TOOL_BIN_DIR = "D:\Program\uv\tools-bin" }

function uvac {
    if (-Not (Test-Path -Path ".venv")) {
        Write-Host ".venv folder does not exist in the current directory." -ForegroundColor Red
        return
    }
    .venv\Scripts\activate
}

function uvi {
    $hadMainPy = Test-Path -LiteralPath "main.py"
    uv init --no-readme --vcs none @args
    if (-Not $hadMainPy -and (Test-Path -LiteralPath "main.py")) {
        Remove-Item -LiteralPath "main.py" -Force
    }
}

function uva {
    uv add @args
}

function uvr {
    uv run @args
}

function cg {
    cargo @args
}
function cgi {
    cargo init @args --vcs none
}
function cgn {
    cargo new @args --vcs none
}
function cgb {
    cargo build @args
}
function cgbr {
    cargo build --release @args
}
function cgr {
    cargo run @args
}
function cgrr {
    cargo run --release @args
}
function cga {
    cargo add @args
}
