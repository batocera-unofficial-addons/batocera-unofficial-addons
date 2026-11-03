#!/bin/bash
# Opens Kyty's own launcher window (settings, input mapping, game list), for
# the F1 > Applications entry the installer adds.

install_dir="/userdata/system/add-ons/kytyps5"

# Auto-detect the X display (it can be :0 or :1 depending on how X started)
[ -n "$DISPLAY" ] || export DISPLAY=:$(ls /tmp/.X11-unix | head -n1 | tr -dc 0-9).0
export QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY

cd "$install_dir" || exit 1
exec "$install_dir/kyty_launcher" > /userdata/system/logs/kyty-launcher.log 2>&1
