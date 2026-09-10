#! /usr/bin/env sh
# KDE 6 / Plasma 6 variant of kwriteconfig.sh (uses the kwriteconfig6 binary).
# based on https://github.com/nbeaver/config-kde5/blob/master/config-kde.sh

# Do not obey DRM limitations.
kwriteconfig6 --file okularpartrc --group 'Core General' --key 'ObeyDRM' --type 'bool' 'false'


# =====================================================================================
# KDE Global
# =====================================================================================

kwriteconfig6 --file kdeglobals --group 'KDE' --key 'AnimationDurationFactor' '0.125'
kwriteconfig6 --file kdeglobals --group 'General' --key 'BrowserApplication' 'google-chrome.desktop'


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

kwriteconfig6 --file kglobalshortcutsrc --group 'yakuake' --key 'toggle-window-state' 'F12,F12,Open/Retract Yakuake'


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


# =====================================================================================
# Konsole
# =====================================================================================
kwriteconfig6 --file konsolerc --group 'KonsoleWindow' --key 'RememberWindowSize' 'false'
# TODO: add shortcut for "find"  Ctrl +F instead of Ctr + Shift + F
# TODO: automate profile with dark pastels color, probably using elementary breeze pacakge
# TODO: make setting to have session tabs always visible

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

# wobly windows
kwriteconfig6 --file kwinrc --group Plugins --key 'wobblywindowsEnabled' 'true'
kwriteconfig6 --file kwinrc --group Effect-Wobbly --key 'Drag' '92'
kwriteconfig6 --file kwinrc --group Effect-Wobbly --key 'MoveFactor' '20'
kwriteconfig6 --file kwinrc --group Effect-Wobbly --key 'ResizeWobble' 'false'
kwriteconfig6 --file kwinrc --group Effect-Wobbly --key 'Stiffness' '3'
kwriteconfig6 --file kwinrc --group Effect-Wobbly --key 'WobblynessLevel' '3'
