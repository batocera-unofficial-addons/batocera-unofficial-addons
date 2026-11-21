#!/bin/bash
# Uninstaller for Desktop for Batocera (the native desktop, Install_Desktop.sh).
#
# The add-on keeps a root file system in /userdata/system/add-ons/desktop/rootfs
# and its "desktop" service symlinks those files over Batocera's own at every
# boot, renaming the originals to .bak. One of them is
# /usr/bin/filemanagerlauncher, which F1 runs: the desktop's version closes
# EmulationStation and starts Openbox, tint2 and pcmanfm, which cannot show
# anything on Batocera's Wayland desktop (labwc), so F1 leaves a blank screen.
#
# This puts every original back and removes the add-on, so F1 works again
# right away. It also works on a half-removed install (rootfs already gone,
# links left dangling) and on an older DRL install. Your own files are kept:
# only the files the add-on shipped are removed.

ADDON_NAME="desktop"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
ROOTFS="${ADDON_DIR}/rootfs"
SERVICE_PATH="/userdata/system/services/${ADDON_NAME}"
SERVICE_LOG="/userdata/system/logs/${ADDON_NAME}.log"
TEMP_DIR="/userdata/tmp/Desktop_for_Batocera"
DRL_REMOVER="/userdata/system/configs/bat-drl/Remover_Desktop.sh"

echo "========================================="
echo "Uninstalling: Desktop for Batocera"
echo "========================================="
echo ""

# 1. Leave desktop mode if it is running
echo "Closing desktop mode..."
for proc in tint2 jgmenu picom xcompmgr; do
    pkill -x "$proc" 2>/dev/null
done
pkill -f 'pcmanfm --deskto[p]' 2>/dev/null  # only the desktop, not F1's file manager

# 2. Older DRL installs came with their own remover; run it first
if [ -f "$DRL_REMOVER" ]; then
    echo "Running the older Desktop (DRL) remover..."
    function yad() { return 0; }; export -f yad
    bash "$DRL_REMOVER" </dev/null
    unset -f yad
    rm -f "$DRL_REMOVER"
fi

# 3. Stop the service so it cannot link anything again, and let it undo its
#    own links while its files are still there
if [ -f "$SERVICE_PATH" ]; then
    echo "Stopping and removing the desktop service..."
    bash "$SERVICE_PATH" stop >/dev/null 2>&1
    batocera-services stop "$ADDON_NAME" >/dev/null 2>&1
    batocera-services disable "$ADDON_NAME" >/dev/null 2>&1
    rm -f "$SERVICE_PATH"
fi

# 4. Remove any link still pointing into the add-on (the service skips some,
#    and a half-removed install leaves dangling ones) and put originals back
echo "Restoring Batocera's own files..."
restored=0
while IFS= read -r -d '' link; do
    rm -f "$link"
    if [ -e "${link}.bak" ] || [ -L "${link}.bak" ]; then
        mv -f "${link}.bak" "$link"
    fi
    restored=$((restored + 1))
done < <(find /usr /etc /lib -xdev -lname "${ADDON_DIR}/*" -print0 2>/dev/null)
# Originals the service backed up whose link is already gone
if [ -f "$SERVICE_LOG" ]; then
    sed -n 's/.*Backing up: \(.*\) -> \1\.bak$/\1/p' "$SERVICE_LOG" | sort -u | while IFS= read -r target; do
        if [ -e "${target}.bak" ] && [ ! -e "$target" ]; then
            mv -f "${target}.bak" "$target"
        fi
    done
fi
echo "  ${restored} links removed."

# F1's launcher must be Batocera's again
if [ -L /usr/bin/filemanagerlauncher ] && [ ! -e /usr/bin/filemanagerlauncher ]; then
    rm -f /usr/bin/filemanagerlauncher
fi
if [ ! -e /usr/bin/filemanagerlauncher ]; then
    # Batocera's read-only system image (where it is visible differs by version)
    for layer in /overlay/base /overlay/base2 /overlay_root/base /overlay_root/base2; do
        if [ -f "$layer/usr/bin/filemanagerlauncher" ]; then
            cp -a "$layer/usr/bin/filemanagerlauncher" /usr/bin/filemanagerlauncher
            break
        fi
    done
fi

# 5. Openbox (X11): the add-on replaced Batocera's rc.xml with its own
#    (it keeps Batocera's as rc.xml.es, so that file marks it)
if [ -f /etc/openbox/rc.xml.es ]; then
    # Batocera's read-only system image (where it is visible differs by version)
    for layer in /overlay/base /overlay/base2 /overlay_root/base /overlay_root/base2; do
        if [ -f "$layer/etc/openbox/rc.xml" ]; then
            echo "Restoring Batocera's Openbox settings..."
            cp -f "$layer/etc/openbox/rc.xml" /etc/openbox/rc.xml
            break
        fi
    done
    rm -f /etc/openbox/rc.xml.es
    pgrep -x openbox >/dev/null && openbox --reconfigure >/dev/null 2>&1
fi

# 6. The add-on's own files. The Docker "Desktop" add-on shares this folder;
#    if it is installed too, keep its files.
if [ -d "$ADDON_DIR" ]; then
    echo "Removing the add-on's files..."
    for item in rootfs icons config rc.xml.desktop rc.xml.es; do
        rm -rf --one-file-system "${ADDON_DIR:?}/$item"
    done
    if [ ! -e "$ADDON_DIR/Desktop.AppImage" ]; then
        rm -rf --one-file-system "${ADDON_DIR:?}"
    fi
fi
rm -rf "$TEMP_DIR"

# 7. Settings it installed for its taskbar, menu and file manager, and the
#    shortcuts it put on its desktop (anything you added there is kept)
echo "Removing desktop mode settings..."
rm -rf /userdata/system/.config/tint2 /userdata/system/.config/jgmenu \
       /userdata/system/.config/sublime-text /userdata/system/.config/pcmanfm \
       /userdata/system/.config/libfm
for f in Choose_Browser CoreKeyboard ES FileManagerES Install_WPS_Office \
         Pack_Theme "Shortcut Creator" screenrec; do
    rm -f "/userdata/system/Desktop/$f.desktop"
done
rmdir /userdata/system/Desktop 2>/dev/null
# Its shortcut to Steam's games folder (only the link, never the games;
# a real folder of that name is left alone)
[ -L "/userdata/Steam Games Folder" ] && rm -f "/userdata/Steam Games Folder"
rm -f "$SERVICE_LOG" /userdata/system/logs/tint2.log /userdata/system/logs/picom.log

echo ""
echo "========================================="
echo "Desktop for Batocera has been removed."
echo "F1 opens Batocera's file manager again."
echo "Restart Batocera to reset any remaining icons and themes."
echo "========================================="
