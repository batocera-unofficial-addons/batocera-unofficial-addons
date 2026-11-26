#!/bin/bash
# Uninstaller for the Native Wayland Desktop, installed by native-wayland-desktop.sh.
# Closes it if it is open, gives F1 back (to KDE Plasma Desktop if that is
# installed, otherwise to the file manager) and removes the add-on and its
# Ports entry. Your wallpaper and pinned apps
# (/userdata/system/configs/native-wayland-desktop) are removed too; the Desktop folder
# (/userdata/system/Desktop) and what is in it are kept.

APP_NAME="Native Wayland Desktop"
install_dir="/userdata/system/add-ons/native-wayland-desktop"
ports_dir="/userdata/roms/ports"

echo "Removing ${APP_NAME}..."

# Close it if it is open
pid=$(cat /run/native-wayland-desktop.pid 2>/dev/null)
[ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null && sleep 2
rm -f /run/native-wayland-desktop.pid

# F1: stop this desktop's service...
# (native-wayland-desktop is the old name, from before hyphens were dropped)
for svc in native_wayland_desktop native-wayland-desktop; do
    if [ -f "/userdata/system/services/$svc" ]; then
        bash "/userdata/system/services/$svc" stop
        batocera-services disable "$svc" >/dev/null 2>&1
        rm -f "/userdata/system/services/$svc"
    fi
done
# ...and give it back to KDE Plasma Desktop if that is installed
if [ -f /userdata/system/services/kdeplasma ] && [ -x /userdata/system/add-ons/kdeplasma/kdeplasma-launch.sh ]; then
    batocera-services enable kdeplasma >/dev/null 2>&1
    batocera-services start kdeplasma >/dev/null 2>&1 || bash /userdata/system/services/kdeplasma start
    f1="KDE Plasma"
else
    f1="the file manager"
fi

rm -rf "${install_dir:?}" /userdata/system/configs/native-wayland-desktop
rm -f "$ports_dir/Native Wayland Desktop.sh" "$ports_dir/Native Wayland Desktop.sh.keys" "$ports_dir/images/native-wayland-desktop-logo.png"
if [ -f "$ports_dir/gamelist.xml" ]; then
    xmlstarlet ed -L -d "/gameList/game[path='./Native Wayland Desktop.sh']" "$ports_dir/gamelist.xml"
fi
rm -f /userdata/system/logs/native-wayland-desktop.log

# labwc's full-screen rule for the desktop (Batocera also resets it at boot)
labwc_rc="/userdata/system/.config/labwc/rc.xml"
if [ -f "$labwc_rc" ] && grep -q 'title="Native Wayland Desktop"' "$labwc_rc"; then
    xmlstarlet ed -L -d "/labwc_config/windowRules/windowRule[@title='Native Wayland Desktop']" "$labwc_rc"
    LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure 2>/dev/null
fi

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo "${APP_NAME} has been removed. F1 opens ${f1} again."
