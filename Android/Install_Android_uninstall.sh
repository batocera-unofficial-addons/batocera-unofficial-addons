#!/bin/bash
# Uninstaller for Android (DRL Edition), installed by Install_Android.sh.
# Removes the add-on's bin and lib folders and the links BUA's symlink
# service makes to them, the BlissOS ISO, QEMU and the rest of
# bat-drl/Android, the Ports launcher, keys, images and gamelist entry, the
# desktop entries, their restore script and its custom.sh line, and the
# Desktop shortcuts. AntiMicroX in bat-drl came with the package too; when
# another installed add-on still uses it, it asks before removing it. To
# answer yes without asking (in the BUA app: LB+RB on the installed apps
# screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/Android/Install_Android_uninstall.sh | bash -s -- --ignore-warning

TEMP_DIR="/userdata/tmp/Android"
ADDON_DIR="/userdata/system/add-ons/android-bua"
PORTS_DIR="/userdata/roms/ports"
GAMELIST_PATH="${PORTS_DIR}/gamelist.xml"
BACKUP_PATH="${PORTS_DIR}/gamelist.xml.bak"
APP_NAME="Android"
APP_EXEC="Android"
PORT_SCRIPT_PATH="${PORTS_DIR}/${APP_EXEC}.sh"
PORT_SCRIPT_NAME="${APP_EXEC}.sh"
DEST_FILE="/userdata/system/configs/bat-drl/Android/Android.iso"
CUSTOM_SH="/userdata/system/custom.sh"
RESTORE_LINE="bash /userdata/system/configs/android/restore-desktop-entries.sh"

BAT_DRL="/userdata/system/configs/bat-drl"
DRL_APP_DIR="${DEST_FILE%/*}"
ANTIMICROX_DIR="${BAT_DRL}/AntiMicroX"
CONFIG_DIR="/userdata/system/configs/android"
# andrl makes this on its first run, as a folder to share files with Android
SHARE_DIR="/userdata/Android"
DESKTOP_DIR="/usr/share/applications"
USER_DESKTOP_DIR="/userdata/system/Desktop"
# Desktop entries in the package, copied to ${CONFIG_DIR}/applications and
# from there to ${DESKTOP_DIR} at every boot.
DESKTOP_ENTRIES="Android.desktop Android_Config.desktop Remover_Android.desktop"

# Prints what, other than Android itself, still refers to AntiMicroX:
# launchers, services, other bat-drl packages, ES systems, custom.sh, and
# symlinks in other add-ons (e.g. f1/bin/antimicrox). One name per line,
# nothing when unused.
antimicrox_users() {
    local path link
    for path in "${BAT_DRL}"/* "${PORTS_DIR}"/*.sh /userdata/system/services/* \
                /userdata/system/configs/emulationstation/es_systems_*.cfg "${CUSTOM_SH}"; do
        [ -e "${path}" ] || continue
        case "${path}" in
            "${ANTIMICROX_DIR}" | "${DRL_APP_DIR}" | "${PORT_SCRIPT_PATH}") continue ;;
        esac
        grep -rqsiI -e "antimicrox" "${path}" && basename "${path}"
    done
    find /userdata/system/add-ons -mindepth 2 -maxdepth 3 -ilname "*antimicrox*" 2>/dev/null |
        while IFS= read -r link; do
            case "${link}" in
                "${ADDON_DIR}/"*) continue ;;
            esac
            link="${link#/userdata/system/add-ons/}"
            echo "${link%%/*} add-on"
        done
}

# Stops the processes whose program is in the given dir.
stop_from() {
    local dir="$1" exe pid
    for exe in /proc/[0-9]*/exe; do
        case "$(readlink "${exe}" 2>/dev/null)" in
            "${dir}/"*)
                pid="${exe#/proc/}"
                kill "${pid%/exe}" 2>/dev/null
                ;;
        esac
    done
}

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

# Removes AntiMicroX. When another installed app still uses it, asks first:
# Yes removes it, No keeps it.
remove_antimicrox() {
    local users line list=""
    [ -d "${ANTIMICROX_DIR}" ] || return 0
    users="$(antimicrox_users | sort -u)"
    if [ -n "${users}" ]; then
        while IFS= read -r line; do
            list+="  - ${line}\n"
        done <<< "${users}"
        echo "WARNING: ${ANTIMICROX_DIR} is still used by:"
        printf '%b\n' "${list}"
        if ! ask "Uninstall Android" "${ANTIMICROX_DIR} came with Android, and these apps still use it:\n\n${list}\nRemove it anyway? They may stop working."; then
            echo "Keeping ${ANTIMICROX_DIR}."
            return 0
        fi
        [ "${ignore_warning}" = "true" ] && echo "Ignoring warnings: removing ${ANTIMICROX_DIR} anyway."
    fi
    echo "Removing ${ANTIMICROX_DIR}..."
    stop_from "${ANTIMICROX_DIR}"
    rm -rf "${ANTIMICROX_DIR:?}"
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: Install_Android_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    echo "Removing ${APP_NAME}..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT_PATH}</path></game></gameList>" >/dev/null 2>&1

    # A running Android: the andrl launcher (an shc-compiled script, so it
    # runs as bash with andrl as its first word), the QEMU it starts and
    # anything given a file of bat-drl/Android (AntiMicroX with the pad
    # profile).
    pkill -f "^(/usr/bin/)?andrl( |$)" 2>/dev/null
    pkill -f "${DRL_APP_DIR}/" 2>/dev/null
    stop_from "${DRL_APP_DIR}"
    stop_from "${ADDON_DIR}"

    rm -rf "${ADDON_DIR:?}"
    # BUA's symlink service links the files in the add-on's bin and lib
    # folders (andrl, qemu, antimicrox, libwayland-*) into /usr/bin and
    # /usr/lib. Remove the links that pointed into the add-on folder, now
    # left dangling. This comes after removing the folder so the service
    # can't make them again.
    find /usr/bin /usr/lib -maxdepth 1 -type l -lname "${ADDON_DIR}/*" -delete 2>/dev/null

    # QEMU, the BlissOS ISO, icons, pad profile and DRL's own remover.
    rm -rf "${DRL_APP_DIR:?}" "${TEMP_DIR:?}"

    rm -f "${PORT_SCRIPT_PATH}" "${PORT_SCRIPT_PATH}.keys"
    rm -f "${PORTS_DIR}/images/${APP_EXEC}-marquee.png" "${PORTS_DIR}/images/${APP_EXEC}-thumb.png"
    rm -f "${BACKUP_PATH}"

    if [ -f "${CUSTOM_SH}" ]; then
        sed -i "\|^${RESTORE_LINE}\$|d" "${CUSTOM_SH}"
    fi
    local entry
    for entry in ${DESKTOP_ENTRIES}; do
        rm -f "${DESKTOP_DIR}/${entry}"
    done
    rm -rf "${CONFIG_DIR:?}"
    # Shortcuts on the DRL desktop, links to the entries above.
    rm -f "${USER_DESKTOP_DIR}/Android.desktop" "${USER_DESKTOP_DIR}/Android_Config.desktop"
    rmdir "${USER_DESKTOP_DIR}" 2>/dev/null

    if [ -f "${GAMELIST_PATH}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${PORT_SCRIPT_NAME}']" "${GAMELIST_PATH}" > "${GAMELIST_PATH}.tmp" \
            && mv "${GAMELIST_PATH}.tmp" "${GAMELIST_PATH}"
    fi

    remove_antimicrox

    rmdir "${BAT_DRL}" 2>/dev/null

    # Files the user put here are theirs, so only an empty folder goes
    if [ -d "${SHARE_DIR}" ] && ! rmdir "${SHARE_DIR}" 2>/dev/null; then
        echo "Kept ${SHARE_DIR}: it still has files in it."
    fi

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
