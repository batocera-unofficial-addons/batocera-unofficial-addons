#!/bin/bash
# Uninstaller for Everest, installed by everest.sh.
# Removes the Olympus Flatpak and its filesystem override, the Ports launcher,
# its artwork and gamelist entry, the desktop entries, and the hidden entry in
# the Flatpak system list. Olympus settings and Celeste mods are kept.

APP_NAME="Everest"
APP_ID="io.github.everestapi.Olympus"

PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
FLATPAK_ENTRY="Everest Team.flatpak"
USER_DATA_DIR="/userdata/system/.var/app/${APP_ID}"

remove_file() {
    if [ -f "$1" ]; then
        echo "Removing: $1"
        rm -f "$1"
    fi
}

main() {
    echo "========================================="
    echo "Uninstalling: ${APP_NAME}"
    echo "========================================="
    echo ""

    # ES keeps a played game's stats in memory and writes them back to
    # gamelist.xml on the next reload, which brings back the entry removed
    # below. Removing the game through ES first, while its launcher still
    # exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    # The installer uses a user install; check the system one too.
    for scope in --user --system; do
        if flatpak info "$scope" "$APP_ID" >/dev/null 2>&1; then
            echo "Uninstalling Flatpak (${scope#--}): ${APP_ID}"
            flatpak uninstall "$scope" -y --noninteractive "$APP_ID" || echo "Warning: could not uninstall ${APP_ID}"
        fi
    done
    flatpak override --reset "$APP_ID" >/dev/null 2>&1
    batocera-flatpak-update >/dev/null 2>&1

    remove_file "$PORT_SCRIPT"
    remove_file "${PORTS_DIR}/images/${APP_NAME}-marquee.png"
    remove_file "${PORTS_DIR}/images/${APP_NAME}-thumb.png"
    remove_file "/userdata/system/.local/share/applications/${APP_NAME}.desktop"
    remove_file "/userdata/system/Desktop/${APP_NAME}.desktop"
    remove_file "/userdata/roms/flatpak/${FLATPAK_ENTRY}"

    if [ -f "$GAME_LIST" ]; then
        echo "Removing ${APP_NAME} from ${GAME_LIST}"
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "$GAME_LIST" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "$GAME_LIST"
        rm -f "${GAME_LIST}.tmp"
    fi
    if [ -f "$FLATPAK_GAMELIST" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${FLATPAK_ENTRY}']" "$FLATPAK_GAMELIST" > "${FLATPAK_GAMELIST}.tmp" \
            && mv "${FLATPAK_GAMELIST}.tmp" "$FLATPAK_GAMELIST"
        rm -f "${FLATPAK_GAMELIST}.tmp"
    fi

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo ""
    if [ -d "$USER_DATA_DIR" ]; then
        echo "Olympus settings were kept in ${USER_DATA_DIR}."
    fi
    echo "Celeste and its mods were not touched."
    echo ""
    echo "========================================="
    echo "Uninstallation complete: ${APP_NAME}"
    echo "========================================="
}

main "$@"
