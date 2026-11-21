#!/bin/bash
# Started by the Light Desktop's labwc (config/autostart): the desktop
# (wallpaper and icons) and the panel. Each is started again if it ever
# crashes, for as long as the desktop is open.
dir=/userdata/system/add-ons/lightdesktop
keep_running() {
    while [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
        python3 "$dir/$1"
        sleep 1
    done
}
keep_running lightdesktop-desktop.py &
keep_running lightdesktop-panel.py
