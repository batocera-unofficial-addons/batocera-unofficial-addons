#!/bin/bash
# Uninstaller for EGGNOGG+, installed by eggnoggplus.sh.
# Removes the game folder, the Ports launcher, logo and gamelist entry, and
# the settings the game writes on first run. The launcher copies PID 1's
# environment (HOME=/), so the game keeps its settings in
# /.madgarden/eggnoggplus; /userdata/system/.madgarden/eggnoggplus is checked
# too, for a game started with HOME=/userdata/system.

APP_NAME="EGGNOGG+"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
# The installer takes the extension from LOGO_URL, which ends in .png.
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
    rm -f "${PORT_SCRIPT}" "${LOGO_PATH}"

    # Settings and key config written by the game on first run. .madgarden
    # is the developer's folder, shared by their other games, so it is only
    # removed when nothing else is left in it.
    local home
    for home in "" "/userdata/system"; do
        rm -rf "${home}/.madgarden/eggnoggplus"
        rmdir "${home}/.madgarden" 2>/dev/null
    done

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
