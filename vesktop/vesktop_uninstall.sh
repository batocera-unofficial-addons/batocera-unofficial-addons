#!/bin/bash
# Uninstaller for Vesktop, installed by vesktop.sh.
# Removes the AppImage and icon, the Ports launcher, keys, logo and gamelist
# entry, the desktop entry and its persistent copy, the restore script and
# its custom.sh line, and the log and settings the launcher creates.

INSTALL_DIR="/userdata/system/add-ons/vesktop"
DESKTOP_FILE="/usr/share/applications/Vesktop.desktop"
custom_startup="/userdata/system/custom.sh"
log_file="/userdata/system/logs/vesktop.log"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/Vesktop.sh"

main() {
    echo "Removing Vesktop..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    if [ -f "${custom_startup}" ]; then
        sed -i "\|/userdata/system/configs/vesktop/restore_desktop_entry.sh|d" "${custom_startup}"
    fi

    rm -f "${DESKTOP_FILE}"
    rm -rf "${INSTALL_DIR:?}" "/userdata/system/configs/vesktop"
    rm -f "${PORT_SCRIPT}" "${PORT_SCRIPT}.keys" "${PORTS_DIR}/images/vesktoplogo.png"
    rm -f "${log_file}"

    # Vesktop keeps its settings and Discord login in ${HOME}/.config/vesktop.
    # The launcher exports PID 1's environment first, where HOME is /, so
    # that is usually /.config/vesktop.
    rm -rf "/.config/vesktop" "/userdata/system/.config/vesktop"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./Vesktop.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Vesktop has been removed."
}

main "$@"
