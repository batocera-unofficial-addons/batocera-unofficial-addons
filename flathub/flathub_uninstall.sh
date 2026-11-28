#!/bin/bash
# Uninstaller for the Flathub port, installed by flathub.sh.
# Removes the Ports launcher, its key mapping, logo and gamelist entry.
# Google Chrome is kept: other ports (Netflix, Disney+, ...) use it too;
# remove it with its own uninstaller.

PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/flathub.sh"

remove_file() {
    if [ -f "$1" ]; then
        echo "Removing: $1"
        rm -f "$1"
    fi
}

main() {
    echo "========================================="
    echo "Uninstalling: Flathub"
    echo "========================================="
    echo ""

    # Drop the game from ES's memory first, so a reload does not write its
    # entry back into gamelist.xml
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    remove_file "$PORT_SCRIPT"
    remove_file "${PORTS_DIR}/flathub.sh.keys"
    remove_file "${PORTS_DIR}/images/flathub-logo.jpg"

    if [ -f "$GAME_LIST" ]; then
        echo "Removing Flathub from ${GAME_LIST}"
        xmlstarlet ed -d "/gameList/game[path='./flathub.sh']" "$GAME_LIST" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "$GAME_LIST"
        rm -f "${GAME_LIST}.tmp"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo ""
    echo "Google Chrome was kept (other ports use it)."
    echo ""
    echo "========================================="
    echo "Uninstallation complete: Flathub"
    echo "========================================="
}

main "$@"
