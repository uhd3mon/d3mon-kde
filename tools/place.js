// KWin script used by tools/screenshot.sh: lays out the demo windows
// like the reference shot (Konsole bottom left, Dolphin right).
const spots = {
    "org.kde.konsole": { x: 60, y: 420, width: 560, height: 400 },
    "org.kde.dolphin": { x: 660, y: 110, width: 880, height: 600 },
};
for (const w of workspace.windowList()) {
    const s = spots[w.resourceClass];
    if (s) {
        w.frameGeometry = s;
    }
}
