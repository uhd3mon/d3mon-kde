#!/usr/bin/env bash
# d3mon-kde apps: installs the usual apps on Arch Linux (pacman, with
# Steam + its lib32 Vulkan driver, and the AUR via yay).
# Safe by default: prints the plan (dry run) unless --apply is given.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=1
SKIP_STEAM=0
SKIP_AUR=0
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PKG_STATUS="not run"
STEAM_STATUS="not run"
AUR_STATUS="not run"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--dry-run | --apply] [options]

Installs Steam, MPV, Kitty, OBS (+ plugins) on Arch Linux.
The only part of d3mon-kde that needs sudo.

  --dry-run      Print every action, change nothing (default)
  --apply        Really install the packages
  --skip-steam   Do not install Steam
  --skip-aur     Do not install AUR packages (obs-vkcapture)
  -h, --help     Show this help

App lists: packages/pacman.txt and packages/aur.txt.
EOF
}

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

main() {
	while (($#)); do
		case "$1" in
		--dry-run) DRY_RUN=1 ;;
		--apply) DRY_RUN=0 ;;
		--skip-steam) SKIP_STEAM=1 ;;
		--skip-aur) SKIP_AUR=1 ;;
		-h | --help) usage; return 0 ;;
		*) bad_option "$1" ;;
		esac
		shift
	done
	check_user "sudo is used for pacman"
	header "d3mon-kde apps"

	install_packages
	if ((SKIP_AUR)); then
		AUR_STATUS="skipped (--skip-aur)"
	else
		install_aur
	fi

	summary_header
	say "Packages: $PKG_STATUS"
	say "Steam:    $STEAM_STATUS"
	say "AUR:      $AUR_STATUS"
	summary_notes
	if ((DRY_RUN)); then
		say "Re-run with --apply to install."
	else
		say "Done."
	fi
}

main "$@"
