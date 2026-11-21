#!/bin/bash
# Started by the Light Desktop's labwc (config/autostart): the wallpaper and
# the panel. The panel is started again if it ever crashes, for as long as
# the desktop is open.
dir=/userdata/system/add-ons/lightdesktop
"$dir/lightdesktop-wallpaper.sh" &
while [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
    python3 "$dir/lightdesktop-panel.py"
    sleep 1
done
