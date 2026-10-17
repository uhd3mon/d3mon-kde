#!/usr/bin/env bash
# d3mon-kde: runs apps.sh (packages) then theme.sh (theme + configs).
# Safe by default: prints the plan (dry run) unless --apply is given.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--dry-run | --apply] [options]

Runs apps.sh (Steam, MPV, Kitty, OBS; needs sudo) and then theme.sh
(d3mon KDE theme + Kitty/MPV configs; per user).

  --dry-run           Print every action, change nothing (default)
  --apply             Really install
  --theme dark|light  Theme to apply (default: dark)
  --layout            Also replace your panels (top bar)
  --skip-packages     Do not run apps.sh
  --skip-theme        Do not run theme.sh
  --skip-steam        Do not install Steam
  --skip-aur          Do not install AUR packages
  --skip-configs      Do not install the Kitty/MPV configs
  -h, --help          Show this help
EOF
}

apps=() theme=() skip_apps=0 skip_theme=0
while (($#)); do
	case "$1" in
	--dry-run | --apply) apps+=("$1") theme+=("$1") ;;
	--skip-steam | --skip-aur) apps+=("$1") ;;
	--layout | --skip-configs) theme+=("$1") ;;
	--theme | --theme=*)
		# Checked here so a typo fails before apps.sh runs.
		if [[ "$1" == --theme ]]; then
			(($# >= 2)) || { echo "error: --theme needs a value: dark or light." >&2; exit 1; }
			value="$2"
			shift
		else
			value="${1#--theme=}"
		fi
		[[ "$value" == dark || "$value" == light ]] ||
			{ echo "error: --theme must be dark or light, not '$value'." >&2; exit 1; }
		theme+=(--theme "$value")
		;;
	--skip-packages) skip_apps=1 ;;
	--skip-theme) skip_theme=1 ;;
	-h | --help) usage; exit 0 ;;
	*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

((skip_apps)) || "$SCRIPT_DIR/apps.sh" "${apps[@]}"
((skip_theme)) || "$SCRIPT_DIR/theme.sh" "${theme[@]}"
