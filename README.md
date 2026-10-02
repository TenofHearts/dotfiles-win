# dotfiles-win

Personal Windows configuration for PowerShell, Oh My Posh, and Neovim. Settings stay in this repository so they are easy to track and reuse across machines.

## Quick start

Install Git and the applications you want to use. The Neovim configuration requires Neovim 0.12+, ripgrep, and fd; select a Nerd Font in your terminal for icons. These scripts connect configurations, but do not install applications.

Run from the PowerShell host you want to configure:

```powershell
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-win.git dotfiles
cd dotfiles

.\install.ps1 -DryRun  # Preview changes
.\install.ps1          # Install configurations
. $PROFILE.CurrentUserCurrentHost  # Reload the shell profile
```

Use `-SkipNvim` for a shell-only installation. Start `nvim` to let it download its plugins and tools. Keep the checkout in a stable location, since the installed configurations reference it directly.

## Structure

```text
dotfiles/
|-- install.ps1                 # Main setup entry point
|-- scripts/
|   |-- links.ps1               # Manage the PowerShell profile loader
|   `-- nvim.ps1                # Manage the Neovim directory junction
|-- config/
|   |-- powershell/             # Shell profile and command shortcuts
|   |-- oh-my-posh/             # Prompt theme
|   `-- nvim/                   # Neovim configuration (Git submodule)
`-- .gitmodules                 # Submodule source
```

## Script usage

| Script | Purpose | Example |
| --- | --- | --- |
| `install.ps1` | Set up both configurations, backing up existing ones. | `.\install.ps1` |
| `scripts/links.ps1` | Install, check, or restore the PowerShell profile loader. | `.\scripts\links.ps1 -Action status` |
| `scripts/nvim.ps1` | Install, check, or restore the Neovim junction. | `.\scripts\nvim.ps1 -Action status` |

Both helper scripts accept `-Action install`, `-Action status` (the default), and `-Action restore`. Add `-DryRun` to preview installation or restoration.

Installation prints a backup manifest path. To restore, use the matching helper and manifest:

```powershell
.\scripts\links.ps1 -Action restore -Manifest '<profile-manifest-path>'
.\scripts\nvim.ps1 -Action restore -Manifest '<nvim-manifest-path>'
```

Restore refuses to replace a configuration connection that has been changed. Manifests are stored under `$HOME/.local/state/dotfiles-win` by default. Profile backups live there too; Neovim backups sit beside the original configuration directory.

For custom locations, `install.ps1` accepts `-ProfilePath`, `-NvimPath`, and `-StatePath`. The helpers use `-ProfilePath` or `-ConfigPath`, plus `-StatePath`.

## Configuration overview

### PowerShell

The PowerShell setup aims to make everyday development feel familiar across machines. Its main idea is to reduce repetitive work while keeping commands easy to understand and adapt. Shared conventions provide a consistent starting point, while personal and machine-specific choices remain separate. Convenience should preserve the meaning of the underlying tools, so moving between the configured shell and a standard environment stays straightforward. The design also favors flexibility: each machine can support the tools needed for its work without requiring an identical environment everywhere. Overall, the shell should be a dependable workspace that is easy to maintain as habits evolve.

### Oh My Posh

The Oh My Posh theme treats the prompt as a compact overview of the current working context. Its purpose is to help answer everyday questions at a glance: where am I working, what environment am I using, and what needs attention? The design emphasizes visual hierarchy, grouping related information so it can be scanned naturally. Color and spacing give different kinds of information distinct roles, while a consistent appearance makes the terminal feel familiar across sessions. The guiding principle is to balance useful context with readability, keeping the place where commands are entered clear and comfortable during extended development work.

### Neovim

The Neovim setup aims to provide a focused editing environment that remains understandable and personal. It follows the idea that an editor should grow with its user, with each addition serving a clear purpose. Consistent interaction across languages helps build familiar habits, while project conventions guide how code should look and behave. The design favors deliberate actions, predictable changes, and a clear distinction between personal preferences and project requirements. Maintainability matters as much as convenience: the setup should be approachable to adjust and easy to carry between machines. The result is a foundation for daily programming that leaves room for experimentation.

## Updates

```powershell
git pull
git submodule update --init --recursive
```

Reload PowerShell or restart Neovim after configuration changes. If you edit the Neovim submodule, commit and push its changes first, then commit the updated submodule reference in this repository.
