# dotfiles-win

Personal Windows configurations for PowerShell, Oh My Posh, Neovim, Codex, Git, Windows Terminal, GlazeWM, and Zebar.

## Install

Use PowerShell 7.3+ and install the applications first. Zebar requires Node.js 22.12+ to build its bar. Neovim requires Neovim 0.12+, ripgrep, and fd. Install 0xProto Nerd Font and open Windows Terminal once before setup. GlazeWM and Zebar configuration links require Developer Mode or an elevated shell.

Review the curated environment with `.\scripts\packages.ps1`. Add `-InstallMissing` to install missing tools, `-Upgrade` to update selected manager-owned tools, or `-DryRun` to preview either operation. Both installation and upgrades are opt-in. See [package setup](config/packages/packages.md) for groups, individual selections, the WinGet export, and runtime prerequisites.

```powershell
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-win.git dotfiles
cd dotfiles
.\install.ps1 -DryRun
.\install.ps1
. $PROFILE.CurrentUserCurrentHost
```

Installers replace existing configurations without creating backups. Restore actions and the `-Manifest` and `-StatePath` options have been removed.

Keep the checkout in a stable location. Add `-SkipNvim`, `-SkipCodex`, `-SkipGit`, `-SkipTerminal`, `-SkipGlazeWM`, or `-SkipZebar` to omit an application.

## Configurations

Run these commands from the repository root to load individual configurations.

| Configuration | Purpose | Load |
| --- | --- | --- |
| PowerShell / Oh My Posh | Shell profile and prompt theme. | `.\scripts\links.ps1 -Action install` |
| Neovim | Code editor configuration. | `.\scripts\nvim.ps1 -Action install` |
| Codex | Shared CLI profile and preferences. | `.\scripts\codex.ps1 -Action install` |
| Git | Shared preferences and ignore rules. | `.\scripts\git.ps1 -Action install` |
| Windows Terminal | Terminal appearance and keybindings. | `.\scripts\terminal.ps1 -Action apply` |
| GlazeWM | Tiling window management. | `.\scripts\glazewm.ps1 -Action install` |
| Zebar | Workspace and system-status menu bar. | `.\scripts\zebar.ps1 -Action install` |

Reload PowerShell and restart Neovim, GlazeWM, and Zebar after loading their configurations. For custom locations, use the corresponding `*Path` option in `install.ps1` or `-ConfigPath` in an application script (`-ProfilePath` for PowerShell).

## Update

Codex uses the same [configuration submodule](https://github.com/TenofHearts/codex-config) as [dotfiles](https://github.com/TenofHearts/dotfiles). The installer symlinks only `config/codex/dotfiles.config.toml` into `$env:CODEX_HOME` (or `$HOME/.codex` when unset), preserving local `config.toml`, credentials, sessions, and plugins. The link requires Developer Mode or an elevated shell. Use `-CodexPath` in `install.ps1` or `-ConfigPath` in `scripts/codex.ps1` to choose another destination file; `-Action status` verifies the link.

Reload PowerShell to activate the `codex` function, which forwards arguments to the CLI with `--profile dotfiles`. Matching shared preferences override local settings. Invoke `codex.exe` directly to use local defaults. Restart Codex after updating the profile. Commit shared preference changes inside `config/codex` first, then update the parent repository's submodule reference.

```powershell
git pull
git submodule update --init --recursive
.\install.ps1
. $PROFILE.CurrentUserCurrentHost
```

Restart Neovim, GlazeWM, and Zebar to load updates.
