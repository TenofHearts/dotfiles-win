# dotfiles-win

Personal Windows configurations for PowerShell, Oh My Posh, Neovim, Git, Windows Terminal, GlazeWM, and Zebar.

## Install

Use PowerShell 7.3+ and install the applications first. Zebar requires Node.js 22.12+ to build its bar. Neovim requires Neovim 0.12+, ripgrep, and fd. Install 0xProto Nerd Font and open Windows Terminal once before setup. GlazeWM and Zebar configuration links require Developer Mode or an elevated shell.

```powershell
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-win.git dotfiles
cd dotfiles
.\install.ps1 -DryRun
.\install.ps1
. $PROFILE.CurrentUserCurrentHost
```

Installers replace existing configurations without creating backups. Restore actions and the `-Manifest` and `-StatePath` options have been removed.

Keep the checkout in a stable location. Add `-SkipNvim`, `-SkipGit`, `-SkipTerminal`, `-SkipGlazeWM`, or `-SkipZebar` to omit an application.

## Configurations

Run these commands from the repository root to load individual configurations.

| Configuration | Purpose | Load |
| --- | --- | --- |
| PowerShell / Oh My Posh | Shell profile and prompt theme. | `.\scripts\links.ps1 -Action install` |
| Neovim | Code editor configuration. | `.\scripts\nvim.ps1 -Action install` |
| Git | Shared preferences and ignore rules. | `.\scripts\git.ps1 -Action install` |
| Windows Terminal | Terminal appearance and keybindings. | `.\scripts\terminal.ps1 -Action apply` |
| GlazeWM | Tiling window management. | `.\scripts\glazewm.ps1 -Action install` |
| Zebar | Workspace and system-status menu bar. | `.\scripts\zebar.ps1 -Action install` |

Reload PowerShell and restart Neovim, GlazeWM, and Zebar after loading their configurations. For custom locations, use the corresponding `*Path` option in `install.ps1` or `-ConfigPath` in an application script (`-ProfilePath` for PowerShell).

## Update

```powershell
git pull
git submodule update --init --recursive
.\install.ps1
. $PROFILE.CurrentUserCurrentHost
```

Restart Neovim, GlazeWM, and Zebar to load updates.
