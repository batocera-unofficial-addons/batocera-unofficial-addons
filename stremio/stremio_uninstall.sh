#!/bin/bash
# Uninstaller for Stremio, installed by stremio.sh (x86_64, Flatpak).
# Removes the com.stremio.Stremio Flatpak and its data, the Ports launcher,
# keys file, logo and gamelist entry, and the Flatpak system entry
# (Stremio.flatpak, its icon and gamelist entry) that the installer's
# batocera-flatpak-update run creates.
#
# Keeps the flathub remote: Batocera's Flatpak system and other add-ons
# use it. Runtimes are left to Flatpak's own "unused" check, which only
# removes runtimes that no installed app needs and that were not
# installed on their own.

APPNAME="Stremio"
FLATPAK_ID="com.stremio.Stremio"

PORTS_DIR="/userdata/roms/ports"
FLATPAK_DIR="/userdata/roms/flatpak"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LAUNCHER="${PORTS_DIR}/${APPNAME,,}.sh"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/${APPNAME,,}.png"
KEYS_PATH="/userdata/roms/ports/stremio.sh.keys"
FLATPAK_ROM="${FLATPAK_DIR}/${APPNAME}.flatpak"
FLATPAK_IMAGE="${FLATPAK_DIR}/images/${APPNAME}.png"

main() {
    echo "Removing ${APPNAME}..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entries removed below. Removing the games through ES first, while
    # their files still exist, drops them from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${LAUNCHER}</path></game></gameList>" >/dev/null 2>&1
    curl -s -X POST "http://127.0.0.1:1234/removegames/flatpak" \
        -d "<gameList><game><path>${FLATPAK_ROM}</path></game></gameList>" >/dev/null 2>&1

    if flatpak info --system "${FLATPAK_ID}" >/dev/null 2>&1; then
        flatpak kill "${FLATPAK_ID}" >/dev/null 2>&1
        echo "Uninstalling the ${FLATPAK_ID} Flatpak..."
        flatpak uninstall --system -y --noninteractive "${FLATPAK_ID}"
        if flatpak info --system "${FLATPAK_ID}" >/dev/null 2>&1; then
            echo "Failed to uninstall the ${FLATPAK_ID} Flatpak; ${APPNAME} was not removed."
            exit 1
        fi

        # Runtimes Stremio needed (GNOME Platform, GL drivers, codecs) and
        # that no other installed app needs any more. Flatpak keeps the ones
        # an installed app uses or that were installed on their own. A
        # system runtime can also serve apps in a user installation, so skip
        # this when there are any.
        if [ -z "$(flatpak list --user --app --columns=application 2>/dev/null)" ]; then
            echo "Removing Flatpak runtimes no installed app uses..."
            flatpak uninstall --system -y --noninteractive --unused
        else
            echo "Apps in a user Flatpak installation found; leaving runtimes in place."
        fi
    fi

    # App data, in the home of whoever ran it: Ports launchers run with
    # HOME=/userdata/system, Batocera's Flatpak system uses its own home.
    rm -rf "/userdata/system/.var/app/${FLATPAK_ID}"
    rm -rf "/userdata/saves/flatpak/data/.var/app/${FLATPAK_ID}"
    # Caches Stremio makes in that home on its first run
    rm -rf "/userdata/saves/flatpak/data/.cache/${APPNAME,,}" \
        "/userdata/saves/flatpak/data/.cache/app/${FLATPAK_ID}" \
        "/userdata/saves/flatpak/data/.cache/.flatpak/${FLATPAK_ID}"

    rm -f "${LAUNCHER}" "${KEYS_PATH}" "${PORTS_IMAGE_PATH}"
    rm -f "${FLATPAK_ROM}" "${FLATPAK_IMAGE}"
    rm -f "/tmp/stremio_install.log"

    if [ -f "${PORTS_GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APPNAME,,}.sh']" "${PORTS_GAMELIST}" > "${PORTS_GAMELIST}.tmp" \
            && mv "${PORTS_GAMELIST}.tmp" "${PORTS_GAMELIST}"
    fi
    if [ -f "${FLATPAK_GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APPNAME}.flatpak']" "${FLATPAK_GAMELIST}" > "${FLATPAK_GAMELIST}.tmp" \
            && mv "${FLATPAK_GAMELIST}.tmp" "${FLATPAK_GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APPNAME} has been removed."
    exit 0
}

main "$@"
