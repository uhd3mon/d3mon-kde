#!/usr/bin/env bash
# d3mon-kde theme: installs every d3mon theme file into KDE for this
# user (~/.local/share, ~/.config; no sudo) and applies it.
# Safe by default: prints the plan (dry run) unless --apply is given.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=1
THEME=dark
LAYOUT=0
SKIP_CONFIGS=0
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Files written with kwriteconfig6 or by plasma-apply-lookandfeel;
# backed up once per run before the first change.
PLASMA_RC_FILES=(
	kdeglobals kwinrc kcminputrc plasmarc ksplashrc
	plasma-org.kde.plasma.desktop-appletsrc plasmashellrc
)

THEME_STATUS="not run"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--dry-run | --apply] [options]

Installs the d3mon KDE Plasma theme for your user and applies it:
Global Themes "d3mon Dark" / "d3mon Light", colours, icons, Plasma
Style, window decoration, wallpaper, Konsole profiles, plus the
Kitty and MPV configs. No sudo, nothing to download.

  --dry-run           Print every action, change nothing (default)
  --apply             Really install and apply
  --theme dark|light  Theme to apply (default: dark)
  --layout            Also replace your panels with the d3mon layout
                      (top bar + floating dock). Off by default.
  --skip-configs      Do not install configs/ (kitty, mpv)
  -h, --help          Show this help

Changed files are backed up to
~/.local/state/d3mon-kde/backup/<timestamp>/ first.
D3MON_NO_LIVE=1 skips plasma-apply-lookandfeel: settings are only
written to the config files (for the next login).
EOF
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
	((SKIP_CONFIGS)) ||
		say "kitty    follows Plasma light/dark by itself (dark/light-theme.auto.conf)"
}

# Where each installed part shows up in System Settings.
where_in_kde() {
	local verb="is now"
	((DRY_RUN)) && verb="will be"
	say "The d3mon theme $verb in System Settings:"
	say "  Colors & Themes -> Global Theme: d3mon Dark, d3mon Light"
	say "  Colors & Themes -> Colors: d3mon Dark, d3mon Light"
	say "  Colors & Themes -> Icons: d3mon, d3mon Light"
	say "  Colors & Themes -> Plasma Style: d3mon"
	say "  Colors & Themes -> Window Decorations: d3mon, d3mon Light"
	say "  Wallpaper (right-click desktop): d3mon Grid"
	say "  Konsole -> Settings -> Profiles: d3mon, d3mon-light"
}

main() {
	while (($#)); do
		case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--apply) DRY_RUN=0 ;;
		--layout) LAYOUT=1 ;;
		--skip-configs) SKIP_CONFIGS=1 ;;
		--theme)
			(($# >= 2)) || die "--theme needs a value: dark or light."
			THEME="$2"
			shift
			;;
		--theme=*) THEME="${1#--theme=}" ;;
		-h | --help) usage; return 0 ;;
		*) bad_option "$1" ;;
		esac
		shift
	done
	[[ "$THEME" == dark || "$THEME" == light ]] ||
		die "--theme must be dark or light, not '$THEME'."
	check_user "the theme installs per user, no sudo needed"
	header "d3mon-kde theme"

	if ((SKIP_CONFIGS)); then
		say "App configs skipped (--skip-configs)."
	else
		install_app_configs
	fi
	install_theme_files
	apply_theme

	summary_header
	say "Theme:    $THEME_STATUS"
	summary_files
	summary_notes
	where_in_kde
	say ""
	if ((DRY_RUN)); then
		say "Re-run with --apply to install."
	else
		say "Done. Open a new Konsole/Kitty window to see the terminal theme."
	fi
}

main "$@"
