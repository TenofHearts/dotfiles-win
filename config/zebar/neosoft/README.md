# Compact Neosoft widgets

This configuration adapts [Neosoft Zebar](https://github.com/blaiyz/neosoft-zebar)
at the revision in `upstream.json`. The original workspace buttons, battery icons,
volume state/icons, provider wiring, configuration loader and build system are
reused. `patch-upstream.mjs` makes checked source adaptations; `overlay/` provides
the three-window layout, system theme styling and read-only dropdowns.

Each monitor gets a mode pill on the left, its assigned workspaces in the middle,
and volume, Wi-Fi, Bluetooth, battery and HH:mm on the right. Pills are 36px high,
have 10px corner radii and slightly transparent backgrounds. The visible top edge is
4px from the screen, with an 8px visible horizontal inset (4px window inset plus
4px shadow padding). Width follows content.
Selected workspaces on the focused monitor are blue; other monitors use gray.
Wi-Fi and Bluetooth names appear only in their dropdowns. Battery is hidden when
Windows does not report a battery. The Windows light/dark preference controls colors.

The upstream autotiler, weather, media and CPU/memory polling are disabled. No
volume, network or Bluetooth action changes settings. Clicking an information
button opens its details; clicking another replaces it. Escape, an outside click
or loss of focus closes the dropdown. Opening a dropdown focuses its Zebar window.

Wi-Fi and Bluetooth are read through Windows' WinRT APIs by `connection-info.ps1`
every 20 seconds, only in the status widget. Classic and LE Bluetooth connections
are queried; paired but disconnected devices are excluded. Query failures appear
as unavailable information. Audio comes from Zebar's existing audio provider.

Install Node.js 22+ and Zebar first. In PowerShell:

```powershell
.\scripts\zebar.ps1 -Action install
.\scripts\zebar.ps1 -Action status
```

The settings file uses a file symlink, which needs Developer Mode or elevated
PowerShell. The widget build itself needs no Windows admin rights. `install.ps1`
also installs this pack unless `-SkipZebar` is set. Build dependencies are installed
with `npm ci` using the checked-in lockfile. The upstream source archive is pinned
by revision and SHA256. The original license is copied into the installed pack.

Downloaded source, npm dependencies and build output stay under `.test-output/`;
the installed pack stays under `~/.glzr/zebar/dotfiles-neosoft`. Neither is tracked.
Existing packs are moved to timestamped backups under ~/.local/state/dotfiles-win/backups before replacement. The marketplace
starter and other downloaded plugins are not changed. To undo the visual change,
set `startupConfigs` back to `glzr-io.starter/with-glazewm/default` and restart Zebar.

After pulling changes, run `scripts/zebar.ps1 -Action install` and restart
Zebar. `-Action build` validates and builds without installing; `-DryRun` prints
paths without downloading or modifying files. Do not edit installed generated JS;
edit the overlay or patch script instead. This keeps everything needed to reproduce
the customizations in dotfiles while keeping third-party plugins out of Git.
