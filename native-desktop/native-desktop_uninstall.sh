#!/bin/bash
# Uninstaller for Native Desktop — removes whichever variant is installed
# (Native X11 Desktop or Native Wayland Desktop) and any older desktop.

echo "========================================="
echo "Uninstalling: Native Desktop"
echo "========================================="
echo ""

LIGHT_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/native-wayland-desktop"
f1="the file manager"

# --- Remove Native Wayland Desktop if installed ---
if [ -d /userdata/system/add-ons/native-wayland-desktop ] || [ -f /userdata/system/services/native_wayland_desktop ] || [ -f /userdata/system/services/native-wayland-desktop ]; then
    echo "Removing Native Wayland Desktop..."
    curl -fsSL "$LIGHT_URL/native-wayland-desktop_uninstall.sh" | bash
    echo ""
fi

# --- Remove lightweight Native X11 Desktop if installed ---
if { [ -d /userdata/system/add-ons/native-x11-desktop ] && [ ! -d /userdata/system/add-ons/native-x11-desktop/rootfs ]; } || \
   [ -f /userdata/system/services/native_x11_desktop ]; then
    echo "Removing Native X11 Desktop..."

    # Close it if running
    pid=$(cat /run/native-x11-desktop.pid 2>/dev/null)
    if [ -n "$pid" ]; then
        kill -TERM "$pid" 2>/dev/null
        sleep 2
    fi
    rm -f /run/native-x11-desktop.pid

    # Stop and remove service
    # (native-x11-desktop is the old name, from before hyphens were dropped)
    for svc in native_x11_desktop native-x11-desktop; do
        if [ -f "/userdata/system/services/$svc" ]; then
            bash "/userdata/system/services/$svc" stop 2>/dev/null
            batocera-services disable "$svc" >/dev/null 2>&1
            rm -f "/userdata/system/services/$svc"
        fi
    done

    # Restore Openbox config if desktop was active
    if [ -f /tmp/native-x11-desktop-rc-backup.xml ]; then
        cp /tmp/native-x11-desktop-rc-backup.xml /etc/openbox/rc.xml
        rm -f /tmp/native-x11-desktop-rc-backup.xml
        pgrep -x openbox >/dev/null && openbox --reconfigure >/dev/null 2>&1
    fi

    # Remove addon files and configs
    rm -rf /userdata/system/add-ons/native-x11-desktop
    rm -rf /userdata/system/configs/native-x11-desktop
    rm -f /userdata/system/logs/native-x11-desktop.log

    # Remove Ports entry
    ports_dir="/userdata/roms/ports"
    rm -f "$ports_dir/Native X11 Desktop.sh" "$ports_dir/Native X11 Desktop.sh.keys"
    rm -f "$ports_dir/images/native-x11-desktop-logo.png"
    if [ -f "$ports_dir/gamelist.xml" ]; then
        xmlstarlet ed -L -d "/gameList/game[path='./Native X11 Desktop.sh']" "$ports_dir/gamelist.xml"
    fi

    # Give F1 to KDE Plasma if installed, otherwise file manager
    if [ -f /userdata/system/services/kdeplasma ] && [ -x /userdata/system/add-ons/kdeplasma/kdeplasma-launch.sh ]; then
        batocera-services enable kdeplasma >/dev/null 2>&1
        batocera-services start kdeplasma >/dev/null 2>&1
        f1="KDE Plasma"
    fi

    echo "Native X11 Desktop removed."
fi

# --- Remove older desktops ---
# Light Desktop, Desktop for Batocera (squashfs / reworked DRL) and the
# original DRL desktop. Shared with native-desktop.sh; the Docker "Desktop"
# add-on is never touched.
REPO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main"
cleanup_script=$(mktemp)
if curl -fsSL -o "$cleanup_script" "$REPO_URL/native-desktop/native-desktop-legacy-cleanup.sh"; then
    bash "$cleanup_script" uninstall
else
    echo "Could not download the cleanup for older desktops; skipped."
fi
rm -f "$cleanup_script"

# F1 back to KDE Plasma if it is installed (the file manager otherwise)
if [ -f /userdata/system/services/kdeplasma ] && [ -x /userdata/system/add-ons/kdeplasma/kdeplasma-launch.sh ]; then
    batocera-services enable kdeplasma >/dev/null 2>&1
    batocera-services start kdeplasma >/dev/null 2>&1
    f1="KDE Plasma"
fi

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo ""
echo "========================================="
echo "Native Desktop has been removed."
echo "F1 opens ${f1} again."
echo "========================================="
