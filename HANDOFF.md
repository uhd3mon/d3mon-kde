# HANDOFF

## Goal

d3mon-kde: Bash scripts Kevin runs on Arch + KDE Plasma 6 to
restore his usual apps (Steam, MPV, Kitty, OBS + browser plugin +
obs-vkcapture) and apply the d3mon KDE theme (Dracula-style look in
d3mon colours, dark + light). `theme.sh` installs every theme part
straight into KDE (no separate downloads). See AGENTS.md for rules.
GitHub: https://github.com/uhd3mon/d3mon-kde (public).

## History

- 2026-10-17: Kevin dropped the Hyprland project (hyprd3mon) for
  KDE. The old git history is saved as a bundle:
  `~/.local/share/hyprd3mon-archive/hyprd3mon.bundle`.
- 2026-10-17: Hyprland removal (`--remove-hyprland`) deleted at
  Kevin's request; install.sh split into apps.sh + theme.sh; round
  "traffic light" window buttons replaced by flat line buttons.
  Git history rewritten without Claude co-author lines (Kevin's
  request); commits carry only Kevin's name from now on.

## Current state (2026-10-17)

Built and tested in throwaway HOMEs and nested Plasma sessions.
Not yet run for real (packages, live apply on Kevin's desktop).

- `apps.sh`: packages only (the sudo part). `sudo pacman -Syu
  --needed` of packages/pacman.txt (+ Steam with the lib32 Vulkan
  driver from lspci, only if [multilib] is on) and `yay -S --needed`
  of packages/aur.txt. Flags: `--apply`, `--skip-steam`,
  `--skip-aur`.
- `theme.sh`: per user, no sudo. Copies every theme part into
  ~/.local/share (colour schemes, icons, Plasma Style, Aurorae,
  Global Themes, Konsole, wallpaper) + configs/kitty, configs/mpv
  into ~/.config, then applies. Flags: `--apply`,
  `--theme dark|light`, `--layout`, `--skip-configs`. Ends with a
  list of where each part appears in System Settings.
- `install.sh`: thin wrapper, runs apps.sh then theme.sh and routes
  flags; `--skip-packages` = no apps.sh, `--skip-theme` = no
  theme.sh (so also no kitty/mpv configs, a change from before).
- `lib/common.sh`: shared helpers (run/dry run, backups,
  install_file/link/tree, cfg_set, summary). All scripts: dry run
  default, refuse root, idempotent, backups in
  ~/.local/state/d3mon-kde/backup/<time>/.
- Live apply (`plasma-apply-lookandfeel`) only when HOME is the
  passwd home, plasmashell runs and `D3MON_NO_LIVE` != 1; otherwise
  kwriteconfig6 into `$HOME/.config` for the next login. Also sets
  DefaultDark/LightLookAndFeel and Konsole's default profile.
- Theme: colour schemes D3monDark/Light; icon themes d3mon
  (inherits breeze-dark) + d3mon-light (inherits breeze); Plasma
  Style d3mon (only widgets/tasks.svg); Aurorae d3mon / d3mon-light
  v2.0 (flat 32x24 cells, line glyphs minus / square / two squares
  / X in the title colour, rounded hover fill, red close hover
  with white X); wallpaper d3mon-grid; Global Themes org.d3mon.dark
  / .light (+ layout JS: top bar + dock). Konsole, kitty, mpv.
- `tools/package.sh` -> `dist/` (optional "Install from File"
  packages; release v0.2.0 carries them).
- `tools/screenshot.sh`: nested KWin + fake HOME, uses theme.sh.

## Next steps

1. Kevin: delete the old GitHub repo uhd3mon/hyprd3mon (token
   lacks the delete_repo scope: `gh auth refresh -h github.com -s
   delete_repo`, then `gh repo delete uhd3mon/hyprd3mon --yes`).
2. Kevin, on the laptop: `./install.sh --apply` (or `./apps.sh
   --apply` and `./theme.sh --apply`; `--layout` for top bar +
   dock). Hyprland packages must now be removed by hand if wanted.
3. Check in a real session: new window buttons at his scale, GTK
   apps (Firefox), kitty (untested), Konsole blur, dock states,
   `--layout` on two monitors.
4. Optional: publish to the KDE Store (needs Kevin's account).
5. Install shellcheck and run it on all scripts.

## Decisions

- KDE is installed by archinstall; this repo only adds apps + theme.
- apps.sh = everything needing sudo; theme.sh = everything per user
  (theme + app configs). install.sh only chains them.
- Breeze widget style + colour scheme (no Kvantum).
- Panel layout is opt-in (`--layout`): it resets the user's panels.
- Firefox is not in the app list; add a line to packages/pacman.txt
  if wanted.
- Window buttons: no coloured dots; glyphs in the title colour, only
  close turns red (on hover). Accent green left out to keep it calm.
- No Claude attribution in commits, PRs or releases (Kevin).

## Lessons

- plasma-apply-lookandfeel writes into `~/.config/kdedefaults/`,
  which only counts if XDG_CONFIG_DIRS includes it (startplasma does
  that). A nested test session must set it too.
- kpackagetool6 `KWin/Aurorae` requires `decoration.svgz`; Aurorae
  itself also reads plain .svg. Repo keeps .svg, package.sh gzips.
- A Global Theme package may carry `contents/colors`; it applies
  even when the scheme isn't installed. Icons/style/decoration
  can't be embedded.
- `Wallpaper/Images` via kpackagetool6 installs to the wrong place
  (~/.local/share/<id>); unpack into ~/.local/share/wallpapers.
- Icon theme inheriting breeze-dark in a light scheme gives
  invisible toolbar/tray icons; hence d3mon-light.
- Digital clock with autoFontAndSize=false needs fontWeight 400.
- KDE tints unfocused selection 40% toward the accent unless the
  scheme has its own [Colors:Selection][Inactive] and
  ChangeSelectionColor=false.
- KIO reads Places group-hidden flags from owner
  http://www.kde.org and resets them when the xbel has no bookmark.
- mpv 8-digit colours are #AARRGGBB; `#` in values must be quoted.
- backup_path marks absent paths as seen, or a file the run just
  created gets "backed up".
- Thin line glyphs need strokes on .5 px coordinates to stay one
  pixel wide at 1x (Strata).

## Verification observed (2026-10-17)

- `bash -n install.sh apps.sh theme.sh lib/common.sh tools/*.sh`
  OK; no "hypr" left in any script.
- Real-HOME dry runs of apps.sh, theme.sh, install.sh: exit 0;
  plan `sudo pacman -Syu --needed mpv kitty obs-studio
  obs-studio-plugin-browser ttf-jetbrains-mono-nerd
  lib32-vulkan-radeon steam` and `yay -S --needed obs-vkcapture
  lib32-obs-vkcapture`, printed only.
- Unknown option -> exit 2 (all three); `install.sh --theme` with no
  or a bad value -> exit 1 before apps.sh runs.
- Fake HOME `theme.sh --apply` twice: 150 new / 143 settings, then
  0 new/updated, 0 changed, no backups, no backup dir.
- aurorae.py regenerates byte-identical; all SVGs valid, 8 states
  per button (Nova). `tools/package.sh` builds 12 files (Nova).
- Nested Plasma 6.7 screenshots (dark + light, via theme.sh): new
  min/max/close buttons, title centred, rest of theme unchanged;
  saved to docs/screenshots/.
- Nova reviewed the split: no must-fix; stale HANDOFF and Aurorae
  version fixed; double summary from the wrapper is cosmetic.
- Not run: real package install, live apply on the real desktop,
  kitty, GTK apps, shellcheck.

## Team memory

<!-- workspace:memory:start -->
- hyprland project layout (2026-10-17): /home/kevin/Workspace/hyprland, local git (fe1ed45, no remote). install.sh = Bash entry, dry-run default, --apply not implemented; configs/<app>/ -> ~/.config/<app>/; patches/<app>/ = mods to upstream apps (Hyprshot, Hyprlock...). Guides: README, AGENTS.md (rules+checks), CLAUDE.md=@AGENTS.md, HANDOFF.md. Checks: bash -n install.sh; ./install.sh --dry-run. Arch (pacman+yay). Hyprland/shellcheck not installed; old config in ~/.config/hypr not imported. (Sora, 2026-10-17)
- hyprd3mon published 2026-10-17: PUBLIC repo https://github.com/uhd3mon/hyprd3mon (branch main, commit a5a74f8; local folder /home/kevin/Workspace/hyprland). Kevin's GitHub login is uhd3mon (git author name KevinEightSeven is not a login). Full installer built (Hyprland 0.56 Lua config, waybar/rofi/mako/kitty/hyprlock, Hyprshot keys, settings + dark/light themes, Firefox/OBS/obs-vkcapture(AUR)/Steam). Tested only offline (fake HOME, Lua stub); first real --apply + Hyprland login still to do on Kevin's laptop. Older note saying "--apply not implemented, no remote" is stale. (Sora, 2026-10-17)
- hyprd3mon 2026-10-17 (commit 8c6daf1, pushed): bar network click = bin/hyprd3mon-network (rofi Wi-Fi/VPN menu; Kevin rejected nmtui as "horrible"); right-click = nm-connection-editor. Keybind help/settings lists are keys-first at 760px (were cut off). Kevin runs it live on 1920px screens now. uploads/ (chat screenshots) is gitignored. (Sora, 2026-10-17)
- d3mon-kde theme assets (Strata, 2026-10-17): theme/icons/d3mon (places/scalable 64 folders 32-512 px + places/symbolic 16-31 px line icons using ColorScheme-Text, aliases = symlinks, inherits breeze-dark), theme/aurorae/d3mon + d3mon-light (Aurorae v2 needs metadata.desktop or the theme is skipped; rc = <theme>rc; padding 14 holds the SVG shadow), theme/wallpapers/d3mon-grid (images/ light, images_dark/ dark, 5 sizes). Generated by scripts in /tmp/strata-gen (icons.py, aurorae.py, wall.sh, preview-*.sh) — not yet in the repo; suggest tools/. assets/wallpapers removed. Not yet seen in a real Plasma session. (Strata, 2026-10-17)
- d3mon-kde (2026-10-17, Atlas): install.sh rewritten for KDE: flags --apply --theme dark|light --layout --skip-theme/-packages/-steam/-aur --remove-hyprd3mon; packages in packages/{pacman,aur}.txt. Live plasma-apply-lookandfeel only when HOME == passwd home + plasmashell running + D3MON_NO_LIVE!=1; otherwise kwriteconfig6 into $HOME/.config (safe for fake-HOME tests). Theme files: color-schemes, konsole (2 schemes + d3mon.profile/d3mon-light.profile), look-and-feel org.d3mon.dark/light (+layout JS), configs/kitty (auto light/dark files), configs/mpv. Tested only in fake HOMEs; real apply not run. (Atlas, 2026-10-17)
- d3mon-kde icons (Strata, 2026-10-17): theme generators now live in tools/gen/ (icons.py writes both theme/icons/d3mon + d3mon-light by default; aurorae.py ROOT, tasks.py > widgets/tasks.svg, wall.sh, preview-*.sh). d3mon-light has its own places/scalable (body #cfd2ca, back/tab #a9ada4, glyph #3a3d37, strip #4f8f00); places/symbolic is a symlink to d3mon's. Dark icons regenerate byte-identical. Verified in nested light/dark screenshots. (Strata, 2026-10-17)
- d3mon-kde colours (Atlas, 2026-10-17): dark window/header #141416, view #0f0f11, button #1c1c1f (wallpaper #070707). Selection: ChangeSelectionColor=false + explicit [Colors:Selection][Inactive] (dark #2c3322, light #dfeccf); light active selection #c8e2a0 with dark ink. KDE otherwise tints unfocused selection 40% toward accent (olive/lime). Breeze focus/checkbox = DecorationFocus; QPalette::Accent (progress bars) = Selection bg. tools/screenshot.sh pre-writes user-places.xbel (owner http://www.kde.org, GroupState-Devices/RemovableDevices-IsHidden=true, one Home bookmark so KIO keeps the flags). Aurorae bg in tools/gen/aurorae.py still #0d0d0e, should become #141416. (Atlas, 2026-10-17)
- 2026-10-17: project pivoted from Hyprland to d3mon-kde (KDE Plasma 6 app restore + d3mon theme). New public repo https://github.com/uhd3mon/d3mon-kde (fresh history, commit c5008c6, release v0.1.0 with Install-from-File packages from tools/package.sh). Old hyprd3mon history saved at ~/.local/share/hyprd3mon-archive/hyprd3mon.bundle; old GitHub repo uhd3mon/hyprd3mon NOT yet deleted (gh token lacks delete_repo; Kevin must run gh auth refresh -h github.com -s delete_repo, then gh repo delete). Notes above about hyprd3mon/Hyprland are history. Visual testing: tools/screenshot.sh (nested KWin, fake HOME) — safe, real Plasma screenshots. (Sora, 2026-10-17)
- d3mon-kde window buttons (Strata, 2026-10-17): Kevin dropped the mac-style round dots. tools/gen/aurorae.py now draws flat 32x24 cells with line glyphs (1.4 px strokes on .5 px coordinates, title text colour, inactive = dim text, deactivated 35%), a rounded hover fill (dark #26272b, light #dcddd8), a stronger pressed fill and a red close hover (#e5534b dark / #e0483f light) with a white X. rc: TitleEdgeTop/Bottom 3, TitleHeight 24, ButtonSpacing 0, TitleEdgeLeft/Right 6. aurorae.py now also writes metadata.json. tools/gen/preview-deco.sh reads the layout from the rc and renders strips at 1x, 1.25x and 1.5x (run it with bash; it isn't executable). Seen in nested Plasma dark + light. (Strata, 2026-10-17)
<!-- workspace:memory:end -->
