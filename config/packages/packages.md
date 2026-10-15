# Environment packages

`catalog.json` is the editable source of truth for the selected dotfiles and development tools verified on this Windows machine, plus the explicitly requested Typst addition. `winget.json` is the generated WinGet selection, not a dump of every app on the original machine. Versions are deliberately unpinned. Installing these packages does not deploy the dotfiles or configure application defaults.

## Review or install

Run with PowerShell 7.3+ from the repository root. The default is an offline inventory; it does not download, install, update package indexes, or upgrade anything.

```powershell
# Review the selection and command locations.
./scripts/packages.ps1 | Format-Table Name, Group, Status, Package -AutoSize

# Show planned actions, without contacting package managers.
./scripts/packages.ps1 -InstallMissing -Upgrade -DryRun

# Choose either operation, or combine them explicitly.
./scripts/packages.ps1 -InstallMissing
./scripts/packages.ps1 -Upgrade
./scripts/packages.ps1 -InstallMissing -Upgrade

# Limit scope by group or exact display name from catalog.json.
./scripts/packages.ps1 -Group dotfiles -InstallMissing
./scripts/packages.ps1 -Only 'zoxide', 'fzf' -InstallMissing
./scripts/packages.ps1 -Only 'fzf' -Upgrade

# Regenerate the WinGet export after editing the catalog.
./scripts/packages.ps1 -ExportDirectory ./config/packages
```

The script supports Windows and WinGet only.

The export can also be used directly with `winget import --import-file ./config/packages/winget.json`. That command uses WinGet's own install/upgrade behavior and cannot recognize all manually installed equivalents. Prefer the script for preserving existing installations.

`-InstallMissing` treats an existing executable as present, including installations managed by Chocolatey, standalone downloads, Conda, or MinGW. During actual operations it also checks the chosen manager's installed records, protecting against duplicate installations when an executable is not on PATH. Windows Terminal, the Nerd Font, and 7-Zip have additional local checks. Upgrades are attempted only for the selected package IDs recognized by the chosen manager; unmanaged tools are reported and skipped, with no migration. Manager failures abort rather than being mistaken for missing packages. An inventory status of `Missing` means not locally detected, not proof that the app is absent from all custom directories.

Dry runs are offline: they cannot predict manager ownership, available upgrades, or registry entries that only the manager can match. `-Upgrade` skips missing tools unless `-InstallMissing` is also supplied. Neither flag upgrades every application on the machine. Unknown-version/pinned WinGet packages are not forced. Installation paths follow manager/installer settings; the script does not relocate existing tools. Restart the terminal afterward so PATH changes become visible. `-ExportDirectory` explicitly writes export files even when package operations use `-DryRun`.

## Selection

| Group | Tools | Reason |
| --- | --- | --- |
| dotfiles | PowerShell, Git, Oh My Posh, Neovim, ripgrep, fd, zoxide, fzf, fnm, 0xProto Nerd Font | Profile, editor, searching, directory jumping, Node version management, icons |
| dotfiles, Windows only | Windows Terminal, GlazeWM, Zebar | Configured terminal and desktop |
| development | uv, Rustup, MinGW-w64 toolchain, CMake, Ninja, 7-Zip, Typst | Existing Python, Rust, and native build tools |

Installed tools form the baseline. Typst is the explicit user-requested exception: it was not detected on this machine and is included for future installation. Other suggested tools that were not found have been removed. The selection remains a smaller development core, not an export of every installed application.

## What was found on the Windows machine

Inventory on 2026-10-15 found all dotfiles tools and the font, plus uv, Rustup, clang/GCC, CMake, and Ninja. Neovim was 0.12.5 and Node was 25.8.1. Rust's rust-analyzer, rust-src, rustfmt, and Clippy components were installed. `mingw32-make` exists, but the Neovim configuration explicitly checks for a command named `make`.

The catalog contains 19 locally verified entries plus Typst, for 20 entries total and 18 WinGet package mappings. The existing MinGW-w64 distribution and 0xProto Nerd Font are manual prerequisites. The WinGet export omits both rather than substituting a different compiler distribution. 7-Zip 25.00 was additionally verified through its installed-app record at a custom location outside PATH. No tools were downloaded, installed, or upgraded while preparing these files.

## Runtime and build prerequisites

Package-manager installation and runtime provisioning are separate. The script intentionally does not install or update Node versions, Python interpreters, Rust toolchains, editor plugins, or PowerShell modules. On a new machine, run the following yourself as needed:

```powershell
# After fnm initialization in your shell; use Node 24 LTS for new setups.
fnm install 24
fnm default 24
fnm use 24

# Only if a uv-managed Python interpreter is wanted; keep Conda if preferred.
uv python install

# Only if the toolchain/components are missing.
rustup toolchain install stable --profile minimal
rustup default stable
rustup component add rust-analyzer rust-src rustfmt clippy
```

These commands are not needed merely to reproduce the current machine's already working runtimes. Zebar's build requires Node 22.12+; the Neovim configuration requires Neovim 0.12+. The script inventories command presence, not version compatibility. Check the supplied package versions before using the configs. Mason handles Pyright, Black, clang-format, and clangd as configured in Neovim; do not install duplicate global npm/pip tools just for the editor.

The installed MinGW-w64 distribution provides GCC/clang, CMake, and Ninja. It is recorded as a manual prerequisite because the standalone LLVM package would install a different distribution. CMake and Ninja retain equivalent WinGet mappings for new machines; their existing executables are detected and preserved. Rust MSVC builds may require Visual Studio C++ Build Tools and a Windows SDK; these are not automatically installed.


On Windows the 0xProto Nerd Font remains a manual prerequisite from https://www.nerdfonts.com/font-downloads; no unverified WinGet font ID is used. Select the font in your terminal after installation.

## References

- https://learn.microsoft.com/windows/package-manager/winget/install
- https://learn.microsoft.com/windows/package-manager/winget/upgrade
