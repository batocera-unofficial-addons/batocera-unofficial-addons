#!/bin/bash
# Starts the Native X11 Desktop (F1 in EmulationStation, or Ports > Native X11 Desktop).
# Reconfigures Openbox with a desktop-friendly setup (keybinds, theme), starts
# the panel and desktop scripts, then restores the ES Openbox config on exit.
install_dir=/userdata/system/add-ons/native-x11-desktop
log=/userdata/system/logs/native-x11-desktop.log
pidfile=/run/native-x11-desktop.pid
rc_backup=/tmp/native-x11-desktop-rc-backup.xml
exec > "$log" 2>&1
echo "== $(date) Native X11 Desktop start"

if ! pgrep -x openbox >/dev/null; then
    echo "The Native X11 Desktop needs Batocera's X11 desktop (Openbox)."
    exit 1
fi
# Already open (F1 pressed twice): do nothing
if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "The Native X11 Desktop is already open."
    exit 0
fi

echo $$ > "$pidfile"

# Save the current Openbox config and apply the desktop version
cp /etc/openbox/rc.xml "$rc_backup"
cp "$install_dir/config/rc.xml" /etc/openbox/rc.xml
openbox --reconfigure

# Apply the desktop right-click menu
cp "$install_dir/config/menu.xml" /etc/openbox/menu.xml 2>/dev/null
openbox --reconfigure

export HOME=/userdata/system
export DISPLAY="${DISPLAY:-:0.0}"
export XDG_MENU_PREFIX=batocera-
export XDG_CACHE_HOME=/tmp/xdg_cache
export NATIVE_X11_DESKTOP=1
export GTK_THEME=Adwaita:dark

# Show mouse cursor while desktop is open
batocera-backglass disable 2>/dev/null
batocera-mouse show

cd /userdata
"$install_dir/native-x11-desktop-session.sh" &
session_pid=$!
wait $session_pid
status=$?

# Cleanup: restore original Openbox config
rm -f "$pidfile"
if [ -f "$rc_backup" ]; then
    cp "$rc_backup" /etc/openbox/rc.xml
    rm -f "$rc_backup"
    openbox --reconfigure
fi

batocera-mouse hide
batocera-backglass enable 2>/dev/null
echo "== $(date) Native X11 Desktop closed ($status)"
