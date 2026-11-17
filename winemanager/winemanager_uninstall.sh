#!/bin/bash
# Uninstaller for Wine Manager, installed by winemanager.sh.
# winemanager.sh unzips winemanager.zip and copies its roms/ and system/
# folders over /userdata/. This removes what the zip puts there: the app in
# /userdata/system/wine_manager and its Ports scripts (Wine manager, Enable
# and Disable redist install, with the pad mapping), with their gamelist
# entries. Files of the same name that were on the device before the install
# were overwritten by it and can't be restored.
#
# Also removes what the app's own updater (Gr3gorywolf's install.sh) adds
# when it was run: the Ports logo and the desktop entry.
#
# Keeps /userdata/system/wine (Wine/Proton versions the app downloaded, and
# the redistributables of the Wine Dependencies add-ons): Batocera's Windows
# games run on them. If the redist install was disabled through the app or
# its Ports script, asks whether to enable it again.
#
# Usage: winemanager_uninstall.sh [--ignore-warning]
#   --ignore-warning  answer Yes to every question without asking
#                     (LB+RB on the BUA app's Updater screen). From a terminal:
#                     curl -L <url> | bash -s -- --ignore-warning

APP_NAME="Wine Manager"

TEMP_DIR="/userdata/tmp/winemanager"
DEST_DIR="/userdata/"

WINE_MANAGER_FOLDER="${DEST_DIR}system/wine_manager"
ROMS_PORTS_FOLDER="${DEST_DIR}roms/ports"
IMAGE_FOLDER="${ROMS_PORTS_FOLDER}/images"
DESKTOP_FOLDER="/usr/share/applications"
xml_file="${ROMS_PORTS_FOLDER}/gamelist.xml"
WINE_EXE_DIR="/userdata/system/wine/exe"

# The Ports scripts the zip contains
PORT_SCRIPTS=(wine_manager.sh enable_redist_install.sh disable_redist_install.sh)

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

main() {
    local arg script home
    for arg in "$@"; do
        case "${arg}" in
            --ignore-warning) ignore_warning=true ;;
            *) echo "Usage: winemanager_uninstall.sh [--ignore-warning]"; exit 1 ;;
        esac
    done

    echo "Removing ${APP_NAME}..."

    pkill -f "${WINE_MANAGER_FOLDER}/batocera_wine_manager" 2>/dev/null

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    for script in "${PORT_SCRIPTS[@]}"; do
        curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
            -d "<gameList><game><path>${ROMS_PORTS_FOLDER}/${script}</path></game></gameList>" >/dev/null 2>&1
    done

    rm -rf "${WINE_MANAGER_FOLDER:?}"
    for script in "${PORT_SCRIPTS[@]}"; do
        rm -f "${ROMS_PORTS_FOLDER}/${script}"
    done
    rm -f "${ROMS_PORTS_FOLDER}/wine_manager.sh.keys"

    # Added only by the app's updater (Gr3gorywolf's install.sh)
    rm -f "${IMAGE_FOLDER}/batocera_wine_manager.png"
    rm -f "${DESKTOP_FOLDER}/batocera_wine_manager.desktop"

    # The app's settings (Flutter keeps them under its application id)
    for home in /userdata/system ""; do
        rm -rf "${home}/.local/share/com.example.batocera_wine_manager"
    done

    # Left over from an install that stopped before its cleanup
    rm -rf "${TEMP_DIR:?}"

    if [ -f "${xml_file}" ]; then
        for script in "${PORT_SCRIPTS[@]}"; do
            xmlstarlet ed -d "/gameList/game[path='./${script}']" "${xml_file}" > "${xml_file}.tmp" \
                && mv "${xml_file}.tmp" "${xml_file}"
        done
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    # disable_redist_install.sh renames the redist folder to exe.bak, and the
    # script that renames it back has just been removed.
    if [ -d "${WINE_EXE_DIR}.bak" ] && [ ! -e "${WINE_EXE_DIR}" ]; then
        local text="The Wine redistributable install was disabled with Wine Manager (${WINE_EXE_DIR} renamed to ${WINE_EXE_DIR}.bak).\n\nEnable it again?"
        echo -e "${text}"
        if ask "${APP_NAME}" "${text}"; then
            mv "${WINE_EXE_DIR}.bak" "${WINE_EXE_DIR}" && echo "Enabled again: ${WINE_EXE_DIR}"
        else
            echo "Kept disabled: ${WINE_EXE_DIR}.bak"
        fi
    fi

    echo "Kept /userdata/system/wine (Wine/Proton versions and redistributables used by Windows games)."
    echo "${APP_NAME} has been removed."
    exit 0
}

main "$@"
