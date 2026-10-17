#!/usr/bin/env bash
# d3mon-kde installer: restores the usual apps on Arch + KDE Plasma 6
# and installs/applies the d3mon theme.
# Safe by default: prints the plan (dry run) unless --apply is given.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=1
SKIP_STEAM=0
SKIP_PACKAGES=0
SKIP_AUR=0
SKIP_THEME=0
THEME=dark
LAYOUT=0
REMOVE_HYPRD3MON=0
REMOVE_HYPRLAND=0

# Always under $HOME (not XDG_*), so a throwaway HOME keeps every
# write away from the real account.
CONFIG_DIR="$HOME/.config"
DATA_DIR="$HOME/.local/share"
BACKUP_DIR="$HOME/.local/state/d3mon-kde/backup/$(date +%Y%m%d-%H%M%S)"

# Files written with kwriteconfig6 or by plasma-apply-lookandfeel;
# backed up once per run before the first change.
PLASMA_RC_FILES=(
	kdeglobals kwinrc kcminputrc plasmarc ksplashrc
	plasma-org.kde.plasma.desktop-appletsrc plasmashellrc
)

# What the old Hyprland installer (hyprd3mon) left behind.
HYPRD3MON_PATHS=(
	".local/bin/hyprd3mon-*"
	.config/hyprd3mon
	.config/hypr/hyprland.lua
	.config/hypr/monitors.lua
	.config/hypr/hyprlock.conf
	.config/hypr/hyprpaper.conf
	.config/waybar
	.config/rofi
	.config/mako
	.local/share/hyprd3mon
	.local/share/fonts/hyprd3mon
	.cache/hyprd3mon
)

# Packages the old Hyprland installer added for Hyprland only (apps
# like Firefox, OBS, Steam, Kitty, Nautilus stay).
HYPRLAND_PACKAGES=(
	hyprland hyprlock hyprpaper hyprshot hyprshutdown hyprpolkitagent
	hyprpicker xdg-desktop-portal-hyprland waybar rofi mako
)

# Counters and notes for the summary.
N_NEW=0 N_UPDATED=0 N_SAME=0 N_BACKUP=0
N_CFG_SET=0 N_CFG_SAME=0 N_MOVED=0
PKG_STATUS="not run"
STEAM_STATUS="not run"
AUR_STATUS="not run"
THEME_STATUS="not run"
HYPRLAND_STATUS="not run"
NOTES=()
declare -A BACKED_UP=()

usage() {
	cat <<EOF
Usage: $(basename "$0") [--dry-run | --apply] [options]

Installs Steam, MPV, Kitty, OBS (+ plugins) on Arch Linux and the
d3mon KDE Plasma theme (colours, icons, window decoration, Konsole,
Kitty, wallpaper, Global Themes "d3mon Dark" / "d3mon Light").

  --dry-run           Print every action, change nothing (default)
  --apply             Really install packages and files
  --theme dark|light  Theme to apply (default: dark)
  --layout            Also replace your panels with the d3mon layout
                      (top bar + floating dock). Off by default.
  --skip-theme        Install apps and app configs only
  --skip-packages     No pacman or yay at all (implies --skip-steam
                      and --skip-aur)
  --skip-steam        Do not install Steam
  --skip-aur          Do not install AUR packages (obs-vkcapture)
  --remove-hyprd3mon  Move the old Hyprland setup's files into the
                      backup folder (never deletes)
  --remove-hyprland   --remove-hyprd3mon, plus uninstall Hyprland,
                      hyprlock, hyprpaper, hyprshot, waybar, rofi,
                      mako (pacman -Rns). Run it from KDE.
  -h, --help          Show this help

App lists: packages/pacman.txt and packages/aur.txt.
Changed files are backed up to
~/.local/state/d3mon-kde/backup/<timestamp>/ first.
D3MON_NO_LIVE=1 skips plasma-apply-lookandfeel: settings are only
written to the config files (for the next login).
EOF
}

say() { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

# Run a command, or only print it in dry-run mode.
run() {
	if ((DRY_RUN)); then
		say "[dry-run] $*"
	else
		say "+ $*"
		"$@"
	fi
}

# Path of a target relative to $HOME, for display and backups.
home_rel() { printf '%s' "${1#"$HOME"/}"; }

# Prints the package names in a list file: one per line, "#" starts a
# comment (whole line or after whitespace).
read_list() {
	local file="$1" line
	[[ -f "$file" ]] || return 0
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		read -r line _ <<<"$line" || true
		[[ -n "$line" ]] && printf '%s\n' "$line"
	done <"$file"
	return 0
}

# ---------------------------------------------------------------- packages

# Prints the lib32 Vulkan driver(s) matching the GPUs found by lspci.
# Matches only GPU lines, case-sensitively for AMD ("ati" alone would
# match "Corporation").
lib32_vulkan_drivers() {
	local gpus
	gpus="$(lspci 2>/dev/null | grep -iE 'vga|3d controller|display controller' || true)"
	if grep -qE '\[AMD/ATI\]|Radeon|AMD' <<<"$gpus"; then
		echo lib32-vulkan-radeon
	fi
	if grep -qi 'intel' <<<"$gpus"; then
		echo lib32-vulkan-intel
	fi
	if grep -qi 'nvidia' <<<"$gpus"; then
		if pacman -Qq nvidia-utils >/dev/null 2>&1; then
			echo lib32-nvidia-utils
		else
			warn "NVIDIA GPU found but nvidia-utils is not installed;" \
				"not adding lib32-nvidia-utils."
		fi
	fi
}

multilib_enabled() {
	grep -qE '^[[:space:]]*\[multilib\]' /etc/pacman.conf 2>/dev/null
}

# Prints the lib32 Vulkan driver(s) for Steam, one per line.
steam_drivers() {
	local drivers=()
	if have lspci; then
		mapfile -t drivers < <(lib32_vulkan_drivers)
	else
		warn "lspci not found (package pciutils); cannot detect the GPU."
	fi
	if ((${#drivers[@]})); then
		say "GPU Vulkan driver(s): ${drivers[*]}" >&2
		printf '%s\n' "${drivers[@]}"
	else
		warn "No lib32 Vulkan driver picked; pacman may ask for a provider."
	fi
}

# One full upgrade + install (no partial upgrades); Steam joins it.
install_packages() {
	step "Packages (official repos, full upgrade)"
	if ! have pacman; then
		say "pacman not found; skipping packages (this part is for Arch Linux)."
		PKG_STATUS="skipped (no pacman)"
		STEAM_STATUS="$PKG_STATUS"
		return 0
	fi
	local list=() pkgs=() p want_steam=0
	mapfile -t list < <(read_list "$SCRIPT_DIR/packages/pacman.txt")
	for p in "${list[@]}"; do
		if [[ "$p" == steam ]]; then want_steam=1; else pkgs+=("$p"); fi
	done
	if ((!want_steam)); then
		STEAM_STATUS="not in packages/pacman.txt"
	elif ((SKIP_STEAM)); then
		STEAM_STATUS="skipped (--skip-steam)"
	elif multilib_enabled; then
		local drivers=()
		mapfile -t drivers < <(steam_drivers)
		pkgs+=("${drivers[@]}" steam)
		if ((DRY_RUN)); then STEAM_STATUS="planned"; else STEAM_STATUS="installed"; fi
	else
		say "[multilib] is not enabled in /etc/pacman.conf; skipping Steam."
		say "To enable it, uncomment these two lines in /etc/pacman.conf:"
		say "  [multilib]"
		say "  Include = /etc/pacman.d/mirrorlist"
		say "then re-run this script."
		STEAM_STATUS="skipped (multilib disabled)"
	fi
	if ((!${#pkgs[@]})); then
		say "packages/pacman.txt lists nothing to install."
		PKG_STATUS="nothing to do"
		return 0
	fi
	run sudo pacman -Syu --needed "${pkgs[@]}"
	if ((DRY_RUN)); then PKG_STATUS="planned"; else PKG_STATUS="installed"; fi
}

# AUR packages via yay (never as root; yay calls sudo itself).
install_aur() {
	step "AUR packages (yay)"
	local list=() pkgs=() p
	mapfile -t list < <(read_list "$SCRIPT_DIR/packages/aur.txt")
	for p in "${list[@]}"; do
		if [[ "$p" == lib32-* ]] && ! multilib_enabled; then
			say "[multilib] is off; skipping $p"
			continue
		fi
		pkgs+=("$p")
	done
	if ((!${#pkgs[@]})); then
		AUR_STATUS="nothing to do"
		return 0
	fi
	if ! have yay; then
		say "yay not found; skipping: ${pkgs[*]}"
		say "To get yay:"
		say "  sudo pacman -S --needed git base-devel"
		say "  git clone https://aur.archlinux.org/yay-bin.git"
		say "  cd yay-bin && makepkg -si"
		say "then re-run this script."
		AUR_STATUS="skipped (yay not installed)"
		return 0
	fi
	run yay -S --needed "${pkgs[@]}"
	if ((DRY_RUN)); then AUR_STATUS="planned"; else AUR_STATUS="installed"; fi
}

# ------------------------------------------------------------------- files

# Copies a file or folder to the backup folder, keeping its path
# relative to $HOME. Once per run per path.
backup_path() {
	local path="$1" backup
	# Mark absent paths too: a file this run creates is not a backup.
	[[ -z "${BACKED_UP[$path]:-}" ]] || return 0
	BACKED_UP[$path]=1
	[[ -e "$path" || -L "$path" ]] || return 0
	backup="$BACKUP_DIR/$(home_rel "$path")"
	say "backup   ~/$(home_rel "$path") -> ~/$(home_rel "$backup")"
	if ((!DRY_RUN)); then
		mkdir -p "$(dirname "$backup")"
		cp -a -- "$path" "$backup"
	fi
	N_BACKUP=$((N_BACKUP + 1))
}

# install_file SRC DEST
# Identical -> skip. Different -> back up, then replace. Absent -> copy.
install_file() {
	local src="$1" dest="$2" shown mode=644
	shown="~/$(home_rel "$dest")"
	[[ -x "$src" ]] && mode=755

	if [[ -e "$dest" || -L "$dest" ]]; then
		if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
			say "same     $shown"
			N_SAME=$((N_SAME + 1))
			return 0
		fi
		say "update   $shown"
		backup_path "$dest"
		((DRY_RUN)) || rm -f -- "$dest"
		N_UPDATED=$((N_UPDATED + 1))
	else
		say "new      $shown"
		N_NEW=$((N_NEW + 1))
	fi
	if ((!DRY_RUN)); then
		install -D -m "$mode" -- "$src" "$dest"
	fi
	return 0
}

# install_link SRC DEST: recreates a (relative) symlink, e.g. icon
# aliases. Same target -> skip; anything else -> back up, replace.
install_link() {
	local src="$1" dest="$2" target shown
	target="$(readlink -- "$src")"
	shown="~/$(home_rel "$dest")"
	if [[ -e "$dest" || -L "$dest" ]]; then
		if [[ -L "$dest" && "$(readlink -- "$dest")" == "$target" ]]; then
			say "same     $shown"
			N_SAME=$((N_SAME + 1))
			return 0
		fi
		say "update   $shown"
		backup_path "$dest"
		((DRY_RUN)) || rm -rf -- "$dest"
		N_UPDATED=$((N_UPDATED + 1))
	else
		say "new      $shown"
		N_NEW=$((N_NEW + 1))
	fi
	if ((!DRY_RUN)); then
		mkdir -p "$(dirname "$dest")"
		ln -s -- "$target" "$dest"
	fi
	return 0
}

# install_tree SRC_DIR DEST_DIR: file by file (symlinks stay links);
# skips .gitkeep and README files. Returns 0 if SRC_DIR is absent.
install_tree() {
	local src_dir="$1" dest_dir="$2" src rel
	if [[ ! -d "$src_dir" ]]; then
		say "(nothing in ${src_dir#"$SCRIPT_DIR"/} yet)"
		return 0
	fi
	while IFS= read -r -d '' src; do
		rel="${src#"$src_dir"/}"
		case "$(basename "$rel")" in .gitkeep | README*) continue ;; esac
		if [[ -L "$src" ]]; then
			install_link "$src" "$dest_dir/$rel"
		else
			install_file "$src" "$dest_dir/$rel"
		fi
	done < <(find "$src_dir" \( -type f -o -type l \) -print0 | sort -z)
}

install_app_configs() {
	step "App configs -> ~/.config (kitty, mpv)"
	install_tree "$SCRIPT_DIR/configs" "$CONFIG_DIR"
}

install_theme_files() {
	step "Theme files -> ~/.local/share"
	install_tree "$SCRIPT_DIR/theme/color-schemes" "$DATA_DIR/color-schemes"
	install_tree "$SCRIPT_DIR/theme/icons" "$DATA_DIR/icons"
	install_tree "$SCRIPT_DIR/theme/aurorae" "$DATA_DIR/aurorae/themes"
	install_tree "$SCRIPT_DIR/theme/look-and-feel" "$DATA_DIR/plasma/look-and-feel"
	install_tree "$SCRIPT_DIR/theme/plasma" "$DATA_DIR/plasma/desktoptheme"
	install_tree "$SCRIPT_DIR/theme/konsole" "$DATA_DIR/konsole"
	install_tree "$SCRIPT_DIR/theme/wallpapers" "$DATA_DIR/wallpapers"
}

# ------------------------------------------------------------ KDE settings

# cfg_set QUIET FILE KEY VALUE GROUP... : writes one KConfig key with
# kwriteconfig6 if it differs; backs the file up first.
cfg_set() {
	local quiet="$1" file="$2" key="$3" value="$4" g=() x cur
	shift 4
	for x in "$@"; do g+=(--group "$x"); done
	cur="$(kreadconfig6 --file "$file" "${g[@]}" --key "$key" 2>/dev/null || true)"
	if [[ "$cur" == "$value" ]]; then
		N_CFG_SAME=$((N_CFG_SAME + 1))
		return 0
	fi
	backup_path "$file"
	if ((!quiet)); then
		local groups
		groups="$(printf '[%s]' "$@")"
		say "set      ~/$(home_rel "$file") $groups $key=$value"
	fi
	if ((!DRY_RUN)); then
		mkdir -p "$(dirname "$file")"
		kwriteconfig6 --file "$file" "${g[@]}" --key "$key" -- "$value"
	fi
	N_CFG_SET=$((N_CFG_SET + 1))
}

# Copies every colour from a .colors file into kdeglobals, as
# plasma-apply-colorscheme does, without signalling a live session.
merge_color_scheme() {
	local scheme="$1" file="$CONFIG_DIR/kdeglobals" line key value
	local groups=() before=$N_CFG_SET
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		if [[ "$line" == \[* ]]; then
			# "[Colors:Header][Inactive]" -> ("Colors:Header" "Inactive")
			line="${line#[}"
			line="${line%]}"
			IFS=$'\x1f' read -r -a groups <<<"${line//][/$'\x1f'}"
			continue
		fi
		key="${line%%=*}"
		value="${line#*=}"
		# The scheme's display name is not a kdeglobals setting.
		[[ "${groups[*]}" == General && "$key" == Name ]] && continue
		cfg_set 1 "$file" "$key" "$value" "${groups[@]}"
	done <"$scheme"
	if ((N_CFG_SET > before)); then
		say "colours  ~/.config/kdeglobals <- $(basename "$scheme")" \
			"($((N_CFG_SET - before)) keys)"
	else
		say "colours  ~/.config/kdeglobals already match $(basename "$scheme")"
	fi
}

# Writes a Global Theme's contents/defaults ("[file][group]" headers)
# with kwriteconfig6. [Wallpaper] needs plasmashell, so it is skipped.
apply_laf_defaults() {
	local defaults="$1" line key value file="" groups=() parts=()
	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" || "$line" == \#* ]] && continue
		if [[ "$line" == \[* ]]; then
			line="${line#[}"
			line="${line%]}"
			IFS=$'\x1f' read -r -a parts <<<"${line//][/$'\x1f'}"
			file="" groups=()
			((${#parts[@]} >= 2)) || continue
			file="${parts[0]}"
			groups=("${parts[@]:1}")
			continue
		fi
		[[ -n "$file" ]] || continue
		key="${line%%=*}"
		value="${line#*=}"
		cfg_set 0 "$CONFIG_DIR/$file" "$key" "$value" "${groups[@]}"
	done <"$defaults"
}

# True only for the user's real, running Plasma session.
live_plasma_session() {
	[[ "${D3MON_NO_LIVE:-0}" != 1 ]] || return 1
	[[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || return 1
	local real_home
	real_home="$(getent passwd "$(id -un)" | cut -d: -f6)"
	[[ -n "$real_home" && "$HOME" -ef "$real_home" ]] || return 1
	pgrep -u "$(id -u)" -x plasmashell >/dev/null 2>&1
}

# Writes the Global Theme's settings straight into the config files
# (no running Plasma needed); they take effect at the next login.
apply_theme_offline() {
	local scheme="$1" laf="$2"
	if ! have kwriteconfig6 || ! have kreadconfig6; then
		say "kwriteconfig6 not found (package kconfig); theme files are" \
			"installed but not selected. Pick \"d3mon ${THEME^}\" in System Settings."
		THEME_STATUS="files only (no kwriteconfig6)"
		return 0
	fi
	merge_color_scheme "$SCRIPT_DIR/theme/color-schemes/$scheme.colors"
	cfg_set 0 "$CONFIG_DIR/kdeglobals" LookAndFeelPackage "$laf" KDE
	apply_laf_defaults "$SCRIPT_DIR/theme/look-and-feel/$laf/contents/defaults"
	NOTES+=("No running Plasma session for this HOME: settings go straight into the config files and apply at the next login. The wallpaper and GTK colours are not set this way; pick the Global Theme \"d3mon ${THEME^}\" in System Settings (or re-run this script inside Plasma).")
	((LAYOUT)) && NOTES+=("--layout needs a running Plasma session; the panel layout was not changed.")
	if ((DRY_RUN)); then THEME_STATUS="planned (config files)"; else THEME_STATUS="written to config files (next login)"; fi
}

apply_theme_live() {
	local scheme="$1" laf="$2" cur_laf cur_scheme f
	if ! have plasma-apply-lookandfeel; then
		say "plasma-apply-lookandfeel not found; writing config files instead."
		apply_theme_offline "$scheme" "$laf"
		return 0
	fi
	cur_laf="$(kreadconfig6 --file "$CONFIG_DIR/kdeglobals" --group KDE --key LookAndFeelPackage 2>/dev/null || true)"
	cur_scheme="$(kreadconfig6 --file "$CONFIG_DIR/kdeglobals" --group General --key ColorScheme 2>/dev/null || true)"
	if ((!LAYOUT)) && [[ "$cur_laf" == "$laf" && "$cur_scheme" == "$scheme" ]]; then
		say "Global Theme $laf is already applied."
		THEME_STATUS="already applied"
		return 0
	fi
	for f in "${PLASMA_RC_FILES[@]}"; do backup_path "$CONFIG_DIR/$f"; done
	if ((LAYOUT)); then
		run plasma-apply-lookandfeel --apply "$laf" --resetLayout
	else
		run plasma-apply-lookandfeel --apply "$laf"
	fi
	if ((DRY_RUN)); then THEME_STATUS="planned (live session)"; else THEME_STATUS="applied to the running session"; fi
}

apply_theme() {
	step "Apply theme: d3mon $THEME"
	local scheme laf profile
	if [[ "$THEME" == light ]]; then
		scheme=D3monLight laf=org.d3mon.light profile=d3mon-light.profile
	else
		scheme=D3monDark laf=org.d3mon.dark profile=d3mon.profile
	fi

	if live_plasma_session; then
		say "Running Plasma session found for this HOME."
		apply_theme_live "$scheme" "$laf"
	else
		say "No live Plasma session for this HOME (or D3MON_NO_LIVE=1);" \
			"the running desktop is not touched."
		apply_theme_offline "$scheme" "$laf"
	fi

	if have kwriteconfig6 && have kreadconfig6; then
		# If Plasma switches light/dark by itself, keep it on d3mon.
		cfg_set 0 "$CONFIG_DIR/kdeglobals" DefaultDarkLookAndFeel org.d3mon.dark KDE
		cfg_set 0 "$CONFIG_DIR/kdeglobals" DefaultLightLookAndFeel org.d3mon.light KDE
		cfg_set 0 "$CONFIG_DIR/konsolerc" DefaultProfile "$profile" "Desktop Entry"
	else
		say "kwriteconfig6 not found; Konsole default profile not set" \
			"(choose \"$profile\" in Konsole -> Settings)."
	fi
	say "kitty    follows Plasma light/dark by itself (dark/light-theme.auto.conf)"
}

# ------------------------------------------------------------- hyprd3mon

# Moves one path into the backup folder (keeping its place under $HOME).
move_to_backup() {
	local path="$1" dest
	dest="$BACKUP_DIR/hyprd3mon/$(home_rel "$path")"
	say "move     ~/$(home_rel "$path") -> ~/$(home_rel "$dest")"
	if ((!DRY_RUN)); then
		mkdir -p "$(dirname "$dest")"
		mv -- "$path" "$dest"
	fi
	N_MOVED=$((N_MOVED + 1))
}

remove_hyprd3mon() {
	step "Move the old hyprd3mon (Hyprland) files to the backup folder"
	local pattern path found=0
	for pattern in "${HYPRD3MON_PATHS[@]}"; do
		for path in "$HOME"/$pattern; do
			[[ -e "$path" || -L "$path" ]] || continue
			if [[ "$pattern" == *hyprd3mon* ]]; then
				found=1
				move_to_backup "$path"
				continue
			fi
			# Shared names (waybar, rofi, hypr/...): only the files
			# hyprd3mon wrote; every one of them mentions "hyprd3mon".
			local hits=() hit
			mapfile -d '' -t hits < <(grep -rlsZ hyprd3mon -- "$path" || true)
			if ((!${#hits[@]})); then
				say "keep     ~/$(home_rel "$path") (not from hyprd3mon)"
				continue
			fi
			found=1
			for hit in "${hits[@]}"; do move_to_backup "$hit"; done
			# Drop the folder only if hyprd3mon's files were all it had.
			if ((!DRY_RUN)) && [[ -d "$path" ]]; then
				rmdir -p --ignore-fail-on-non-empty -- "$path" 2>/dev/null || true
			fi
		done
	done
	((found)) || say "nothing from hyprd3mon found"

	# hyprd3mon made Nautilus the folder handler; hand it back to Dolphin.
	if have xdg-mime && [[ "$(xdg-mime query default inode/directory 2>/dev/null)" == org.gnome.Nautilus.desktop ]]; then
		backup_path "$CONFIG_DIR/mimeapps.list"
		run xdg-mime default org.kde.dolphin.desktop inode/directory
	fi
	NOTES+=("hyprd3mon also changed GTK settings with gsettings (dark/light preference, Papirus icons); those are left as they are.")
}

# Uninstalls the Hyprland-only packages that are installed.
remove_hyprland_packages() {
	step "Remove Hyprland packages"
	if ! have pacman; then
		say "pacman not found; skipping."
		return 0
	fi
	local p pkgs=()
	for p in "${HYPRLAND_PACKAGES[@]}"; do
		pacman -Qq "$p" >/dev/null 2>&1 && pkgs+=("$p")
	done
	if ((!${#pkgs[@]})); then
		say "none of these are installed: ${HYPRLAND_PACKAGES[*]}"
		HYPRLAND_STATUS="nothing installed"
		return 0
	fi
	run sudo pacman -Rns "${pkgs[@]}"
	if ((DRY_RUN)); then HYPRLAND_STATUS="planned: ${pkgs[*]}"; else HYPRLAND_STATUS="removed: ${pkgs[*]}"; fi
}

# ----------------------------------------------------------------- summary

summary() {
	local mode=applied note
	((DRY_RUN)) && mode="dry run (nothing changed)"
	step "Summary: $mode"
	say "Packages: $PKG_STATUS"
	say "Steam:    $STEAM_STATUS"
	say "AUR:      $AUR_STATUS"
	say "Theme:    $THEME_STATUS"
	say "Files:    $N_NEW new, $N_UPDATED updated, $N_SAME unchanged"
	say "Settings: $N_CFG_SET changed, $N_CFG_SAME already set"
	((REMOVE_HYPRLAND)) && say "Hyprland: $HYPRLAND_STATUS"
	((REMOVE_HYPRD3MON)) && say "hyprd3mon: $N_MOVED path(s) moved to the backup folder"
	if ((N_BACKUP || N_MOVED)); then
		say "Backups:  ~/$(home_rel "$BACKUP_DIR")"
	else
		say "Backups:  none needed"
	fi
	for note in "${NOTES[@]}"; do say "Note:     $note"; done
	say ""
	if ((DRY_RUN)); then
		say "Re-run with --apply to install."
	else
		say "Done. Open a new Konsole/Kitty window to see the terminal theme."
	fi
}

main() {
	while (($#)); do
		case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--apply) DRY_RUN=0 ;;
		--skip-steam) SKIP_STEAM=1 ;;
		--skip-aur) SKIP_AUR=1 ;;
		--skip-packages) SKIP_PACKAGES=1 ;;
		--skip-theme) SKIP_THEME=1 ;;
		--layout) LAYOUT=1 ;;
		--remove-hyprd3mon) REMOVE_HYPRD3MON=1 ;;
		--remove-hyprland) REMOVE_HYPRLAND=1 REMOVE_HYPRD3MON=1 ;;
		--theme)
			(($# >= 2)) || die "--theme needs a value: dark or light."
			THEME="$2"
			shift
			;;
		--theme=*) THEME="${1#--theme=}" ;;
		-h | --help) usage; return 0 ;;
		*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; return 2 ;;
		esac
		shift
	done
	[[ "$THEME" == dark || "$THEME" == light ]] ||
		die "--theme must be dark or light, not '$THEME'."

	((EUID != 0)) || die "do not run as root; run as your user (sudo is used for pacman)."
	[[ -n "${HOME:-}" && -d "$HOME" ]] || die "HOME is not set to a directory."

	if ((REMOVE_HYPRD3MON)) && [[ "${XDG_CURRENT_DESKTOP:-}" == *Hyprland* ]]; then
		die "you are in a Hyprland session; log in to KDE and run this again."
	fi

	say "d3mon-kde installer"
	say "Repo: $SCRIPT_DIR"
	say "Home: $HOME"
	((DRY_RUN)) && say "Mode: dry run (use --apply to make changes)"

	if ((SKIP_PACKAGES)); then
		PKG_STATUS="skipped (--skip-packages)"
		STEAM_STATUS="skipped (--skip-packages)"
		AUR_STATUS="skipped (--skip-packages)"
	else
		install_packages
		if ((SKIP_AUR)); then
			AUR_STATUS="skipped (--skip-aur)"
		else
			install_aur
		fi
	fi

	if ((REMOVE_HYPRLAND)); then
		if ((SKIP_PACKAGES)); then
			HYPRLAND_STATUS="skipped (--skip-packages)"
		else
			remove_hyprland_packages
		fi
	fi
	((REMOVE_HYPRD3MON)) && remove_hyprd3mon

	install_app_configs
	if ((SKIP_THEME)); then
		THEME_STATUS="skipped (--skip-theme)"
	else
		install_theme_files
		apply_theme
	fi
	summary
}

main "$@"
