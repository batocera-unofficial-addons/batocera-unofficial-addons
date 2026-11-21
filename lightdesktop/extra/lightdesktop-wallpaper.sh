#!/bin/bash
# (Re)starts the Light Desktop's wallpaper: a picture chosen with "Change
# wallpaper" (saved as /userdata/system/configs/lightdesktop/wallpaper.*),
# or else the add-on's own.
img=$(ls /userdata/system/configs/lightdesktop/wallpaper.* 2>/dev/null | head -1)
[ -f "$img" ] || img=/userdata/system/add-ons/lightdesktop/wallpaper.png
pkill -f '^swaybg -m fill -i .*lightdeskto[p]'
exec swaybg -m fill -i "$img"
