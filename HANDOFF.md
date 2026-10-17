# HANDOFF

## Goal

d3mon-kde: one Bash script Kevin runs on Arch + KDE Plasma 6 to
restore his usual apps (Steam, MPV, Kitty, OBS + browser plugin +
obs-vkcapture) and apply the d3mon KDE theme (Dracula-style look in
d3mon colours, dark + light). The theme must also install through
KDE's own System Settings pages. See AGENTS.md for rules.
GitHub: https://github.com/uhd3mon/d3mon-kde (public).

## History

- 2026-10-17: Kevin dropped the Hyprland project (hyprd3mon) for
  KDE. The old git history (incl. the unfinished VPN work from the
  cancelled run) is saved as a bundle:
  `~/.local/share/hyprd3mon-archive/hyprd3mon.bundle`
  (`git clone` it to look). The local `.git` was deleted and a new
  history started. Old repo uhd3mon/hyprd3mon: see Next steps.

## Current state (2026-10-17)

Built and tested in throwaway HOMEs and nested Plasma sessions.
Not yet run for real (packages, live apply on Kevin's desktop).

- `install.sh`: dry run default. `--apply`, `--theme dark|light`,
  `--layout` (replaces panels: top bar + floating dock),
  `--skip-theme/-packages/-steam/-aur`, `--remove-hyprd3mon`
  (moves only files that mention "hyprd3mon" to the backup dir),
  `--remove-hyprland` (that + `sudo pacman -Rns` of the installed
  ones of hyprland hyprlock hyprpaper hyprshot hyprshutdown
  hyprpolkitagent hyprpicker xdg-desktop-portal-hyprland waybar rofi
  mako; refused inside a Hyprland session; skipped with
  --skip-packages). Refuses root.
- Live apply (`plasma-apply-lookandfeel`) only when HOME is the
  passwd home, plasmashell runs and `D3MON_NO_LIVE` != 1; otherwise
  kwriteconfig6 into `$HOME/.config` for the next login. Also sets
  DefaultDark/LightLookAndFeel so Plasma's auto light/dark switch
  stays on d3mon, and Konsole's default profile.
- Theme (all user-level): colour schemes D3monDark/Light; icon
  themes d3mon (inherits breeze-dark) + d3mon-light (inherits
  breeze; own light folders, symbolic icons shared); Plasma Style
  d3mon (only widgets/tasks.svg: dock tint + accent underline);
  Aurorae d3mon / d3mon-light (round buttons); wallpaper package
  d3mon-grid (images + images_dark); Global Themes org.d3mon.dark /
  .light (+ layout JS: top bar with app menu, one-line clock 10pt,
  tray; dock pins only installed apps via applicationExists()).
  Konsole schemes + profiles, kitty (auto dark/light files), mpv.
- `tools/package.sh` -> `dist/`: packages for System Settings
  "Install from File" (Global Theme with embedded contents/colors,
  Plasma Style, Icons, Colors) + kpackagetool6 KWin/Aurorae (SVGs
  gzipped to .svgz) + wallpaper tarball.
- `tools/screenshot.sh`: nested KWin `--virtual` + private DBus +
  fake HOME + plasmashell; KWin script places windows; drives hidden
  via user-places.xbel. Real screenshots in docs/screenshots/.

## Next steps

1. Kevin: delete the old GitHub repo uhd3mon/hyprd3mon (our token
   lacks the delete_repo scope; see the final report).
2. Kevin, on the laptop (from KDE):
   `./install.sh --remove-hyprland --apply`, then
   `./install.sh --apply` (add `--layout` for the top bar + dock).
3. Check in a real session: GTK apps (Firefox) follow the colours,
   kitty (not installed here, untested), Konsole blur, focused-window
   selection colours, dock hover/attention states, `--layout` on a
   multi-monitor setup (layout JS makes panels on the first screen).
4. Optional: publish to the KDE Store so "Get New…" finds it
   (needs Kevin's store account).
5. Install shellcheck and run it on install.sh and tools/*.sh.

## Decisions

- KDE is installed by archinstall; this repo only adds apps + theme.
- Breeze widget style + colour scheme (no Kvantum): clean in every
  Qt app and GTK (via kde-gtk-config) with nothing extra to install.
- Panel layout is opt-in (`--layout`): it resets the user's panels.
- Firefox is not in the app list (Kevin listed Steam, MPV, Kitty,
  OBS); add a line to packages/pacman.txt if wanted.
- Repo is public like hyprd3mon was.
- `--remove-hyprland` leaves Nautilus, Firefox, OBS, Steam, Kitty,
  grim/slurp/wl-clipboard and Papirus installed.

## Lessons

- plasma-apply-lookandfeel writes into `~/.config/kdedefaults/`,
  which only counts if XDG_CONFIG_DIRS includes it (startplasma does
  that). A nested test session must set it too.
- kpackagetool6 `KWin/Aurorae` requires `decoration.svgz`; Aurorae
  itself also reads plain .svg. Repo keeps .svg, package.sh gzips.
- A Global Theme package may carry `contents/colors`; it applies
  even when the scheme isn't installed (verified via
  D3MON_SHOT_VIA=kde). Icons/style/decoration can't be embedded.
- `Wallpaper/Images` via kpackagetool6 installs to the wrong place
  (~/.local/share/<id>); unpack into ~/.local/share/wallpapers.
- Icon theme inheriting breeze-dark in a light scheme gives
  invisible toolbar/tray icons; hence d3mon-light.
- Digital clock with autoFontAndSize=false needs fontWeight 400, or
  it renders thin and dim.
- KDE tints unfocused selection 40% toward the accent unless the
  scheme has its own [Colors:Selection][Inactive] and
  ChangeSelectionColor=false.
- KIO reads Places group-hidden flags from owner
  http://www.kde.org and resets them when the xbel has no bookmark.
- mpv 8-digit colours are #AARRGGBB; `#` in values must be quoted.
- backup_path marks absent paths as seen, or a file the run just
  created gets "backed up".

## Verification observed (2026-10-17)

- `bash -n install.sh tools/*.sh` OK; layout JS `node --check` OK;
  mpv 0.41 loads mpv.conf.
- Real-HOME dry run: exit 0; plan `pacman -Syu --needed mpv kitty
  obs-studio obs-studio-plugin-browser ttf-jetbrains-mono-nerd
  lib32-vulkan-radeon steam`, `yay -S --needed obs-vkcapture
  lib32-obs-vkcapture`, `plasma-apply-lookandfeel --apply
  org.d3mon.dark` printed only. `--remove-hyprland` dry run here:
  `pacman -Rns xdg-desktop-portal-hyprland waybar`; ~/.config/rofi
  and hypr/hyprpaper.conf kept (not from hyprd3mon).
- Fake HOME apply twice: 2nd run 0 new/updated, 0 settings changed,
  no backups (Atlas: 150 files / 143 settings first run).
- Fake HOME cleanup with planted old files + own files: 8 hyprd3mon
  paths moved, own `rofi/my-own.rasi` and `hypr/hyprland.conf` kept,
  emptied waybar dir removed.
- Nested Plasma 6.7 sessions (script install, dark + light, and
  KDE-only install from dist/ via kpackagetool6): Global Theme,
  colours, folder icons, Aurorae buttons, dock underline, wallpaper,
  top bar + dock layout, Konsole palette all seen in screenshots.
- Nova reviewed install.sh: nothing destructive; medium findings
  (skip-packages vs removal, late Hyprland check, whole-folder move,
  mpv colours, auto light/dark, mimeapps backup) fixed.
- Not run: real package install/removal, live apply on the real
  desktop, kitty, GTK apps, shellcheck.

## Team memory

<!-- workspace:memory:start -->
- hyprland project layout (2026-10-17): /home/kevin/Workspace/hyprland, local git (fe1ed45, no remote). install.sh = Bash entry, dry-run default, --apply not implemented; configs/<app>/ -> ~/.config/<app>/; patches/<app>/ = mods to upstream apps (Hyprshot, Hyprlock...). Guides: README, AGENTS.md (rules+checks), CLAUDE.md=@AGENTS.md, HANDOFF.md. Checks: bash -n install.sh; ./install.sh --dry-run. Arch (pacman+yay). Hyprland/shellcheck not installed; old config in ~/.config/hypr not imported. (Sora, 2026-10-17)
- hyprd3mon published 2026-10-17: PUBLIC repo https://github.com/uhd3mon/hyprd3mon (branch main, commit a5a74f8; local folder /home/kevin/Workspace/hyprland). Kevin's GitHub login is uhd3mon (git author name KevinEightSeven is not a login). Full installer built (Hyprland 0.56 Lua config, waybar/rofi/mako/kitty/hyprlock, Hyprshot keys, settings + dark/light themes, Firefox/OBS/obs-vkcapture(AUR)/Steam). Tested only offline (fake HOME, Lua stub); first real --apply + Hyprland login still to do on Kevin's laptop. Older note saying "--apply not implemented, no remote" is stale. (Sora, 2026-10-17)
- hyprd3mon 2026-10-17 (commit 8c6daf1, pushed): bar network click = bin/hyprd3mon-network (rofi Wi-Fi/VPN menu; Kevin rejected nmtui as "horrible"); right-click = nm-connection-editor. Keybind help/settings lists are keys-first at 760px (were cut off). Kevin runs it live on 1920px screens now. uploads/ (chat screenshots) is gitignored. (Sora, 2026-10-17)
- d3mon-kde theme assets (Strata, 2026-10-17): theme/icons/d3mon (places/scalable 64 folders 32-512 px + places/symbolic 16-31 px line icons using ColorScheme-Text, aliases = symlinks, inherits breeze-dark), theme/aurorae/d3mon + d3mon-light (Aurorae v2 needs metadata.desktop or the theme is skipped; rc = <theme>rc; padding 14 holds the SVG shadow), theme/wallpapers/d3mon-grid (images/ light, images_dark/ dark, 5 sizes). Generated by scripts in /tmp/strata-gen (icons.py, aurorae.py, wall.sh, preview-*.sh) — not yet in the repo; suggest tools/. assets/wallpapers removed. Not yet seen in a real Plasma session. (Strata, 2026-10-17)
- d3mon-kde (2026-10-17, Atlas): install.sh rewritten for KDE: flags --apply --theme dark|light --layout --skip-theme/-packages/-steam/-aur --remove-hyprd3mon; packages in packages/{pacman,aur}.txt. Live plasma-apply-lookandfeel only when HOME == passwd home + plasmashell running + D3MON_NO_LIVE!=1; otherwise kwriteconfig6 into $HOME/.config (safe for fake-HOME tests). Theme files: color-schemes, konsole (2 schemes + d3mon.profile/d3mon-light.profile), look-and-feel org.d3mon.dark/light (+layout JS), configs/kitty (auto light/dark files), configs/mpv. Tested only in fake HOMEs; real apply not run. (Atlas, 2026-10-17)
- d3mon-kde icons (Strata, 2026-10-17): theme generators now live in tools/gen/ (icons.py writes both theme/icons/d3mon + d3mon-light by default; aurorae.py ROOT, tasks.py > widgets/tasks.svg, wall.sh, preview-*.sh). d3mon-light has its own places/scalable (body #cfd2ca, back/tab #a9ada4, glyph #3a3d37, strip #4f8f00); places/symbolic is a symlink to d3mon's. Dark icons regenerate byte-identical. Verified in nested light/dark screenshots. (Strata, 2026-10-17)
- d3mon-kde colours (Atlas, 2026-10-17): dark window/header #141416, view #0f0f11, button #1c1c1f (wallpaper #070707). Selection: ChangeSelectionColor=false + explicit [Colors:Selection][Inactive] (dark #2c3322, light #dfeccf); light active selection #c8e2a0 with dark ink. KDE otherwise tints unfocused selection 40% toward accent (olive/lime). Breeze focus/checkbox = DecorationFocus; QPalette::Accent (progress bars) = Selection bg. tools/screenshot.sh pre-writes user-places.xbel (owner http://www.kde.org, GroupState-Devices/RemovableDevices-IsHidden=true, one Home bookmark so KIO keeps the flags). Aurorae bg in tools/gen/aurorae.py still #0d0d0e, should become #141416. (Atlas, 2026-10-17)
<!-- workspace:memory:end -->
