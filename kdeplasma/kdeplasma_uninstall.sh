#!/bin/bash
# Uninstaller for KDE Plasma Desktop, installed by kdeplasma.sh.
# Gives F1 back to the file manager, removes the Ports entry and deletes the
# Plasma system (/userdata/system/add-ons/kdeplasma). Your own files are
# never touched: Plasma's view of /userdata is unmounted first, and nothing
# is deleted while any of its mounts remain.

APP_NAME="KDE Plasma Desktop"
install_dir="/userdata/system/add-ons/kdeplasma"
root="$install_dir/rootfs"
ports_dir="/userdata/roms/ports"
service_file="/userdata/system/services/kdeplasma"

echo "Removing ${APP_NAME}..."

# Log out of Plasma if it is running, and stop anything left in the container
pkill -f '^/usr/bin/startplasma-waylan[d]' 2>/dev/null
sleep 3
ns=$(cat /run/kdeplasma.mntns 2>/dev/null)
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
    # In the container's own mount namespace, or (older versions) chrooted into it
    if { [ -n "$ns" ] && [ "$(readlink /proc/$pid/ns/mnt 2>/dev/null)" = "$ns" ]; } \
        || [ "$(readlink /proc/$pid/root 2>/dev/null)" = "$root" ]; then
        kill -9 "$pid" 2>/dev/null
    fi
done
rm -f /run/kdeplasma.mntns

# F1 back to the file manager...
if [ -f "$service_file" ]; then
    bash "$service_file" stop
    batocera-services disable kdeplasma >/dev/null 2>&1
    rm -f "$service_file"
fi
# ...and back to the Native Wayland Desktop if that is installed
f1="the file manager"
if [ -f /userdata/system/services/native-wayland-desktop ] && [ -x /userdata/system/add-ons/native-wayland-desktop/native-wayland-desktop-launch.sh ]; then
    batocera-services enable native-wayland-desktop >/dev/null 2>&1
    batocera-services start native-wayland-desktop >/dev/null 2>&1 || bash /userdata/system/services/native-wayland-desktop start
    f1="the Native Wayland Desktop"
fi

# Unmount everything inside the container (including its view of /userdata)
for _ in 1 2 3 4 5 6 7 8; do
    mounts=$(awk -v r="$root" 'index($2, r)==1 {print $2}' /proc/mounts | sort -r)
    [ -z "$mounts" ] && break
    for m in $mounts; do umount -l "$m" 2>/dev/null; done
    sleep 1
done
if awk -v r="$root" 'index($2, r)==1 {f=1} END {exit !f}' /proc/mounts; then
    dialog --title "KDE Plasma" --msgbox "Some of Plasma's folders are still mounted, so nothing was deleted. Restart Batocera and run the uninstaller again." 8 60
    exit 1
fi

# Delete the Plasma system. --one-file-system is a second guard: rm never
# crosses into another mount.
rm -rf --one-file-system "${install_dir:?}"

# Ports entry and logo
rm -f "$ports_dir/KDE Plasma.sh" "$ports_dir/KDE Plasma.sh.keys" "$ports_dir/images/kdeplasma-logo.png"
if [ -f "$ports_dir/gamelist.xml" ]; then
    xmlstarlet ed -L -d "/gameList/game[path='./KDE Plasma.sh']" "$ports_dir/gamelist.xml"
fi
rm -f /userdata/system/logs/kdeplasma.log /userdata/system/logs/kdeplasma-install.log

# labwc's full-screen rule for Plasma (Batocera also resets it at boot)
labwc_rc="/userdata/system/.config/labwc/rc.xml"
if [ -f "$labwc_rc" ] && grep -q 'title="KDE Wayland Compositor\*"' "$labwc_rc"; then
    xmlstarlet ed -L -d "/labwc_config/windowRules/windowRule[@title='KDE Wayland Compositor*']" "$labwc_rc"
    LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure 2>/dev/null
fi

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo "${APP_NAME} has been removed. F1 opens ${f1} again."
