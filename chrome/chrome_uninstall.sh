#!/bin/bash
# Uninstaller for Google Chrome, installed by chrome.sh.
# Removes the AppImage, the Ports launcher, logo and gamelist entry, the log
# the launcher creates, the desktop entry and the custom.sh line that
# restores it at boot. Chrome's own launcher sets HOME to the add-on folder,
# so its profile goes with it; the web apps that run on Chrome (Netflix,
# Spotify, ...) start it with the HOME of ES, so their shared profile in
# /userdata/system is removed too.
# Asks first when installed web apps still run on Chrome; to remove it
# without asking (in the BUA app: LB+RB on the installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome_uninstall.sh | bash -s -- --ignore-warning

APPNAME="Chrome"
APPDIR="/userdata/system/add-ons/google-chrome"
APPPATH="${APPDIR}/GoogleChrome.AppImage"
PORTS_DIR="/userdata/roms/ports"
PORT_SCRIPT="${PORTS_DIR}/GoogleChrome.sh"
GAMELIST="${PORTS_DIR}/gamelist.xml"
LOG_FILE="/userdata/system/logs/google-chrome.log"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

# Every Ports launcher except Chrome's own that starts Chrome's AppImage, by
# its gamelist name (or file name when it has none). Read from the device, so
# web apps added to the repo later, or made by the user, are found too.
dependents() {
    local launcher file name
    for launcher in "${PORTS_DIR}"/*.sh; do
        [ -f "${launcher}" ] && [ "${launcher}" != "${PORT_SCRIPT}" ] || continue
        grep -qF "${APPPATH}" "${launcher}" || continue
        file="${launcher##*/}"
        name=""
        [ -f "${GAMELIST}" ] && name="$(xmlstarlet sel -t -v "/gameList/game[path='./${file}']/name" "${GAMELIST}" 2>/dev/null | head -n 1)"
        echo "${name:-${file}}"
    done | sort -u
}

ignore_warning=false   # set to true by --ignore-warning

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

confirm_removal() {
    local apps line list=""
    apps="$(dependents)"
    [ -z "${apps}" ] && return 0

    while IFS= read -r line; do
        list+="  - ${line}\n"
    done <<< "${apps}"
    echo "WARNING: these apps run on Google Chrome. They stay installed, but"
    echo "won't start until Chrome is installed again:"
    printf '%b\n' "${list}"
    if [ "${ignore_warning}" = "true" ]; then
        echo "Ignoring warnings: removing Google Chrome anyway."
        return 0
    fi
    if ask "Uninstall Google Chrome" "These apps run on Google Chrome. They stay installed, but won't start until Chrome is installed again:\n\n${list}\nUninstall Google Chrome?"; then
        return 0
    fi
    echo "Google Chrome was not uninstalled."
    return 1
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: chrome_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    confirm_removal || exit 1

    echo "Removing Google Chrome..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    rm -rf "${APPDIR:?}"
    rm -f "${PORT_SCRIPT}" "${PORTS_DIR}/images/chrome-logo.png"
    rm -f "${LOG_FILE}"

    # Profile and cache of the web apps, which start Chrome with HOME
    # /userdata/system.
    rm -rf /userdata/system/.config/google-chrome /userdata/system/.cache/google-chrome

    rm -f "${DESKTOP_FILE}"
    rm -rf "/userdata/system/configs/${APPNAME,,}"
    if [ -f "${CUSTOM_STARTUP}" ]; then
        grep -vxF "bash \"${RESTORE_SCRIPT}\" &" "${CUSTOM_STARTUP}" > "${CUSTOM_STARTUP}.tmp"
        cat "${CUSTOM_STARTUP}.tmp" > "${CUSTOM_STARTUP}"
        rm -f "${CUSTOM_STARTUP}.tmp"
    fi

    if [ -f "${GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./GoogleChrome.sh']" "${GAMELIST}" > "${GAMELIST}.tmp" \
            && mv "${GAMELIST}.tmp" "${GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Google Chrome has been removed."
}

main "$@"
