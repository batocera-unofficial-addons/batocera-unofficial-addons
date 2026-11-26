#!/bin/bash
# Starts the Native Wayland Desktop (F1 in EmulationStation, or Ports > Native Wayland Desktop).
# It is a second labwc, Batocera's own compositor, running full screen as a
# window inside Batocera's labwc, with its own taskbar, app menu and
# wallpaper. Closing it (EmulationStation button, Hotkey+Start from Ports)
# returns to EmulationStation, which kept running underneath.
install_dir=/userdata/system/add-ons/native-wayland-desktop
log=/userdata/system/logs/native-wayland-desktop.log
pidfile=/run/native-wayland-desktop.pid
exec > "$log" 2>&1
echo "== $(date) Native Wayland Desktop start"

if ! pgrep -x labwc >/dev/null; then
    echo "The Native Wayland Desktop needs Batocera's Wayland desktop (labwc), not X11 (Openbox)."
    exit 1
fi
# Already open (F1 pressed twice): do nothing
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "The Native Wayland Desktop is already open."
    exit 0
fi

# Full screen, without a title bar: the window is titled "Native Wayland Desktop".
# Batocera rewrites labwc's rc.xml at every boot, so add the rule each time.
labwc_rc="/userdata/system/.config/labwc/rc.xml"
if [ -f "$labwc_rc" ] && ! grep -q 'title="Native Wayland Desktop"' "$labwc_rc"; then
    xmlstarlet ed -L \
        -s "/labwc_config/windowRules" -t elem -n "windowRule" -v "" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t attr -n "title" -v "Native Wayland Desktop" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t attr -n "serverDecoration" -v "no" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t elem -n "action" -v "" \
        -s "/labwc_config/windowRules/windowRule[last()]/action" -t attr -n "name" -v "ToggleFullscreen" \
        "$labwc_rc" \
        && LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure
fi

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export HOME=/userdata/system
# Programs started in the desktop use its own Xwayland, so X11 apps open
# inside it too
unset DISPLAY LABWC_PID
export XDG_CURRENT_DESKTOP=labwc:wlroots
export XDG_MENU_PREFIX=batocera-
export XDG_CACHE_HOME=/tmp/xdg_cache   # PCManFM on an exFAT /userdata, like F1's file manager
export NATIVE_WAYLAND_DESKTOP=1
# Dark mode for the file manager, text editor and other GTK apps (only
# inside the desktop; F1's file manager elsewhere keeps its look)
export GTK_THEME=Adwaita:dark

# Batocera hides the mouse cursor for EmulationStation; show it while the
# desktop is open, like F1's file manager does
batocera-backglass disable 2>/dev/null
batocera-mouse show

cd /userdata
labwc -C "$install_dir/config" -t "Native Wayland Desktop" &
echo $! > "$pidfile"
wait $!
status=$?
rm -f "$pidfile"

batocera-mouse hide
batocera-backglass enable 2>/dev/null
echo "== $(date) Native Wayland Desktop closed ($status)"
