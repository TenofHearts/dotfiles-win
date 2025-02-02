oh-my-posh init pwsh --config $env:POSH_THEMES_PATH'\byml.omp.json' | Invoke-Expression
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

function ga{
	git add
}
function gca{
	git commit -a
}
function gps{
	git push
}
function gpl{
	git pull
}
function glg{
	git log --graph --decorate
} 

Set-Alias ll ls