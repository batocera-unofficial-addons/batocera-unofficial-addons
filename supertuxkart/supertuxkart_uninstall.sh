#!/bin/bash
# Uninstaller for SuperTuxKart, installed by supertuxkart.sh.
# Removes the game files, the Ports launcher, logo and gamelist entry, and
# the log, settings, add-ons and cache the launcher and game create, and the
# links BUA's symlink service makes to the game's bin and lib files.

APP_NAME="SuperTuxKart"

ADDONS_DIR="/userdata/system/add-ons"
TUX_DIR="${ADDONS_DIR}/supertuxkart"
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

    rm -rf "${TUX_DIR:?}"
    # BUA's symlink service links the files in the game's bin and lib
    # folders into /usr/bin and /usr/lib. Remove the links that pointed into
    # the game folder, now left dangling. This comes after removing the
    # folder so the service can't make them again.
    find /usr/bin /usr/lib -maxdepth 1 -type l -lname "${TUX_DIR}/*" -delete 2>/dev/null
    rm -f "${PORT_SCRIPT}" "${LOGO_PATH}"
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"

    # The game keeps its settings in ${HOME}/.config/supertuxkart, add-ons,
    # replays and screenshots in ${HOME}/.local/share/supertuxkart, and
    # cached textures in ${HOME}/.cache/supertuxkart. The launcher exports
    # PID 1's environment first, where HOME is /, so those are usually
    # under /.
    local home
    for home in "" "/userdata/system"; do
        rm -rf "${home}/.config/${APP_NAME,,}" \
            "${home}/.local/share/${APP_NAME,,}" \
            "${home}/.cache/${APP_NAME,,}"
    done

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
