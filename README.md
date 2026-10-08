# dotfiles-win

Personal Windows configuration for PowerShell, Oh My Posh, Neovim, Git, and Windows Terminal. Settings stay in this repository so they are easy to track and reuse across machines.

## Quick start

Use PowerShell 7.3 or newer. Install Git and the applications you want to use. The Neovim configuration requires Neovim 0.12+, ripgrep, and fd. Install **0xProto Nerd Font** for the shared Terminal font, or edit the shared font preference. Open Windows Terminal once before setup so it creates its local settings. These scripts configure applications, but do not install them.

Run from the PowerShell host you want to configure:

```powershell
git clone --recurse-submodules https://github.com/TenofHearts/dotfiles-win.git dotfiles
cd dotfiles

.\install.ps1 -DryRun  # Preview changes
.\install.ps1          # Install configurations
. $PROFILE.CurrentUserCurrentHost  # Reload the shell profile
```

Use `-SkipNvim`, `-SkipGit`, or `-SkipTerminal` to omit those applications. For a shell-only installation, use all three switches. Start `nvim` to let it download its plugins and tools. Keep the checkout in a stable location, since the installed configurations reference it directly.

## Structure

```text
dotfiles/
|-- install.ps1                 # Main setup entry point
|-- scripts/
|   |-- links.ps1               # Manage the PowerShell profile loader
|   |-- nvim.ps1                # Manage the Neovim directory junction
|   |-- git.ps1                 # Include shared Git preferences
|   `-- terminal.ps1            # Merge shared Terminal preferences
|-- config/
|   |-- powershell/             # Shell profile and command shortcuts
|   |-- oh-my-posh/             # Prompt theme
|   |-- nvim/                   # Neovim configuration (Git submodule)
|   |-- git/                    # Shared Git config and global ignores
|   `-- windows-terminal/       # Shared appearance and shortcuts
`-- .gitmodules                 # Submodule source
```

## Script usage

| Script | Purpose | Example |
| --- | --- | --- |
| `install.ps1` | Set up all configurations. | `.\install.ps1` |
| `scripts/links.ps1` | Install, check, or restore the PowerShell profile loader. | `.\scripts\links.ps1 -Action status` |
| `scripts/nvim.ps1` | Install, check, or restore the Neovim junction. | `.\scripts\nvim.ps1 -Action status` |
| `scripts/git.ps1` | Install or check the Git include. | `.\scripts\git.ps1 -Action install` |
| `scripts/terminal.ps1` | Apply or check Terminal preferences. | `.\scripts\terminal.ps1 -Action apply` |

The application helpers accept `-Action install` and `-Action status` (the default). Terminal also accepts `-Action apply`, equivalent to `install`. Add `-DryRun` to preview changes. Terminal previews list the shared properties that would change. Git and Terminal apply updates directly without keeping backups.

PowerShell and Neovim also support `-Action restore`; their installation prints a backup manifest path. To restore, use the matching helper and manifest:

```powershell
.\scripts\links.ps1 -Action restore -Manifest '<profile-manifest-path>'
.\scripts\nvim.ps1 -Action restore -Manifest '<nvim-manifest-path>'
```

PowerShell/Neovim restore refuses to replace a configuration connection that has been changed since installation. Their manifests are stored under `$HOME/.local/state/dotfiles-win` by default. PowerShell backups live there too; Neovim backups sit beside the original configuration directory.

For custom locations, `install.ps1` accepts `-ProfilePath`, `-NvimPath`, `-GitPath`, `-TerminalPath`, and `-StatePath`. The helpers use `-ProfilePath` or `-ConfigPath`; `-StatePath` applies only to PowerShell/Neovim. Terminal detects existing Store, Preview, and unpackaged settings; specify its path if multiple installations exist or you use portable mode.

## Configuration overview

### PowerShell

The PowerShell setup aims to make everyday development feel familiar across machines. Its main idea is to reduce repetitive work while keeping commands easy to understand and adapt. Shared conventions provide a consistent starting point, while personal and machine-specific choices remain separate. Convenience should preserve the meaning of the underlying tools, so moving between the configured shell and a standard environment stays straightforward. The design also favors flexibility: each machine can support the tools needed for its work without requiring an identical environment everywhere. Overall, the shell should be a dependable workspace that is easy to maintain as habits evolve.

### Oh My Posh

The Oh My Posh theme treats the prompt as a compact overview of the current working context. Its purpose is to help answer everyday questions at a glance: where am I working, what environment am I using, and what needs attention? The design emphasizes visual hierarchy, grouping related information so it can be scanned naturally. Color and spacing give different kinds of information distinct roles, while a consistent appearance makes the terminal feel familiar across sessions. The guiding principle is to balance useful context with readability, keeping the place where commands are entered clear and comfortable during extended development work.

### Neovim

The Neovim setup aims to provide a focused editing environment that remains understandable and personal. It follows the idea that an editor should grow with its user, with each addition serving a clear purpose. Consistent interaction across languages helps build familiar habits, while project conventions guide how code should look and behave. The design favors deliberate actions, predictable changes, and a clear distinction between personal preferences and project requirements. Maintainability matters as much as convenience: the setup should be approachable to adjust and easy to carry between machines. The result is a foundation for daily programming that leaves room for experimentation.

### Git

Git includes the shared preferences from your local `.gitconfig`, which remains an ordinary file. The shared defaults provide a `main` initial branch, pruning on fetch, a pager, and two convenience aliases: `git st` and `git last`. Identity, credentials, proxy settings, editor paths, and trusted directories stay local. The include is placed before existing settings, so local choices can override shared defaults. `git config --global` edits the local file, and changes to either file take effect immediately without rerunning setup. If you move this checkout, update the include and ignore paths in your local `.gitconfig`.

The global ignore file covers OS/editor leftovers, Python environments and caches, dotenv files, and local agent working directories. Environment examples and shared instructions such as `AGENTS.md` and `CLAUDE.md` remain trackable. Existing tracked files are unaffected. Use `git add -f` when you intentionally want to track a file covered by these global patterns. An existing local `core.excludesFile` setting takes precedence over the shared ignore file.

### Windows Terminal

Terminal shares your appearance and shortcuts while each machine retains its installed shells. The shared defaults use the Campbell color scheme, 0xProto Nerd Font, acrylic transparency, and your current window and copy/paste preferences. Ubuntu, Debian, PowerShell, and other profiles remain in the local settings file, along with your default-shell selection and profile discovery choices. Per-profile overrides still take precedence over the shared profile defaults.

The script merges shared defaults recursively, actions by ID, shortcuts by key combination, and custom schemes/themes by name. Unrelated local entries are preserved. Applying changes rewrites the file as ordinary JSON, removing comments and original formatting. Removing a property from the shared file stops managing it but leaves the previously applied local value in place.

To change a shared preference, edit `config/windows-terminal/settings.json`, preview it, then apply:

```powershell
.\scripts\terminal.ps1 -Action apply -DryRun
.\scripts\terminal.ps1 -Action apply
```

Edits made through Terminal's UI stay local until you copy the desired shared values into the repository. The next application restores repository values for managed settings. Shared profile defaults are restricted to appearance settings; shell names, commands, GUIDs, and paths belong in local profiles.

## Updates

```powershell
git pull
git submodule update --init --recursive
.\scripts\terminal.ps1 -Action apply -DryRun
.\scripts\terminal.ps1 -Action apply
```

Git reads shared configuration changes immediately; Terminal preferences need to be reapplied after pulling. Reload PowerShell or restart Neovim after configuration changes. If you edit the Neovim submodule, commit and push its changes first, then commit the updated submodule reference in this repository.

Run `./tests/configs.ps1` to verify Git and Terminal installation, local overrides, merges, and repeat runs. It uses isolated fixtures under `.test-output` and removes them after success.
