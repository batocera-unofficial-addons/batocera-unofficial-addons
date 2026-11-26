#!/bin/bash
# Started by the Native Wayland Desktop's labwc (config/autostart): the desktop
# (wallpaper and icons) and the panel. Each is started again if it ever
# crashes, for as long as the desktop is open.
dir=/userdata/system/add-ons/native-wayland-desktop
keep_running() {
    while [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
        python3 "$dir/$1"
        sleep 1
    done
}
keep_running native-wayland-desktop-desktop.py &
keep_running native-wayland-desktop-panel.py
