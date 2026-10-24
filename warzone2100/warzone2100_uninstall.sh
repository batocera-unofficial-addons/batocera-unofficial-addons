#!/bin/bash
# Uninstaller for Warzone 2100, installed by warzone2100.sh.
# Removes the AppImage, the Ports launcher, logo and gamelist entry, and the
# log, settings and Discord handler the launcher and game create.

APP_NAME="Warzone 2100"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
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
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"

    # The game keeps its settings and saves in .local/share/warzone2100, and
    # writes that folder both under / (the HOME the launcher gets from PID 1)
    # and under /userdata/system.
    rm -rf /.local/share/warzone2100* /userdata/system/.local/share/warzone2100*

    # The game registers a Discord Rich Presence handler for its own Discord
    # app ID, pointing into the AppImage's temporary mount.
    rm -f "/.local/share/applications/discord-505520727521361941.desktop" \
        "/userdata/system/.local/share/applications/discord-505520727521361941.desktop"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
