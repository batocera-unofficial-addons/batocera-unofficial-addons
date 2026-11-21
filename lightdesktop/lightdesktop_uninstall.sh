#!/bin/bash
# Uninstaller for the Light Desktop, installed by lightdesktop.sh.
# Closes it if it is open, gives F1 back (to KDE Plasma Desktop if that is
# installed, otherwise to the file manager) and removes the add-on and its
# Ports entry. Your wallpaper and pinned apps
# (/userdata/system/configs/lightdesktop) are removed too.

APP_NAME="Light Desktop"
install_dir="/userdata/system/add-ons/lightdesktop"
ports_dir="/userdata/roms/ports"
service_file="/userdata/system/services/lightdesktop"

echo "Removing ${APP_NAME}..."

# Close it if it is open
pid=$(cat /run/lightdesktop.pid 2>/dev/null)
[ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null && sleep 2
rm -f /run/lightdesktop.pid

# F1: stop this desktop's service...
if [ -f "$service_file" ]; then
    bash "$service_file" stop
    batocera-services disable lightdesktop >/dev/null 2>&1
    rm -f "$service_file"
fi
# ...and give it back to KDE Plasma Desktop if that is installed
if [ -f /userdata/system/services/kdeplasma ] && [ -x /userdata/system/add-ons/kdeplasma/kdeplasma-launch.sh ]; then
    batocera-services enable kdeplasma >/dev/null 2>&1
    batocera-services start kdeplasma >/dev/null 2>&1 || bash /userdata/system/services/kdeplasma start
    f1="KDE Plasma"
else
    f1="the file manager"
fi

rm -rf "${install_dir:?}" /userdata/system/configs/lightdesktop
rm -f "$ports_dir/Light Desktop.sh" "$ports_dir/Light Desktop.sh.keys" "$ports_dir/images/lightdesktop-logo.png"
if [ -f "$ports_dir/gamelist.xml" ]; then
    xmlstarlet ed -L -d "/gameList/game[path='./Light Desktop.sh']" "$ports_dir/gamelist.xml"
fi
rm -f /userdata/system/logs/lightdesktop.log

# labwc's full-screen rule for the desktop (Batocera also resets it at boot)
labwc_rc="/userdata/system/.config/labwc/rc.xml"
if [ -f "$labwc_rc" ] && grep -q 'title="Light Desktop"' "$labwc_rc"; then
    xmlstarlet ed -L -d "/labwc_config/windowRules/windowRule[@title='Light Desktop']" "$labwc_rc"
    LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure 2>/dev/null
fi

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo "${APP_NAME} has been removed. F1 opens ${f1} again."
