#!/bin/bash
# Uninstaller for Sandtrix, installed by sandtrix.sh.
# Removes the game folder, the Ports launcher, logo and gamelist entry.
# The game keeps its saves, settings, high scores and error log in a save/
# folder inside the game folder (its working directory), so they are removed
# with it.

APPNAME="Sandtrix"
APPDIR="/userdata/system/add-ons/sandtrix"
PORT_SCRIPT="/userdata/roms/ports/Sandtrix.sh"
ICON_PATH="/userdata/roms/ports/images/sandtrix-logo.png"
GAMELIST="/userdata/roms/ports/gamelist.xml"

main() {
    echo "Removing ${APPNAME}..."

    # Stop the game if it is running.
    pkill -f "${APPDIR}/" >/dev/null 2>&1

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    rm -rf "${APPDIR:?}"
    rm -f "${PORT_SCRIPT}" "${ICON_PATH}"

    if [ -f "${GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./Sandtrix.sh']" "${GAMELIST}" > "${GAMELIST}.tmp" \
            && mv "${GAMELIST}.tmp" "${GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APPNAME} has been removed."
}

main "$@"
