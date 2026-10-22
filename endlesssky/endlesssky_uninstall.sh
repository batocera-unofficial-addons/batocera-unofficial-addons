#!/bin/bash
# Uninstaller for Endless Sky, installed by endlesssky.sh.
# Removes the AppImage and its config folder, the Ports launcher, logo and
# gamelist entry, and the log, config link and data the launcher and the
# game create.

APP_NAME="Endless Sky"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
APP_DIR="${ADDONS_DIR}/endless-sky"
PORT_SCRIPT="${PORTS_DIR}/EndlessSky.sh"
LOGO_PATH="${PORTS_DIR}/images/endlessskylogo.png"
LOG_FILE="${LOGS_DIR}/endless-sky.log"

main() {
    echo "Removing ${APP_NAME}..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    rm -rf "${APP_DIR:?}"
    rm -f "${PORT_SCRIPT}" "${LOGO_PATH}" "${LOG_FILE}"

    # The launcher links ${HOME}/.config/endless-sky to the config folder in
    # the add-on folder. It exports PID 1's environment first, where HOME is
    # /, so that is usually /.config/endless-sky. Only remove a link that
    # points at the add-on's own folder.
    local link
    for link in "/.config/endless-sky" "/userdata/system/.config/endless-sky"; do
        if [ -L "${link}" ] && [ "$(readlink "${link}")" = "${APP_DIR}/endless-sky-config" ]; then
            rm -f "${link}"
        fi
    done

    # The game keeps its settings and saves in ${HOME}/.local/share/endless-sky.
    rm -rf "/.local/share/endless-sky" "/userdata/system/.local/share/endless-sky"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./EndlessSky.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
