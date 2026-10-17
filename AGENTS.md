# AGENTS.md

Read this file, README.md and HANDOFF.md before any work.
After lasting changes, update HANDOFF.md (state, next steps,
decisions, lessons, checks you actually observed).

## Goal

d3mon-kde: one script Kevin runs on a fresh Arch + KDE Plasma
install to restore his most used apps (Steam, MPV, Kitty, OBS +
plugins) and apply the d3mon KDE theme: a clean, Dracula-style dark
(and light) look across Plasma, Dolphin, Konsole, Kitty and GTK
apps, with custom folder icons and a window decoration.
KDE itself is installed by archinstall, not by this script.
(This repo replaced the Hyprland project hyprd3mon on 2026-10-17.)

## Constraints

- Target: Arch Linux + KDE Plasma 6 (pacman; AUR via yay). Bash.
- Safe by default: `install.sh` must not change the system
  without `--apply`; the dry run is the default.
- Idempotent: re-running must not duplicate or clobber work.
- Back up any existing user file before replacing it.
- Theme files install per user (`~/.local/share`, `~/.config`);
  only packages need sudo.
- Never run the real install, `sudo`, package installs or apply
  the theme to Kevin's real session without his OK.
- Keep theme/app files as files in `theme/` or `configs/`, not
  heredocs buried in the script.
- No credentials, tokens or personal notes in the repo.

## Layout

- `install.sh` — thin wrapper: runs `apps.sh`, then `theme.sh`
- `apps.sh` — packages only (pacman + Steam/multilib, AUR via yay;
  the only part that uses sudo)
- `theme.sh` — per user, no sudo: installs every theme file into
  KDE, the app configs, and applies the theme
- `lib/common.sh` — shared helpers (output, run, backups,
  install_file/tree, cfg_set, counters), sourced by both
- `packages/pacman.txt`, `packages/aur.txt` — app lists
- `theme/color-schemes/` -> `~/.local/share/color-schemes/`
- `theme/icons/d3mon/` -> `~/.local/share/icons/d3mon/`
  (folder icons; inherits breeze-dark)
- `theme/icons/d3mon-light/` -> light variant (inherits breeze)
- `theme/plasma/d3mon/` -> `~/.local/share/plasma/desktoptheme/`
  (Plasma Style: only `widgets/tasks.svg`, rest falls back to Breeze)
- `theme/aurorae/d3mon[-light]/` -> `~/.local/share/aurorae/themes/`
- `theme/look-and-feel/org.d3mon.*` ->
  `~/.local/share/plasma/look-and-feel/` (Global Themes)
- `theme/konsole/` -> `~/.local/share/konsole/`
- `theme/wallpapers/d3mon-grid/` -> `~/.local/share/wallpapers/`
- `configs/<app>/` -> `~/.config/<app>/` (kitty, mpv)
- `tools/package.sh` — builds `dist/` (gitignored): packages for
  System Settings "Install from File" + kpackagetool6
- `tools/screenshot.sh` — nested throwaway Plasma session shots
  (`D3MON_SHOT_VIA=kde` installs from dist/ instead of theme.sh)
- `tools/gen/` — generators for icons, Aurorae, tasks.svg, wallpapers
- `docs/screenshots/` — real screenshots for the README

Colours live in `theme/color-schemes/`; the Aurorae `bg` in
`tools/gen/aurorae.py` must match the scheme's window colour.

## Checks (verified 2026-10-17)

```sh
bash -n *.sh lib/*.sh tools/*.sh        # syntax check
./apps.sh; ./theme.sh; ./install.sh      # dry runs, change nothing
./theme.sh --bogus; echo $?              # unknown option -> 2
# real file install into a throwaway HOME (run twice: 2nd = no changes)
F=$(mktemp -d)
HOME=$F D3MON_NO_LIVE=1 ./theme.sh --apply
tools/package.sh /tmp/d3dist             # build install-from-file packages
tools/screenshot.sh dark /tmp/shots      # real nested Plasma screenshot
D3MON_SHOT_VIA=kde tools/screenshot.sh dark /tmp/shots
```

Always use a fake HOME and `D3MON_NO_LIVE=1` when testing `--apply`,
or the theme is applied to Kevin's real Plasma session.
`tools/screenshot.sh` is safe: fake HOME, private DBus, virtual KWin
(~45 s per shot). shellcheck and kitty are not installed here.
