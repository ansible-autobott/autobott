// AutoBott panel layout template.
//
// Reproduces the maintainer's panel, captured from a Debian 13 / Plasma 6
// session (dumpCurrentLayoutJS): a NON-floating bottom panel with
//   Application Dashboard - Quicklaunch (Chrome, Dolphin, Konsole) - spacer -
//   Task Manager - spacer - system tray - pager - digital clock.
// Installed system-wide by the linux_kde role's add_kde_style option; the user
// adds it from KDE's "Add Panel" menu. Nothing here runs automatically.
//
// kickerdash and quicklaunch come from plasma-widgets-addons (installed by the
// role); the rest are core Plasma widgets.

var panel = new Panel
panel.location = "bottom"
panel.floating = false
panel.height = Math.round(gridUnit * 2.4444444444444446) // captured height (~44px at the standard gridUnit)

// Application Dashboard launcher (default icon).
panel.addWidget("org.kde.plasma.kickerdash")

// Quicklaunch: browser, file manager, terminal.
var quicklaunch = panel.addWidget("org.kde.plasma.quicklaunch")
quicklaunch.currentConfigGroup = ["General"]
quicklaunch.writeConfig("launcherUrls", [
    "file:///usr/share/applications/google-chrome.desktop",
    "file:///usr/share/applications/org.kde.dolphin.desktop",
    "file:///usr/share/applications/org.kde.konsole.desktop"
])

panel.addWidget("org.kde.plasma.marginsseparator")

// Task Manager: ungrouped, only windows from the panel's own screen, and NO
// pinned launchers. The widget ships with default pins, so we clear them
// explicitly; clearing launchers only takes effect after a reloadConfig()
// (same quirk the stock Kubuntu layout template documents).
var tasks = panel.addWidget("org.kde.plasma.taskmanager")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("groupingStrategy", 0)
tasks.writeConfig("showOnlyCurrentScreen", true)
tasks.writeConfig("launchers", [])
tasks.reloadConfig()

panel.addWidget("org.kde.plasma.marginsseparator")
panel.addWidget("org.kde.plasma.systemtray")
panel.addWidget("org.kde.plasma.pager")
panel.addWidget("org.kde.plasma.digitalclock")
