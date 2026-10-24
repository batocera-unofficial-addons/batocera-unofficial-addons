#!/bin/bash
# Uninstaller for IPTVNator, installed by iptvnator.sh.
# Removes the AppImage, the Ports launcher, its keys file, logo and gamelist
# entry, and the log the launcher creates. The launcher sets HOME to the
# add-on folder, so IPTVNator's settings and cache are removed with it.

APP_NAME="IPTVNator"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
KEYS_FILE="${PORT_SCRIPT}.keys"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"

main() {
    echo "Removing ${APP_NAME}..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    rm -rf "${ADDONS_DIR:?}/${APP_NAME,,}"
    rm -f "${PORT_SCRIPT}" "${KEYS_FILE}" "${LOGO_PATH}"
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
