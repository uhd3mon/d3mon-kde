// d3mon desktop layout (Dracula-like): a thin top bar and a floating
// dock. Used only when the layout is applied on purpose
// (plasma-apply-lookandfeel --resetLayout, or install.sh --layout);
// it replaces the current panels.

// Top bar: launcher, app menu | clock (centred) | system tray
var top = new Panel
top.location = "top"
top.height = 2 * Math.ceil(gridUnit * 1.6 / 2)
top.floating = false
top.lengthMode = "fill"

var kickoff = top.addWidget("org.kde.plasma.kickoff")
kickoff.currentConfigGroup = ["General"]
kickoff.writeConfig("icon", "start-here-kde-symbolic")

top.addWidget("org.kde.plasma.appmenu")
// Two expanding spacers share the free space, so the clock sits in
// the middle (exactly centred when both sides are the same width).
top.addWidget("org.kde.plasma.panelspacer")

var clock = top.addWidget("org.kde.plasma.digitalclock")
clock.currentConfigGroup = ["Appearance"]
clock.writeConfig("showDate", true)
// One line, "17 Oct 2026  5:50 AM" (1 = date beside the time).
clock.writeConfig("dateDisplayFormat", 1)
clock.writeConfig("dateFormat", "custom")
clock.writeConfig("customDateFormat", "d MMM yyyy")
// Same size as the app menu, not scaled up to the panel height.
clock.writeConfig("autoFontAndSize", false)
clock.writeConfig("fontSize", 10)
clock.writeConfig("fontWeight", 400)
clock.writeConfig("fontStyleName", "Regular")

top.addWidget("org.kde.plasma.panelspacer")
top.addWidget("org.kde.plasma.systemtray")

// Dock: icon-only task manager, centred, as wide as its icons.
var dock = new Panel
dock.location = "bottom"
dock.height = 2 * Math.ceil(gridUnit * 2.75 / 2)
dock.floating = true
dock.lengthMode = "fit"
dock.alignment = "center"
dock.hiding = "none"

var tasks = dock.addWidget("org.kde.plasma.icontasks")
tasks.currentConfigGroup = ["General"]
// Pinned apps; ones that are not installed are left out (they would
// show as blank icons).
var apps = [
    "org.kde.dolphin.desktop",
    "kitty.desktop",
    "org.kde.konsole.desktop",
    "steam.desktop",
    "com.obsproject.Studio.desktop",
    "mpv.desktop",
    "systemsettings.desktop"
]
var launchers = []
for (var i = 0; i < apps.length; i++) {
    if (applicationExists(apps[i])) {
        launchers.push("applications:" + apps[i])
    }
    // The default web browser, whichever it is, goes after Dolphin.
    if (i === 0) {
        launchers.push("preferred://browser")
    }
}
tasks.writeConfig("launchers", launchers)

var desktopsArray = desktopsForActivity(currentActivity())
for (var j = 0; j < desktopsArray.length; j++) {
    desktopsArray[j].wallpaperPlugin = "org.kde.image"
}
