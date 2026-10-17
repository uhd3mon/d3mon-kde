# d3mon-kde

One script to restore my usual apps on Arch Linux + KDE Plasma 6 and
apply the **d3mon** theme: a flat, near-black (or light) look with a
green accent, custom folder icons and clean flat window buttons, across
Plasma, Dolphin, Konsole, Kitty and GTK apps. Inspired by the
Dracula KDE theme.

KDE itself is not installed here; pick KDE Plasma in `archinstall`.

![d3mon Dark](docs/screenshots/desktop-dark.png)
![d3mon Light](docs/screenshots/desktop-light.png)

These are real screenshots of a nested Plasma 6.7 session
(`tools/screenshot.sh`). The top bar + dock layout is optional
(`--layout`).

## Use

```sh
git clone https://github.com/uhd3mon/d3mon-kde.git
cd d3mon-kde
./install.sh            # dry run: prints the plan, changes nothing
./install.sh --apply    # apps + theme (dark)
```

`install.sh` just runs the two parts, which also work alone:

- `./apps.sh --apply` installs the apps (the only part using sudo).
  Options: `--skip-steam`, `--skip-aur`.
- `./theme.sh --apply` installs the whole theme into KDE for your
  user and applies it; nothing to download. Options:
  `--theme light`, `--layout` (replaces your panels with the top
  bar + floating dock; off by default), `--skip-configs` (no
  Kitty/MPV configs).

`install.sh` takes all of these, plus `--skip-packages` (no
`apps.sh`) and `--skip-theme` (no `theme.sh`). Without `--apply`
every script is a dry run.

## Apps

From `packages/pacman.txt` (add your own, one per line): Steam
(+ the lib32 Vulkan driver for your GPU, needs `[multilib]`), MPV,
Kitty, OBS Studio + browser plugin, JetBrains Mono Nerd Font.
From the AUR via `yay` (`packages/aur.txt`): obs-vkcapture
(+ lib32) for OBS game capture.

## Theme

- **Global Themes** "d3mon Dark" and "d3mon Light" in
  System Settings → Colors & Themes → Global Theme
- **Colours** D3monDark / D3monLight (KDE apps and GTK apps)
- **Icons** d3mon / d3mon Light: folder icons, the rest is Breeze
- **Plasma Style** d3mon: dock with an accent underline
- **Window decoration** d3mon / d3mon Light: flat minimise,
  maximise and close buttons (red on close hover)
- **Wallpaper** d3mon Grid (dark and light)
- **Konsole** profiles "d3mon" / "d3mon-light"
- **Kitty** follows Plasma light/dark by itself
- **MPV** OSD in d3mon colours

After installing, you can switch between dark and light at any time
in System Settings → Global Theme.

### Optional: without the script

`theme.sh` already puts everything where System Settings finds it.
To share the theme instead, `tools/package.sh` builds packages for
System Settings → "Install from File" (Global Theme, Plasma Style,
Icons, Colors) plus `kpackagetool6` packages for the window
decorations, in `dist/`.

## Safety

- The dry run is the default.
- Changed files are backed up first, to
  `~/.local/state/d3mon-kde/backup/<time>/`.
- Re-running only updates what changed.
- Everything except packages installs to your home folder.

## Layout

- `install.sh` (runs `apps.sh` + `theme.sh`), `lib/common.sh`,
  `packages/`
- `theme/`: color-schemes, icons, plasma, aurorae, look-and-feel,
  konsole, wallpapers
- `configs/`: kitty, mpv
- `tools/`: `package.sh`, `screenshot.sh`, `gen/` (icon,
  decoration, dock and wallpaper generators)
