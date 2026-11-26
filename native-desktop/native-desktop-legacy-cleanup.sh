#!/bin/bash
# Removes the desktops that Native Desktop replaced, so they cannot keep F1 or
# leave broken files behind. Run by native-desktop.sh (before installing) and
# native-desktop_uninstall.sh:
#
#   native-desktop-legacy-cleanup.sh install     keep Light Desktop settings
#   native-desktop-legacy-cleanup.sh uninstall   remove everything
#
# It handles three old desktops:
#   1. Light Desktop (lightdesktop) - "Desktop For Batocera" on Wayland
#   2. Desktop for Batocera - the reworked DRL desktop: a squashfs rootfs in
#      add-ons/desktop and a "desktop" service that symlinks it (and its icon
#      packs) over Batocera's files at boot, keeping the originals as .bak.
#      Nothing of it is in Batocera's saved overlay.
#   3. The original DRL desktop - written into Batocera's overlay and kept
#      with batocera-save-overlay, with its own remover
#
# /userdata survives an image switch, so all three are checked on X11 and
# Wayland. The Docker "Desktop" add-on shares /userdata/system/add-ons/desktop
# (Desktop.AppImage, BatoDesktop.sh in Ports, the docker and symlink_manager
# services): none of its files are touched.

mode="${1:-uninstall}"
OVL=/overlay/overlay   # Batocera's overlay upper layer (where DRL wrote)

# Batocera's read-only system image (where it is visible differs by version)
base_copy() {
    for layer in /overlay/base /overlay/base2 /overlay_root/base /overlay_root/base2; do
        if [ -e "$layer$1" ]; then echo "$layer$1"; return 0; fi
    done
    return 1
}

stop_service() {
    [ -f "/userdata/system/services/$1" ] || return 0
    bash "/userdata/system/services/$1" stop >/dev/null 2>&1
    batocera-services stop "$1" >/dev/null 2>&1
    batocera-services disable "$1" >/dev/null 2>&1
    rm -f "/userdata/system/services/$1"
}

# Old desktop-mode processes (only the desktop's pcmanfm, not F1's file manager)
close_x11_desktop_mode() {
    for proc in tint2 jgmenu picom xcompmgr; do
        pkill -x "$proc" 2>/dev/null
    done
    pkill -f 'pcmanfm --deskto[p]' 2>/dev/null
}

# F1's launcher must be Batocera's own again
restore_filemanagerlauncher() {
    local f=/usr/bin/filemanagerlauncher src
    if [ -L "$f" ] && [ ! -e "$f" ]; then
        rm -f "$f"
    fi
    if [ ! -e "$f" ] && src=$(base_copy "$f"); then
        cp -a "$src" "$f"
    fi
}

# --- 1. Light Desktop ---------------------------------------------------------
cleanup_lightdesktop() {
    [ -d /userdata/system/add-ons/lightdesktop ] || [ -f /userdata/system/services/lightdesktop ] || \
    [ -d /userdata/system/configs/lightdesktop ] || [ -f "/userdata/roms/ports/Light Desktop.sh" ] || return 0
    echo "Removing old Light Desktop..."

    pid=$(cat /run/lightdesktop.pid 2>/dev/null)
    [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null && sleep 2
    rm -f /run/lightdesktop.pid

    # F1: its service bind-mounts its launcher over filemanagerlauncher. The
    # new desktops' services only mount when nothing is bound there, so this
    # has to go first or F1 keeps opening the removed Light Desktop.
    stop_service lightdesktop
    if [ /usr/bin/filemanagerlauncher -ef /userdata/system/add-ons/lightdesktop/lightdesktop-launch.sh ]; then
        while awk '$2=="/usr/bin/filemanagerlauncher" {f=1} END {exit !f}' /proc/mounts; do
            umount /usr/bin/filemanagerlauncher || break
        done
    fi

    # Wallpaper, pinned apps and icon positions use the same layout as Native
    # Desktop's: on install, move them over if it has none yet
    if [ "$mode" = install ] && [ -d /userdata/system/configs/lightdesktop ]; then
        if pgrep -x labwc >/dev/null 2>&1; then
            new_conf=/userdata/system/configs/native-wayland-desktop
        else
            new_conf=/userdata/system/configs/native-x11-desktop
        fi
        [ -e "$new_conf" ] || mv /userdata/system/configs/lightdesktop "$new_conf"
    fi
    rm -rf /userdata/system/configs/lightdesktop
    rm -rf /userdata/system/add-ons/lightdesktop
    rm -f /userdata/system/logs/lightdesktop.log

    local ports=/userdata/roms/ports
    rm -f "$ports/Light Desktop.sh" "$ports/Light Desktop.sh.keys" "$ports/images/lightdesktop-logo.png"
    if [ -f "$ports/gamelist.xml" ]; then
        xmlstarlet ed -L -d "/gameList/game[path='./Light Desktop.sh']" "$ports/gamelist.xml"
    fi

    # labwc's full-screen window rule for it
    local labwc_rc=/userdata/system/.config/labwc/rc.xml
    if [ -f "$labwc_rc" ] && grep -q 'title="Light Desktop"' "$labwc_rc"; then
        xmlstarlet ed -L -d "/labwc_config/windowRules/windowRule[@title='Light Desktop']" "$labwc_rc"
        pgrep -x labwc >/dev/null 2>&1 && LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure 2>/dev/null
    fi
    echo "Old Light Desktop removed."
}

# --- 2. Desktop for Batocera (reworked DRL, service based) --------------------
# $1 = add-on folder, $2 = its service name
cleanup_squashfs_desktop() {
    local dir="$1" svc="$2" rootfs="$1/rootfs"
    # Its marks: the rootfs, Batocera's Openbox config kept aside, or links
    # into the rootfs. (native-x11-desktop is also the current X11 desktop's
    # folder: only the squashfs version has a rootfs.)
    if [ "$svc" = desktop ]; then
        [ -d "$rootfs" ] || [ -f "/userdata/system/services/$svc" ] || [ -f /etc/openbox/rc.xml.es ] || \
            [ -n "$(find /usr/bin -maxdepth 1 -lname "$rootfs/*" -print -quit 2>/dev/null)" ] || return 0
    else
        [ -d "$rootfs" ] || return 0
    fi
    echo "Removing old Desktop for Batocera ($dir)..."
    close_x11_desktop_mode

    # Stop the service first, so it cannot link anything again and can undo
    # its own links while its files are still there
    stop_service "$svc"

    # Remove links still pointing into its rootfs or icon packs (the service
    # skips some, and a half-removed install leaves dangling ones) and put
    # Batocera's originals back
    while IFS= read -r -d '' link; do
        rm -f "$link"
        if [ -e "${link}.bak" ] || [ -L "${link}.bak" ]; then
            mv -f "${link}.bak" "$link"
        fi
    done < <(find /usr /etc /lib -xdev \( -lname "$rootfs/*" -o -lname "$dir/icons/*" \) -print0 2>/dev/null)
    # Originals it backed up whose link is already gone
    local log="/userdata/system/logs/$svc.log"
    if [ -f "$log" ]; then
        sed -n 's/.*Backing up: \(.*\) -> \1\.bak$/\1/p' "$log" | sort -u | while IFS= read -r target; do
            if [ -e "${target}.bak" ] && [ ! -e "$target" ]; then
                mv -f "${target}.bak" "$target"
            fi
        done
    fi
    restore_filemanagerlauncher

    # Openbox: it replaced Batocera's rc.xml (and kept Batocera's as rc.xml.es)
    if [ -f /etc/openbox/rc.xml.es ]; then
        local src
        src=$(base_copy /etc/openbox/rc.xml) && cp -f "$src" /etc/openbox/rc.xml
        rm -f /etc/openbox/rc.xml.es
        pgrep -x openbox >/dev/null && openbox --reconfigure >/dev/null 2>&1
    fi

    # Only the files it shipped. The Docker "Desktop" add-on shares
    # add-ons/desktop (Desktop.AppImage): the folder itself is only removed
    # when nothing else is left in it.
    if [ -d "$dir" ]; then
        for item in rootfs icons config rc.xml.desktop rc.xml.es; do
            rm -rf --one-file-system "${dir:?}/$item"
        done
        rmdir "$dir" 2>/dev/null
    fi
    rm -f "$log"
    echo "Old Desktop for Batocera removed."
}

# Settings and shortcuts the squashfs and DRL desktops shipped (anything the
# user added to /userdata/system/Desktop is kept)
cleanup_x11_desktop_settings() {
    rm -rf /userdata/system/.config/tint2 /userdata/system/.config/jgmenu \
           /userdata/system/.config/sublime-text /userdata/system/.config/pcmanfm \
           /userdata/system/.config/libfm
    for f in Choose_Browser CoreKeyboard ES FileManagerES Install_WPS_Office \
             Pack_Theme "Shortcut Creator" screenrec; do
        rm -f "/userdata/system/Desktop/$f.desktop"
    done
    rmdir /userdata/system/Desktop 2>/dev/null
    # Its link to Steam's games folder (only the link; a real folder is kept)
    [ -L "/userdata/Steam Games Folder" ] && rm -f "/userdata/Steam Games Folder"
    rm -f /userdata/system/logs/tint2.log /userdata/system/logs/picom.log
    rm -rf /userdata/tmp/Desktop_for_Batocera /userdata/tmp/native-desktop
}

# --- 3. Original DRL desktop (saved overlay) ----------------------------------
antimicrox_in_use() {
    for addon in f1 android-bua winconfig freej2me; do
        [ -d "/userdata/system/add-ons/$addon" ] && return 0
    done
    return 1
}

cleanup_drl() {
    local remover=/userdata/system/configs/bat-drl/Remover_Desktop.sh
    [ -f "$remover" ] || [ -d /userdata/system/add-ons/desktop_drl ] || \
        [ -f /userdata/system/services/desktop_drl ] || [ -d /userdata/system/configs/bat-drl/Desktop ] || return 0
    echo "Removing old DRL desktop..."
    close_x11_desktop_mode

    # DRL's own remover first (yad stubbed: its prompts would block)
    if [ -f "$remover" ]; then
        function yad() { return 0; }; export -f yad
        bash "$remover" </dev/null >/dev/null 2>&1
        unset -f yad
        rm -f "$remover"
    fi
    stop_service desktop_drl
    rm -rf /userdata/system/add-ons/desktop_drl

    # What the remover leaves in /userdata
    rm -rf /userdata/system/configs/bat-drl/Desktop /userdata/system/configs/bat-drl/tint2 \
           /userdata/system/configs/bat-drl/FP_Atalho /userdata/userdata
    if ! antimicrox_in_use; then
        rm -rf /userdata/system/configs/bat-drl/AntiMicroX
        rm -f /userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp
    fi
    rmdir /userdata/system/configs/bat-drl 2>/dev/null

    # What it leaves in the overlay. Exact names, removed from the overlay's
    # upper layer only: going through /usr (or using wildcards) would hide
    # Batocera's own copies (zenity is part of Batocera 44, libgtk-3 and
    # libnettle exist with other versions) and other libs (Nvidia) live there.
    if [ -d "$OVL" ]; then
        local L="$OVL/usr/lib"
        antimicrox_in_use || rm -f "$OVL/usr/bin/antimicrox"
        rm -f "$OVL/usr/bin/zenity" "$OVL/usr/bin/filemanagerlauncher"
        rm -f \
            "$L/libXtst.so"        "$L/libXtst.so.6"              "$L/libXtst.so.6.1.0" \
            "$L/libXv.so"          "$L/libXv.so.1"                "$L/libXv.so.1.0.0" \
            "$L/libaio.so"         "$L/libaio.so.1.0.1" \
            "$L/libadwaita-1.so.0" \
            "$L/libatk-bridge-2.0.so.0" \
            "$L/libatspi.so.0" \
            "$L/libbrotlicommon.so.1" \
            "$L/libbrotlidec.so.1" \
            "$L/libcanberra.so.0" \
            "$L/libcap.so.2.27" \
            "$L/libcprime-core.so"    "$L/libcprime-core.so.4"    "$L/libcprime-core.so.4.5.0" \
            "$L/libcprime-gui.so"     "$L/libcprime-gui.so.4"     "$L/libcprime-gui.so.4.5.0" \
            "$L/libcprime-widgets.so" "$L/libcprime-widgets.so.4" "$L/libcprime-widgets.so.4.5.0" \
            "$L/libcroco-0.6.so"   "$L/libcroco-0.6.so.3"        "$L/libcroco-0.6.so.3.0.1" \
            "$L/libcrypt.so.1"     "$L/libcrypt.so.2" \
            "$L/libcups.so.2" \
            "$L/libcurl-gnutls.so.4" \
            "$L/libdbus-glib-1.so.2" \
            "$L/libexslt.so"       "$L/libexslt.so.0.8.20" \
            "$L/libfdisk.so.1.1.0" \
            "$L/libfm-gtk.so"      "$L/libfm-gtk.so.4"           "$L/libfm-gtk.so.4.1.2" \
            "$L/libgailutil-3.so"  "$L/libgailutil-3.so.0"       "$L/libgailutil-3.so.0.0.0" \
            "$L/libgdk-3.so"       "$L/libgdk-3.so.0.2404.8" \
            "$L/libgdk-x11-2.0.so" "$L/libgdk-x11-2.0.so.0"     "$L/libgdk-x11-2.0.so.0.2400.32" \
            "$L/libgtk-3.so"       "$L/libgtk-3.so.0.2404.8" \
            "$L/libgtk-4.so.1" \
            "$L/libgtk-x11-2.0.so" "$L/libgtk-x11-2.0.so.0"     "$L/libgtk-x11-2.0.so.0.2400.32" \
            "$L/libImlib2.so"      "$L/libImlib2.so.1"           "$L/libImlib2.so.1.5.1" \
            "$L/libidn2.so.0" \
            "$L/libjack.so.0" \
            "$L/libkeyutils.so.1" \
            "$L/liblightspark.so.0.8.5" "$L/liblightsparkplugin.so" \
            "$L/libnettle.so.7" \
            "$L/libnsl.so.1" \
            "$L/libpepflashplayer.so" \
            "$L/libQt5DBus.so"     "$L/libQt5DBus.so.5"     "$L/libQt5DBus.so.5.15"    "$L/libQt5DBus.so.5.15.8" \
            "$L/libQt5X11Extras.so" "$L/libQt5X11Extras.so.5" "$L/libQt5X11Extras.so.5.15" "$L/libQt5X11Extras.so.5.15.8" \
            "$L/librsvg-2.so"      "$L/librsvg-2.so.2.40.20" \
            "$L/libsecret-1.so.0" \
            "$L/libselinux.so.1" \
            "$L/libSoundTouch.so"  "$L/libSoundTouch.so.1"       "$L/libSoundTouch.so.1.0.0" \
            "$L/libtdb.so.1" \
            "$L/libthai.so.0"      "$L/libthai.so.0.3"           "$L/libthai.so.0.3.1" \
            "$L/libunistring.so.2" \
            "$L/libwayland-client.so.0" \
            "$L/libwayland-cursor.so.0" \
            "$L/libwayland-egl.so.1" \
            "$L/libwayland-server.so.0" \
            "$L/libxslt.so"        "$L/libxslt.so.1.1.34" \
            "$L/libyaml-cpp.so"    "$L/libyaml-cpp.so.0.6"      "$L/libyaml-cpp.so.0.6.3" \
            "$OVL/lib/libfdisk.so.1.1.0" "$OVL/lib/libthai.so.0.3.1" \
            "$OVL/etc/openbox/rc.xml" "$OVL/etc/xdg/openbox/autostart.bak" \
            2>/dev/null
        rm -rf "$OVL/usr/share/icons/batocera" 2>/dev/null
        rmdir /etc/xdg/libfm /etc/xdg/menus /etc/xdg/pcmanfm/default /etc/openbox \
              /etc/X11 /usr/share/icons/batocera 2>/dev/null
        # The original DRL desktop lived in the saved overlay: without saving
        # it again, everything removed above comes back at the next boot
        if [ -f /boot/boot/overlay ] && command -v batocera-save-overlay >/dev/null 2>&1; then
            echo "Saving Batocera's overlay without the DRL desktop..."
            batocera-save-overlay >/dev/null 2>&1
        fi
    fi
    restore_filemanagerlauncher
    echo "Old DRL desktop removed."
}

# DRL first: the squashfs desktop installed over it on some systems
had_x11_desktop=0
if [ -f /userdata/system/configs/bat-drl/Remover_Desktop.sh ] || [ -d /userdata/system/add-ons/desktop_drl ] || \
   [ -d /userdata/system/add-ons/desktop/rootfs ] || [ -d /userdata/system/add-ons/native-x11-desktop/rootfs ] || \
   [ -f /userdata/system/services/desktop ] || [ -d /userdata/system/configs/bat-drl/Desktop ]; then
    had_x11_desktop=1
fi
cleanup_drl
cleanup_squashfs_desktop /userdata/system/add-ons/desktop desktop
cleanup_squashfs_desktop /userdata/system/add-ons/native-x11-desktop native-x11-desktop
[ "$had_x11_desktop" = 1 ] && cleanup_x11_desktop_settings
cleanup_lightdesktop
exit 0
