#!/bin/bash
# VLC uninstaller for Batocera. Removes the AppImage, the Ports launcher and
# its gamelist entry, the desktop entry and the custom.sh line that restores it.
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/vlc/vlc_uninstall.sh | bash

# Same names and values as vlc.sh
APP_NAME="VLC"
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.jpg"
DESKTOP_FILE="/usr/share/applications/${APP_NAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APP_NAME,,}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

main() {
    echo "========================================="
    echo "Uninstalling: ${APP_NAME}"
    echo "========================================="
    echo ""

    echo "Stopping ${APP_NAME}..."
    # The launcher starts it as ./vlc.AppImage; the app itself runs from the AppImage mount
    pkill -f "${APP_NAME,,}\.AppImage" 2>/dev/null
    pkill -f "/tmp/\.mount_${APP_NAME,,}" 2>/dev/null

    # Remove the startup line before the script it points at
    if [ -f "${CUSTOM_STARTUP}" ]; then
        echo "Removing ${APP_NAME} entry from custom.sh"
        sed -i "\|${RESTORE_SCRIPT}|d" "${CUSTOM_STARTUP}"
    fi

    echo "Removing desktop entry"
    rm -f "${DESKTOP_FILE}"
    rm -rf "/userdata/system/configs/${APP_NAME,,}"

    echo "Removing ${ADDONS_DIR}/${APP_NAME,,}"
    rm -rf "${ADDONS_DIR:?}/${APP_NAME,,}"

    # The launcher runs VLC with HOME=/, so its settings are written here
    echo "Removing ${APP_NAME} settings"
    rm -rf "/.config/${APP_NAME,,}" "/.local/share/${APP_NAME,,}"

    echo "Removing Ports launcher and logo"
    rm -f "${PORT_SCRIPT}" "${LOGO_PATH}"
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"

    if [ -f "${GAME_LIST}" ]; then
        echo "Removing ${APP_NAME} entry from gamelist.xml"
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
        rm -f "${GAME_LIST}.tmp"
    fi

    echo "Refreshing Ports menu..."
    curl -s http://127.0.0.1:1234/reloadgames

    echo ""
    echo "========================================="
    echo "Uninstallation complete: ${APP_NAME}"
    echo "========================================="
}

main "$@"
