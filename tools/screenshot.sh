#!/usr/bin/env bash
# Screenshots the d3mon theme in a nested, throwaway Plasma session:
# fake HOME + private DBus + virtual KWin, so the real desktop and
# the real ~/.config are never touched.
#
#   tools/screenshot.sh [dark|light] [OUT_DIR]   (default: dark docs/screenshots)
set -euo pipefail

THEME="${1:-dark}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$(realpath -m "${2:-$REPO/docs/screenshots}")"
W=1600 H=900
SOCKET="d3mon-shot-$$"

for tool in kwin_wayland plasmashell dolphin konsole spectacle dbus-run-session; do
	command -v "$tool" >/dev/null || { echo "missing: $tool" >&2; exit 1; }
done

FAKE="$(mktemp -d /tmp/d3mon-shot.XXXXXX)"
mkdir -p "$OUT"
WORK="$FAKE.work"   # logs + session scripts, outside the fake HOME
mkdir -p "$WORK"
echo "fake HOME: $FAKE (logs: $WORK)"

# Typical home folders, so Dolphin shows the folder icons.
mkdir -p "$FAKE"/{Desktop,Documents,Downloads,Music,Pictures,Videos,Public,Templates,github,Games}
mkdir -p "$FAKE/.config"
cat >"$FAKE/.config/user-dirs.dirs" <<'EOF'
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_VIDEOS_DIR="$HOME/Videos"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_TEMPLATES_DIR="$HOME/Templates"
EOF

# Hide this PC's real drives from Dolphin's Places (Devices and
# Removable Devices). KIO only resets these group flags when the file
# has no bookmarks, so it gets one (Home); with no kde_places_version
# KIO still adds the other default places after it.
mkdir -p "$FAKE/.local/share"
cat >"$FAKE/.local/share/user-places.xbel" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE xbel>
<xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:kdepriv="http://www.kde.org/kdepriv" xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
 <info>
  <metadata owner="http://www.kde.org">
   <GroupState-Devices-IsHidden>true</GroupState-Devices-IsHidden>
   <GroupState-RemovableDevices-IsHidden>true</GroupState-RemovableDevices-IsHidden>
  </metadata>
 </info>
 <bookmark href="file://$FAKE">
  <title>Home</title>
  <info>
   <metadata owner="http://freedesktop.org">
    <bookmark:icon name="user-home"/>
   </metadata>
   <metadata owner="http://www.kde.org">
    <isSystemItem>true</isSystemItem>
   </metadata>
  </info>
 </bookmark>
</xbel>
EOF

if [[ "${D3MON_SHOT_VIA:-script}" == kde ]]; then
	# Install only the way System Settings would (dist/ packages via
	# kpackagetool6, icons unpacked); no install.sh, no colour scheme
	# file: the Global Theme must bring its colours itself.
	"$REPO/tools/package.sh" "$WORK/dist" >"$WORK/install.log"
	D="$WORK/dist"
	{
		HOME="$FAKE" kpackagetool6 -t Plasma/LookAndFeel -i "$D/d3mon-$THEME.globaltheme.tar.gz" || true
		HOME="$FAKE" kpackagetool6 -t Plasma/Theme -i "$D/d3mon.plasmastyle.tar.gz" || true
		HOME="$FAKE" kpackagetool6 -t KWin/Aurorae -i "$D/d3mon.aurorae.tar.gz" || true
		HOME="$FAKE" kpackagetool6 -t KWin/Aurorae -i "$D/d3mon-light.aurorae.tar.gz" || true
		# Wallpaper: unpacked into ~/.local/share/wallpapers, as
		# "Get New Wallpapers" does.
		mkdir -p "$FAKE/.local/share/wallpapers"
		tar -C "$FAKE/.local/share/wallpapers" -xzf "$D/d3mon-grid.wallpaper.tar.gz" || true
		mkdir -p "$FAKE/.local/share/icons"
		tar -C "$FAKE/.local/share/icons" -xzf "$D/d3mon-icons.tar.gz" || true
	} >>"$WORK/install.log" 2>&1
else
	HOME="$FAKE" D3MON_NO_LIVE=1 "$REPO/install.sh" --apply --skip-packages \
		--theme "$THEME" >"$WORK/install.log"
fi

cat >"$WORK/session.sh" <<EOF
#!/usr/bin/env bash
export QT_QPA_PLATFORM=wayland
plasmashell >"$WORK/plasmashell.log" 2>&1 &
sleep 10
plasma-apply-lookandfeel --apply org.d3mon.$THEME --resetLayout >"$WORK/laf.log" 2>&1
sleep 6
konsole --workdir "\$HOME" -e bash "$WORK/demo.sh" >/dev/null 2>&1 &
sleep 2
dolphin "\$HOME" >/dev/null 2>&1 &
sleep 6
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript "$WORK/place.js" d3mon-place >/dev/null
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start >/dev/null
sleep 3
spectacle --background --nonotify --fullscreen --output "$OUT/desktop-$THEME.png"
sleep 3
EOF
chmod +x "$WORK/session.sh"

# Konsole shows the 16 colours; KWin script places the windows.
cp "$REPO/tools/demo.sh" "$REPO/tools/place.js" "$WORK/"

# Clean environment: no real session bus or display. kdedefaults is
# where plasma-apply-lookandfeel writes the Global Theme (as in a
# real session started by startplasma).
env -i PATH="$PATH" HOME="$FAKE" USER="$USER" LANG="${LANG:-C.UTF-8}" \
	XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" XDG_CONFIG_DIRS="$FAKE/.config/kdedefaults:/etc/xdg" \
	XDG_DATA_DIRS=/usr/local/share:/usr/share XDG_CURRENT_DESKTOP=KDE \
	XDG_SESSION_TYPE=wayland KDE_FULL_SESSION=true KDE_SESSION_VERSION=6 \
	KWIN_SCREENSHOT_NO_PERMISSION_CHECKS=1 \
	timeout 120 dbus-run-session -- kwin_wayland --virtual --no-lockscreen \
	--width "$W" --height "$H" --socket "$SOCKET" \
	--exit-with-session "$WORK/session.sh" >"$WORK/kwin.log" 2>&1 || true

if [[ -s "$OUT/desktop-$THEME.png" ]]; then
	echo "saved: $OUT/desktop-$THEME.png"
else
	echo "no screenshot; logs in $WORK" >&2
	exit 1
fi
