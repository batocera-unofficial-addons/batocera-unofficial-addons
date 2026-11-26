#!/bin/bash
# Started by the launch script: the desktop (wallpaper and icons) and the
# panel. Each is restarted if it crashes, for as long as the desktop is open.
dir=/userdata/system/add-ons/native-x11-desktop
keep_running() {
    while [ -f /run/native-x11-desktop.pid ]; do
        python3 "$dir/$1"
        sleep 1
    done
}
keep_running native-x11-desktop-desktop.py &
keep_running native-x11-desktop-panel.py
