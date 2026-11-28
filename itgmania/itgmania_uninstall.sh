#!/bin/bash
# Uninstaller for ITGMania, installed by itgmania.sh.
# Removes the game files that came with the release, the Ports launcher,
# logo and gamelist entry.
# Keeps your data in /userdata/system/add-ons/itgmania: settings, profiles
# and scores in .itgmania/, and songs, courses, themes and noteskins you
# added to the folder. A reinstall picks them up again.

INSTALL_DIR="/userdata/system/add-ons/itgmania"
MANIFEST="${INSTALL_DIR}/.bua-files"
PORTS_DIR="/userdata/roms/ports"
GAMELIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/ITGMania.sh"

# Program folders of the release that hold no user data. Used for installs
# made before the installer listed its files in .bua-files.
PROGRAM_PARTS="itgmania itgmania.desktop Data Docs Scripts BGAnimations BackgroundEffects BackgroundTransitions"

main() {
    echo "Uninstalling ITGMania..."

    pkill -f "${INSTALL_DIR}/itgmania" 2>/dev/null

    # ES keeps a played game's stats in memory and writes them back to
    # gamelist.xml on the next reload, which brings back the entry removed
    # below. Removing the game through ES first drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    if [ -d "${INSTALL_DIR}" ]; then
        local rel part
        if [ -f "${MANIFEST}" ]; then
            echo "Removing ITGMania's game files..."
            while IFS= read -r rel; do
                [ -n "${rel}" ] && rm -f "${INSTALL_DIR}/${rel}"
            done < "${MANIFEST}"
            rm -f "${MANIFEST}"
        else
            echo "Removing ITGMania's program files (songs, themes and noteskins are kept)..."
            for part in ${PROGRAM_PARTS}; do
                rm -rf "${INSTALL_DIR:?}/${part}"
            done
        fi
        rm -f "${INSTALL_DIR}/itgmania.tar.gz"
        find "${INSTALL_DIR}" -mindepth 1 -depth -type d -empty ! -path "${INSTALL_DIR}/.itgmania*" -delete 2>/dev/null
        rmdir "${INSTALL_DIR}" 2>/dev/null
    fi

    rm -f "${PORT_SCRIPT}" "${PORT_SCRIPT}.keys" "${PORTS_DIR}/images/itgmania-logo.png"

    if [ -f "${GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./ITGMania.sh']" "${GAMELIST}" > "${GAMELIST}.tmp" \
            && mv "${GAMELIST}.tmp" "${GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "ITGMania uninstalled."
    if [ -d "${INSTALL_DIR}" ]; then
        echo "Your ITGMania data (settings, profiles, scores, added songs) was kept in:"
        echo "  ${INSTALL_DIR}"
        echo "Delete that folder to free the space, or reinstall to use it again."
    fi
}

main "$@"
