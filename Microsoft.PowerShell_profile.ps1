oh-my-posh init pwsh --config $env:POSH_THEMES_PATH'\my_theme.omp.json' | Invoke-Expression
# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}
$env:FNM_DIR = "D:\Program\fnm"
fnm env --use-on-cd | Out-String | Invoke-Expression

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

(& uv generate-shell-completion powershell) | Out-String | Invoke-Expression
(& uvx --generate-shell-completion powershell) | Out-String | Invoke-Expression

$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"

$env:UV_CACHE_DIR = "D:\Program\uv\cache"
$env:UV_PYTHON_INSTALL_DIR = "D:\Program\uv\python"
$env:UV_TOOL_DIR = "D:\Program\uv\tools"
$env:UV_TOOL_BIN_DIR = "D:\Program\uv\tools-bin"

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
    cargo init @args --vsc none
}
function cgn {
    cargo new @args --vsc none
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
