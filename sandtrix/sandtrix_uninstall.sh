#!/bin/bash
# Uninstaller for Sandtrix, installed by sandtrix.sh.
# Removes the game files (launcher, jar, bundled JRE), the Ports launcher,
# logo and gamelist entry.
# Keeps the game's saves, settings, high scores and error log in
# /userdata/system/add-ons/sandtrix/save, so a reinstall picks them up again.

APPNAME="Sandtrix"
APPDIR="/userdata/system/add-ons/sandtrix"
SAVE_DIR="${APPDIR}/save"
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

    # Program files only; save/ is kept.
    rm -rf "${APPDIR:?}/jre"
    rm -f "${APPDIR}/Sandtrix" "${APPDIR}/Sandtrix.json" \
        "${APPDIR}/sandtrix-1.0-SNAPSHOT-jar-with-dependencies.jar" "${APPDIR}/Sandtrix_3.0_LINUX.tar.gz"
    rmdir "${APPDIR}" 2>/dev/null
    rm -f "${PORT_SCRIPT}" "${PORT_SCRIPT}.keys" "${ICON_PATH}"

    if [ -f "${GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./Sandtrix.sh']" "${GAMELIST}" > "${GAMELIST}.tmp" \
            && mv "${GAMELIST}.tmp" "${GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APPNAME} has been removed."
    if [ -d "${SAVE_DIR}" ]; then
        echo "Your saves and high scores were kept in:"
        echo "  ${SAVE_DIR}"
        echo "Delete that folder to free the space, or reinstall to use it again."
    fi
}

main "$@"
