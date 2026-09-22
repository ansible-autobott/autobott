#! /usr/bin/env sh
# One-time per-user KDE Plasma 6 provisioning (uses the kwriteconfig6 binary).
#
# SEEDED ONCE: the linux_kde role runs this only while the marker file
# ~/.local/state/autobott/kde-provisioned is absent, and writes that marker
# afterwards. Everything here is therefore a *starting point* the user is free
# to change from System Settings - autobott will not revert it.
#
# Settings that must stay as autobott defines them belong in kwriteconfig6.sh,
# which is re-asserted on every run.

# =====================================================================================
# Kwin - virtual desktops
# =====================================================================================
# Two desktops in a single row. The Id_* keys are the stable UUIDs Plasma uses to
# reference each desktop (from panel widgets, window rules and kglobalshortcutsrc);
# they are seeded to fixed values so a freshly provisioned machine is reproducible.
# Adding or removing desktops later (System Settings > Virtual Desktops) rewrites
# these keys - that is expected and is left alone.
kwriteconfig6 --file kwinrc --group Desktops --key 'Id_1' '28e33d8f-a554-492c-82a9-9cd0ba8b0235'
kwriteconfig6 --file kwinrc --group Desktops --key 'Id_2' '04b36c7f-15f5-4d13-bd38-664a46617547'
kwriteconfig6 --file kwinrc --group Desktops --key 'Rows' '1'
kwriteconfig6 --file kwinrc --group Desktops --key 'Number' '2'
