#!/bin/bash
# Uninstaller for Native Desktop — removes whichever variant is installed
# (Native X11 Desktop, Native Wayland Desktop, or old squashfs desktop).

echo "========================================="
echo "Uninstalling: Native Desktop"
echo "========================================="
echo ""

LIGHT_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/native-wayland-desktop"
f1="the file manager"

# --- Remove Native Wayland Desktop if installed ---
if [ -d /userdata/system/add-ons/native-wayland-desktop ] || [ -f /userdata/system/services/native-wayland-desktop ]; then
    echo "Removing Native Wayland Desktop..."
    curl -fsSL "$LIGHT_URL/native-wayland-desktop_uninstall.sh" | bash
    echo ""
fi

# --- Remove lightweight Native X11 Desktop if installed ---
if [ -d /userdata/system/add-ons/native-x11-desktop ] && [ ! -d /userdata/system/add-ons/native-x11-desktop/rootfs ]; then
    echo "Removing Native X11 Desktop..."

    # Close it if running
    pid=$(cat /run/native-x11-desktop.pid 2>/dev/null)
    if [ -n "$pid" ]; then
        kill -TERM "$pid" 2>/dev/null
        sleep 2
    fi
    rm -f /run/native-x11-desktop.pid

    # Stop and remove service
    if [ -f /userdata/system/services/native-x11-desktop ]; then
        bash /userdata/system/services/native-x11-desktop stop 2>/dev/null
        batocera-services disable native-x11-desktop >/dev/null 2>&1
        rm -f /userdata/system/services/native-x11-desktop
    fi

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

# --- Remove old squashfs-based desktop if present ---
DRL_REMOVER="/userdata/system/configs/bat-drl/Remover_Desktop.sh"
OLD_ROOTFS="/userdata/system/add-ons/native-x11-desktop/rootfs"
OLD_DESKTOP_ROOTFS="/userdata/system/add-ons/desktop/rootfs"

if [ -d "$OLD_ROOTFS" ] || [ -d "$OLD_DESKTOP_ROOTFS" ] || [ -f "$DRL_REMOVER" ]; then
    echo "Removing old squashfs desktop..."

    # Kill old desktop processes
    for proc in tint2 jgmenu picom xcompmgr; do
        pkill -x "$proc" 2>/dev/null
    done
    pkill -f 'pcmanfm --deskto[p]' 2>/dev/null

    # Run DRL remover if present
    if [ -f "$DRL_REMOVER" ]; then
        function yad() { return 0; }; export -f yad
        bash "$DRL_REMOVER" </dev/null 2>/dev/null
        unset -f yad
        rm -f "$DRL_REMOVER"
    fi

    # Stop old services
    for svc in desktop native-x11-desktop desktop_drl; do
        if [ -f "/userdata/system/services/$svc" ]; then
            bash "/userdata/system/services/$svc" stop >/dev/null 2>&1
            batocera-services stop "$svc" >/dev/null 2>&1
            batocera-services disable "$svc" >/dev/null 2>&1
            rm -f "/userdata/system/services/$svc"
        fi
    done

    # Remove old addon dirs
    rm -rf /userdata/system/add-ons/desktop
    rm -rf /userdata/system/add-ons/native-x11-desktop
    rm -rf /userdata/system/add-ons/desktop_drl
    rm -rf /userdata/tmp/native-desktop

    # Restore Openbox config
    if [ -f /etc/openbox/rc.xml.es ]; then
        for layer in /overlay/base /overlay/base2 /overlay_root/base /overlay_root/base2; do
            if [ -f "$layer/etc/openbox/rc.xml" ]; then
                cp -f "$layer/etc/openbox/rc.xml" /etc/openbox/rc.xml
                break
            fi
        done
        rm -f /etc/openbox/rc.xml.es
        pgrep -x openbox >/dev/null && openbox --reconfigure >/dev/null 2>&1
    fi

    # Clean up old desktop settings
    rm -rf /userdata/system/.config/tint2 /userdata/system/.config/jgmenu \
           /userdata/system/.config/sublime-text /userdata/system/.config/pcmanfm \
           /userdata/system/.config/libfm

    echo "Old squashfs desktop removed."
fi

curl -s http://127.0.0.1:1234/reloadgames >/dev/null

echo ""
echo "========================================="
echo "Native Desktop has been removed."
echo "F1 opens ${f1} again."
echo "========================================="
