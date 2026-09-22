#! /usr/bin/env sh
# Per-user KDE Plasma 6 customizations (uses the kwriteconfig6 binary).
# based on https://github.com/nbeaver/config-kde5/blob/master/config-kde.sh
#
# ENFORCED: every autobott run re-asserts these values, so a user change to any
# key below is reverted on the next run. Settings the user is meant to own go in
# kde-provision-once.sh instead, which is seeded only on a fresh machine.

# Do not obey DRM limitations.
kwriteconfig6 --file okularpartrc --group 'Core General' --key 'ObeyDRM' --type 'bool' 'false'


# =====================================================================================
# KDE Global
# =====================================================================================

kwriteconfig6 --file kdeglobals --group 'KDE' --key 'AnimationDurationFactor' '0.125'
kwriteconfig6 --file kdeglobals --group 'General' --key 'BrowserApplication' 'google-chrome.desktop'


# =====================================================================================
# Plasma
# =====================================================================================
# Plasma Style (System Settings > Colors & Themes > Plasma Style): the theme of the
# panels and widgets, independent of the application colour scheme. 'breeze-dark' is
# the id of the stock "Breeze Dark" style (/usr/share/plasma/desktoptheme/breeze-dark).
# A running plasmashell watches plasmarc and switches live; no re-login needed.
kwriteconfig6 --file plasmarc --group 'Theme' --key 'name' 'breeze-dark'
# Cursors (System Settings > Colors & Themes > Cursors): 'Breeze_Light' is the id of
# the stock white "Breeze Light" theme (breeze-cursor-theme). Not live - KWin only
# reloads it on the Cursors KCM's change signal - so it applies at the next login.
kwriteconfig6 --file kcminputrc --group 'Mouse' --key 'cursorTheme' 'Breeze_Light'


# =====================================================================================
# Shortcuts
# =====================================================================================
kwriteconfig6 --file kdeglobals --group 'Shortcuts' --key 'NextCompletion' ''
kwriteconfig6 --file kdeglobals --group 'Shortcuts' --key 'PrevCompletion' ''
kwriteconfig6 --file kdeglobals --group 'Shortcuts' --key 'ShowMenubar' ''

kwriteconfig6 --file kglobalshortcutsrc --group 'kmix' --key 'decrease_volume' 'Ctrl+Down,Volume Down,Decrease Volume'
kwriteconfig6 --file kglobalshortcutsrc --group 'kmix' --key 'increase_volume' 'Ctrl+Up,Volume Up,Increase Volume'
kwriteconfig6 --file kglobalshortcutsrc --group 'kmix' --key 'mute' 'Ctrl+M,Volume Mute,Mute'

kwriteconfig6 --file kglobalshortcutsrc --group 'kwin' --key 'Window Maximize' 'Meta+Ctrl+Alt+Up,Meta+PgUp,Maximize Window'
kwriteconfig6 --file kglobalshortcutsrc --group 'kwin' --key 'Window Minimize' 'Meta+Ctrl+Alt+Down,Meta+PgDown,Minimize Window'
kwriteconfig6 --file kglobalshortcutsrc --group 'kwin' --key 'Window Quick Tile Left' 'Meta+Ctrl+Alt+Left,Meta+Left,Quick Tile Window to the Left'
kwriteconfig6 --file kglobalshortcutsrc --group 'kwin' --key 'Window Quick Tile Right' 'Meta+Ctrl+Alt+Right,Meta+Right,Quick Tile Window to the Right'

# Yakuake toggle bound to two keys: F12 and the Eject key of an Apple keyboard
# (keysym XF86Eject -> 'Eject' in Qt's portable shortcut text). kglobalshortcutsrc
# stores "<active>,<default>,<display name>" and separates several active shortcuts
# with a tab inside the first field; KConfig writes that tab back out as '\t'.
yakuake_toggle="$(printf 'F12\tEject')"
kwriteconfig6 --file kglobalshortcutsrc --group 'yakuake' --key 'toggle-window-state' "${yakuake_toggle},F12,Open/Retract Yakuake"


# =====================================================================================
# Dolphin
# =====================================================================================
kwriteconfig6 --file dolphinrc --group 'DetailsMode' --key 'PreviewSize' '16'
kwriteconfig6 --file dolphinrc --group 'IconsMode' --key 'PreviewSize' '256'
kwriteconfig6 --file dolphinrc --group 'MainWindow' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig6 --file dolphinrc --group 'MainWindow' --key 'MenuBar' 'Disabled'
kwriteconfig6 --file dolphinrc --group 'MainWindow' --key 'ToolBarsMovable' 'Disabled'
kwriteconfig6 --file dolphinrc --group 'Toolbar mainToolBar' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig6 --file dolphinrc --group 'TabBar' --key 'TabBarVisibility' 'AlwaysShowTabBar'
# Open new tabs at the end of the tab bar instead of next to the active one.
kwriteconfig6 --file dolphinrc --group 'General' --key 'OpenNewTabAfterLastTab' --type 'bool' 'true'


# =====================================================================================
# Konsole
# =====================================================================================
kwriteconfig6 --file konsolerc --group 'KonsoleWindow' --key 'RememberWindowSize' 'false'
kwriteconfig6 --file konsolerc --group 'MainWindow' --key 'MenuBar' 'Disabled'
kwriteconfig6 --file konsolerc --group 'MainWindow' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig6 --file konsolerc --group 'Toolbar mainToolBar' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig6 --file konsolerc --group 'TabBar' --key 'TabBarPosition' 'Bottom'
kwriteconfig6 --file konsolerc --group 'TabBar' --key 'TabBarVisibility' 'AlwaysShowTabBar'
# Remove the per-tab close (X) button. Konsole's default is 'OnEachTab'; other
# values are 'OnTabBar' (single X on the bar) and 'None' (no button). Tabs stay
# closable via Ctrl+W and right-click tab -> Close Tab.
kwriteconfig6 --file konsolerc --group 'TabBar' --key 'CloseTabButton' 'None'
# The autobott + prodsystem profiles (and their Autobott / Dracula colorschemes)
# are deployed as files by the linux_kde role (files/konsole/); point Konsole at
# the default (autobott) profile and set the window scheme.
kwriteconfig6 --file konsolerc --group 'Desktop Entry' --key 'DefaultProfile' 'autobott.profile'
kwriteconfig6 --file konsolerc --group 'UiSettings' --key 'ColorScheme' 'BreezeClassic'
# TODO: add shortcut for "find"  Ctrl +F instead of Ctr + Shift + F

# =====================================================================================
# Yakuake
# =====================================================================================

kwriteconfig6 --file yakuakerc --group 'Animation' --key 'Frames' '0'
# Make it more like tabs in a web browser.
kwriteconfig6 --file yakuakerc --group 'Shortcuts' --key 'next-session' 'Ctrl+PgDown'
kwriteconfig6 --file yakuakerc --group 'Shortcuts' --key 'previous-session' 'Ctrl+PgUp'
kwriteconfig6 --file yakuakerc --group 'Shortcuts' --key 'close-session' 'Ctrl+W'
kwriteconfig6 --file yakuakerc --group 'Shortcuts' --key 'new-session' 'Ctrl+T'


kwriteconfig6 --file yakuakerc --group 'Dialogs' --key 'FirstRun' 'false'

kwriteconfig6 --file yakuakerc --group 'Window' --key 'Height' '70'
kwriteconfig6 --file yakuakerc --group 'Window' --key 'Width' '100'
kwriteconfig6 --file yakuakerc --group 'Window' --key 'ShowTabBar' 'true'
kwriteconfig6 --file yakuakerc --group 'Window' --key 'KeepOpen' 'false'
kwriteconfig6 --file yakuakerc --group 'Window' --key 'ShowSystrayIcon' 'false'



# =====================================================================================
# Kwin
# =====================================================================================

kwriteconfig6 --file kwinrc --group 'Windows' --key 'TitlebarDoubleClickCommand' 'Maximize'
# Window-decoration button layout. Despite the KDecoration3 API in Plasma 6, the
# kwinrc config group is still org.kde.kdecoration2 (verified on a live Plasma 6.6).
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft MNSF
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX

# wobbly windows
kwriteconfig6 --file kwinrc --group Plugins --key 'wobblywindowsEnabled' 'true'
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key 'Drag' '92'
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key 'MoveFactor' '20'
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key 'ResizeWobble' 'false'
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key 'Stiffness' '3'
kwriteconfig6 --file kwinrc --group Effect-wobblywindows --key 'WobblynessLevel' '3'

# NOTE: the virtual desktop setup lives in kde-provision-once.sh - it is a
# starting point the user is expected to change, so it is only seeded once.
