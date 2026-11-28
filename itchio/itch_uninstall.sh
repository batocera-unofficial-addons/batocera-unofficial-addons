#!/bin/bash
# Uninstaller for itch.io, installed by itch.sh (x86_64, user Flatpak).
# Removes the io.itch.itch Flatpak, the Ports launcher, keys file, images
# and gamelist entry, the desktop entry and Desktop shortcut, and the
# Flatpak system entry (its .flatpak file, icon and gamelist entry) that
# the installer's batocera-flatpak-update run creates.
#
# Keeps itch's data (sign-in, settings and the games it downloaded) in
# /userdata/system/.var/app/io.itch.itch, so a reinstall picks it up again.
# Keeps the flathub remote: other add-ons use it. Runtimes are left to
# Flatpak's own "unused" check.

APP_NAME="itch.io"
APP_ID="io.itch.itch"
APP_EXEC="itchio"

PORTS_DIR="/userdata/roms/ports"
IMAGES_DIR="${PORTS_DIR}/images"
PORTS_GAMELIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT_PATH="${PORTS_DIR}/${APP_EXEC}.sh"
DESKTOP_FILE="/userdata/system/.local/share/applications/${APP_EXEC}.desktop"
DESKTOP_DIR="/userdata/system/Desktop"
PATH_DESKTOP="${DESKTOP_DIR}/${APP_EXEC}.desktop"
FLATPAK_DIR="/userdata/roms/flatpak"
FLATPAK_GAMELIST="${FLATPAK_DIR}/gamelist.xml"
DATA_DIR="/userdata/system/.var/app/${APP_ID}"

# Prints the Flatpak system's .flatpak files for itch. batocera-flatpak-update
# names them after the app's display name and writes the app ID inside.
flatpak_roms() {
    local rom
    for rom in "${FLATPAK_DIR}"/*.flatpak; do
        [ -f "${rom}" ] || continue
        [ "$(head -n 1 "${rom}" 2>/dev/null)" = "${APP_ID}" ] && echo "${rom}"
    done
}

main() {
    echo "Removing ${APP_NAME}..."

    local roms rom name
    roms="$(flatpak_roms)"

    # ES keeps a played game's stats in memory and writes them back to
    # gamelist.xml on the next reload, which brings back the entries removed
    # below. Removing the games through ES first, while their files still
    # exist, drops them from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT_PATH}</path></game></gameList>" >/dev/null 2>&1
    while IFS= read -r rom; do
        [ -n "${rom}" ] || continue
        curl -s -X POST "http://127.0.0.1:1234/removegames/flatpak" \
            -d "<gameList><game><path>${rom}</path></game></gameList>" >/dev/null 2>&1
    done <<< "${roms}"

    if flatpak info --user "${APP_ID}" >/dev/null 2>&1; then
        flatpak kill "${APP_ID}" >/dev/null 2>&1
        echo "Uninstalling the ${APP_ID} Flatpak..."
        flatpak uninstall --user -y --noninteractive "${APP_ID}"
        if flatpak info --user "${APP_ID}" >/dev/null 2>&1; then
            dialog --title "${APP_NAME}" --msgbox "Failed to uninstall the ${APP_ID} Flatpak; ${APP_NAME} was not removed." 8 60
            exit 1
        fi
        # Runtimes itch needed that no other app in the user installation
        # needs any more. Flatpak keeps the ones still in use.
        echo "Removing user Flatpak runtimes no installed app uses..."
        flatpak uninstall --user -y --noninteractive --unused
    fi
    # The override the installer set (--filesystem=host)
    rm -f "/userdata/system/.local/share/flatpak/overrides/${APP_ID}"

    rm -f "${PORT_SCRIPT_PATH}" "${PORT_SCRIPT_PATH}.keys"
    rm -f "${IMAGES_DIR}/${APP_EXEC}-marquee.png" "${IMAGES_DIR}/${APP_EXEC}-thumb.png"
    rm -f "${DESKTOP_FILE}" "${PATH_DESKTOP}"
    rmdir "${DESKTOP_DIR}" 2>/dev/null

    if [ -f "${PORTS_GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_EXEC}.sh']" "${PORTS_GAMELIST}" > "${PORTS_GAMELIST}.tmp" \
            && mv "${PORTS_GAMELIST}.tmp" "${PORTS_GAMELIST}"
    fi

    # Flatpak system: the entry the installer hid (./itch.io.flatpak) and
    # whatever batocera-flatpak-update made for itch.
    if [ -f "${FLATPAK_GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./itch.io.flatpak']" "${FLATPAK_GAMELIST}" > "${FLATPAK_GAMELIST}.tmp" \
            && mv "${FLATPAK_GAMELIST}.tmp" "${FLATPAK_GAMELIST}"
    fi
    while IFS= read -r rom; do
        [ -n "${rom}" ] || continue
        name="$(basename "${rom}" .flatpak)"
        rm -f "${rom}" "${FLATPAK_DIR}/images/${name}.png"
        if [ -f "${FLATPAK_GAMELIST}" ]; then
            xmlstarlet ed -d "/gameList/game[path='./${name}.flatpak']" "${FLATPAK_GAMELIST}" > "${FLATPAK_GAMELIST}.tmp" \
                && mv "${FLATPAK_GAMELIST}.tmp" "${FLATPAK_GAMELIST}"
        fi
    done <<< "${roms}"

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
    if [ -d "${DATA_DIR}" ]; then
        echo "Your itch.io data (sign-in, settings, downloaded games) was kept in:"
        echo "  ${DATA_DIR}"
        echo "Delete that folder to free the space, or reinstall to use it again."
    fi
    exit 0
}

main "$@"
