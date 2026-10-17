# Shared helpers for apps.sh and theme.sh (sourced, not run).
# The sourcing script sets SCRIPT_DIR and DRY_RUN before calling them.

# Always under $HOME (not XDG_*), so a throwaway HOME keeps every
# write away from the real account.
CONFIG_DIR="$HOME/.config"
DATA_DIR="$HOME/.local/share"
BACKUP_DIR="$HOME/.local/state/d3mon-kde/backup/$(date +%Y%m%d-%H%M%S)"

# Counters and notes for the summary.
N_NEW=0 N_UPDATED=0 N_SAME=0 N_BACKUP=0
N_CFG_SET=0 N_CFG_SAME=0
NOTES=()
declare -A BACKED_UP=()

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

# Refuses root and a missing HOME; prints the run header.
check_user() {
	((EUID != 0)) || die "do not run as root; run as your user${1:+ ($1)}."
	[[ -n "${HOME:-}" && -d "$HOME" ]] || die "HOME is not set to a directory."
}

header() {
	say "$1"
	say "Repo: $SCRIPT_DIR"
	say "Home: $HOME"
	((DRY_RUN)) && say "Mode: dry run (use --apply to make changes)"
	return 0
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

# ----------------------------------------------------------------- summary

summary_header() {
	local mode=applied
	((DRY_RUN)) && mode="dry run (nothing changed)"
	step "Summary: $mode"
}

summary_files() {
	say "Files:    $N_NEW new, $N_UPDATED updated, $N_SAME unchanged"
	say "Settings: $N_CFG_SET changed, $N_CFG_SAME already set"
	if ((N_BACKUP)); then
		say "Backups:  ~/$(home_rel "$BACKUP_DIR")"
	else
		say "Backups:  none needed"
	fi
}

summary_notes() {
	local note
	for note in "${NOTES[@]}"; do say "Note:     $note"; done
	say ""
}

# Unknown option: message + usage on stderr, exit status 2.
bad_option() {
	printf 'Unknown option: %s\n' "$1" >&2
	usage >&2
	exit 2
}
