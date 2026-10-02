# Windows dotfiles

Windows counterpart to [dotfiles-apple](https://github.com/TenofHearts/dotfiles-apple), using the same app-based configuration layout and install/status/restore workflow.

```text
config/
  powershell/Microsoft.PowerShell_profile.ps1
  oh-my-posh/theme.omp.json
scripts/
  links.ps1
install.ps1
```

## Setup

Run these commands from the checkout in the PowerShell host you want to configure:

```powershell
./install.ps1 -DryRun
./install.ps1
./scripts/links.ps1 -Action status
```

The installer backs up the current user/current host profile and writes a small loader that dot-sources the tracked configuration. No administrator access or symlink privileges are required. Keep the checkout in place; subsequent configuration and theme edits take effect in new shells. Running the installer again leaves a correct loader untouched. Moving the checkout requires rerunning the installer.

PowerShell 7 and Windows PowerShell have different profile locations. Run the installer in each host you use, or select a destination explicitly with `-ProfilePath`. Existing profile contents are backed up, not merged; move any settings you still need into the local override before installing. The installer only configures the profile; install Oh My Posh, fnm, uv, Rust/Cargo and Conda separately as needed. Optional prompt and completion integrations are guarded when tools are absent. Select a Nerd Font in your terminal for prompt icons.

## Personal settings

Private settings belong in `~/.config/powershell/profile.local.ps1`, loaded before tool initialization. The existing `D:\Program` fnm and uv paths remain defaults; override them here for another machine:

```powershell
$env:FNM_DIR = "$HOME/.local/share/fnm"
$env:UV_CACHE_DIR = "$HOME/.cache/uv"
$env:UV_PYTHON_INSTALL_DIR = "$HOME/.local/share/uv/python"
$env:UV_TOOL_DIR = "$HOME/.local/share/uv/tools"
$env:UV_TOOL_BIN_DIR = "$HOME/.local/bin"
```

The three-line pastel prompt and existing Git, Conda, uv and Cargo shortcuts are retained. Edit the theme in `config/oh-my-posh/theme.omp.json`; it no longer depends on `POSH_THEMES_PATH` or a separately copied theme.

## Backups and restore

Each installation prints a manifest under `~/.local/state/dotfiles-win/backups/<timestamp>/`. Restore newest installations first:

```powershell
./scripts/links.ps1 -Action restore -Manifest 'PATH/manifest.json' -DryRun
./scripts/links.ps1 -Action restore -Manifest 'PATH/manifest.json'
```

Restore refuses to overwrite a profile edited after installation. Backups are retained after restoration. For isolated verification, use `-ProfilePath` and `-StatePath` pointing at a temporary directory; `-DryRun` performs no writes.
