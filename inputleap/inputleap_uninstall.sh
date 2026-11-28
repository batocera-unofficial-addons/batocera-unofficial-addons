#!/bin/bash
# Uninstaller for Input Leap, installed by inputleap.sh.
# Removes the Input Leap Flatpak, the F1 Applications entry and its saved
# copy, the boot restore script and its custom.sh line, the icon, and the
# hidden entry in the Flatpak system list. Input Leap's own settings
# (server/client setup, screens, certificates) are kept.

APPNAME="inputleap"
APP_ID="io.github.input_leap.input-leap"

CONFIG_DIR="/userdata/system/configs/${APPNAME}"
ADDON_DIR="/userdata/system/add-ons/${APPNAME}"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
RESTORE_SCRIPT="${CONFIG_DIR}/restore_desktop_entry.sh"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
FLATPAK_ENTRY="Input Leap.flatpak"
USER_DATA_DIR="/userdata/system/.var/app/${APP_ID}"

remove_file() {
    if [ -f "$1" ]; then
        echo "Removing: $1"
        rm -f "$1"
    fi
}

main() {
    echo "========================================="
    echo "Uninstalling: Input Leap"
    echo "========================================="
    echo ""

    pkill -f "$APP_ID" >/dev/null 2>&1

    # The installer uses a system install; check the user one too.
    for scope in --system --user; do
        if flatpak info "$scope" "$APP_ID" >/dev/null 2>&1; then
            echo "Uninstalling Flatpak (${scope#--}): ${APP_ID}"
            flatpak uninstall "$scope" -y --noninteractive "$APP_ID" || echo "Warning: could not uninstall ${APP_ID}"
        fi
    done
    batocera-flatpak-update >/dev/null 2>&1

    if [ -f "$CUSTOM_SCRIPT" ] && grep -qF "$RESTORE_SCRIPT" "$CUSTOM_SCRIPT"; then
        echo "Removing the restore line from ${CUSTOM_SCRIPT}"
        sed -i "\|${RESTORE_SCRIPT}|d" "$CUSTOM_SCRIPT"
    fi

    remove_file "$DESKTOP_FILE"
    remove_file "${CONFIG_DIR}/${APPNAME}.desktop"
    remove_file "$RESTORE_SCRIPT"
    rmdir "$CONFIG_DIR" 2>/dev/null

    # A copy the user put on the desktop, only if it starts this Flatpak
    for f in /userdata/system/Desktop/inputleap.desktop /userdata/system/Desktop/input-leap.desktop; do
        if [ -f "$f" ] && grep -qF "$APP_ID" "$f"; then
            remove_file "$f"
        fi
    done

    if [ -d "$ADDON_DIR" ]; then
        echo "Removing: ${ADDON_DIR}"
        rm -rf "${ADDON_DIR:?}"
    fi
    # Empty folder the installer creates
    rmdir /userdata/system/bua/inputleap 2>/dev/null
    rmdir /userdata/system/bua 2>/dev/null

    remove_file "/userdata/roms/flatpak/${FLATPAK_ENTRY}"
    if [ -f "$FLATPAK_GAMELIST" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${FLATPAK_ENTRY}']" "$FLATPAK_GAMELIST" > "${FLATPAK_GAMELIST}.tmp" \
            && mv "${FLATPAK_GAMELIST}.tmp" "$FLATPAK_GAMELIST"
        rm -f "${FLATPAK_GAMELIST}.tmp"
        curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1
    fi

    echo ""
    if [ -d "$USER_DATA_DIR" ]; then
        echo "Input Leap settings were kept in ${USER_DATA_DIR}."
    fi
    echo ""
    echo "========================================="
    echo "Uninstallation complete: Input Leap"
    echo "========================================="
}

main "$@"
