#! /usr/bin/env sh
# based on https://github.com/nbeaver/config-kde5/blob/master/config-kde.sh

# Do not obey DRM limitations.
kwriteconfig5 --file okularpartrc --group 'Core General' --key 'ObeyDRM' --type 'bool' 'false'


# =====================================================================================
# KDE Global
# =====================================================================================

kwriteconfig5 --file kdeglobals --group 'KDE' --key 'AnimationDurationFactor' '0.125'
kwriteconfig5 --file kdeglobals --group 'General' --key 'BrowserApplication' 'google-chrome.desktop'


# =====================================================================================
# Shortcuts
# =====================================================================================
kwriteconfig5 --file kdeglobals --group 'Shortcuts' --key 'NextCompletion' ''
kwriteconfig5 --file kdeglobals --group 'Shortcuts' --key 'PrevCompletion' ''
kwriteconfig5 --file kdeglobals --group 'Shortcuts' --key 'ShowMenubar' ''

kwriteconfig5 --file kglobalshortcutsrc --group 'kmix' --key 'decrease_volume' 'Ctrl+Down,Volume Down,Decrease Volume'
kwriteconfig5 --file kglobalshortcutsrc --group 'kmix' --key 'increase_volume' 'Ctrl+Up,Volume Up,Increase Volume'
kwriteconfig5 --file kglobalshortcutsrc --group 'kmix' --key 'mute' 'Ctrl+M,Volume Mute,Mute'

kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window Maximize' 'Meta+Ctrl+Alt+Up,Meta+PgUp,Maximize Window'
kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window Minimize' 'Meta+Ctrl+Alt+Down,Meta+PgDown,Minimize Window'
kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window Quick Tile Left' 'Meta+Ctrl+Alt+Left,Meta+Left,Quick Tile Window to the Left'
kwriteconfig5 --file kglobalshortcutsrc --group 'kwin' --key 'Window Quick Tile Right' 'Meta+Ctrl+Alt+Right,Meta+Right,Quick Tile Window to the Right'

kwriteconfig5 --file kglobalshortcutsrc --group 'yakuake' --key 'toggle-window-state' "Eject F12,F12,Open/Retract Yakuake"


# =====================================================================================
# Dolphin
# ================================= ====================================================
kwriteconfig5 --file konsolerc --group 'DetailsMode' --key 'PreviewSize' '16'
kwriteconfig5 --file konsolerc --group 'IconsMode' --key 'PreviewSize' '265'
kwriteconfig5 --file konsolerc --group 'MainWindow' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig5 --file konsolerc --group 'MainWindow' --key 'MenuBar' 'Disabled'
kwriteconfig5 --file konsolerc --group 'MainWindow' --key 'ToolBarsMovable' 'Disabled'
kwriteconfig5 --file konsolerc --group 'Toolbar mainToolBar' --key 'ToolButtonStyle' 'IconOnly'
kwriteconfig5 --file konsolerc --group 'TabBar' --key 'TabBarVisibility' 'AlwaysShowTabBar'


# =====================================================================================
# Konsole
# =====================================================================================
kwriteconfig5 --file konsolerc --group 'KonsoleWindow' --key 'RememberWindowSize' 'false'
# TODO: add shortcut for "find"  Ctrl +F instead of Ctr + Shift + F
# TODO: automate profile with dark pastels color, probably using elementary breeze pacakge
# TODO: make setting to have session tabs always visible

# =====================================================================================
# Yakuake
# =====================================================================================

kwriteconfig5 --file yakuakerc --group 'Animation' --key 'Frames' '0'
# Make it more like tabs in a web browser.
kwriteconfig5 --file yakuakerc --group 'Shortcuts' --key 'next-session' 'Ctrl+PgDown'
kwriteconfig5 --file yakuakerc --group 'Shortcuts' --key 'previous-session' 'Ctrl+PgUp'
kwriteconfig5 --file yakuakerc --group 'Shortcuts' --key 'close-session' 'Ctrl+W'
kwriteconfig5 --file yakuakerc --group 'Shortcuts' --key 'new-session' 'Ctrl+T'


kwriteconfig5 --file yakuakerc --group 'Dialogs' --key 'FirstRun' 'false'

kwriteconfig5 --file yakuakerc --group 'Window' --key 'Height' '70'
kwriteconfig5 --file yakuakerc --group 'Window' --key 'Width' '100'
kwriteconfig5 --file yakuakerc --group 'Window' --key 'ShowTabBar' 'true'
kwriteconfig5 --file yakuakerc --group 'Window' --key 'KeepOpen' 'false'
kwriteconfig5 --file yakuakerc --group 'Window' --key 'ShowSystrayIcon' 'false'



# =====================================================================================
# Kwin
# =====================================================================================

kwriteconfig5 --file kwinrc --group 'Windows' --key 'TitlebarDoubleClickCommand' 'Maximize'
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft MNSF
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight IAX

# wobly windows
kwriteconfig5 --file kwinrc --group Plugins --key 'wobblywindowsEnabled' 'true'
kwriteconfig5 --file kwinrc --group Effect-Wobbly --key 'Drag' '92'
kwriteconfig5 --file kwinrc --group Effect-Wobbly --key 'MoveFactor' '20'
kwriteconfig5 --file kwinrc --group Effect-Wobbly --key 'ResizeWobble' 'false'
kwriteconfig5 --file kwinrc --group Effect-Wobbly --key 'Stiffness' '3'
kwriteconfig5 --file kwinrc --group Effect-Wobbly --key 'WobblynessLevel' '3'

# virtual desktops
kwriteconfig5 --file kwinrc --group Desktops --key 'Id_1' '28e33d8f-a554-492c-82a9-9cd0ba8b0235'
kwriteconfig5 --file kwinrc --group Desktops --key 'Id_2' '04b36c7f-15f5-4d13-bd38-664a46617547'
kwriteconfig5 --file kwinrc --group Desktops --key 'Rows' '1'
kwriteconfig5 --file kwinrc --group Desktops --key 'Number' '2'
