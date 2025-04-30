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

function ag {
	conda activate ag
	python -u $env:AG_PATH"\\ag.py"
}
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58
