#!/bin/bash
# Uninstaller for F1, installed by f1.sh.
# Removes the Ports launcher, its logo and gamelist entry, the add-on folder
# (/userdata/system/add-ons/f1) and the /usr/bin/antimicrox link BUA's
# symlink service made to it.
# AntiMicroX and its Nav_Redist2 controller profile in
# /userdata/system/configs/bat-drl came with F1, but other DRL Edition
# add-ons (Winconfig, Android) install and use the same files. They are
# removed only when nothing else still uses them; otherwise they are kept.

APP_NAME="F1"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME}-logo.jpg"
ADDON_DIR="/userdata/system/add-ons/f1"
TEMP_DIR="/userdata/tmp/Antimicrox"

BAT_DRL="/userdata/system/configs/bat-drl"
ANTIMICROX_DIR="${BAT_DRL}/AntiMicroX"
ANTIMICROX_PROFILE="${BAT_DRL}/Nav_Redist2.joystick.amgp"
ES_DIR="/userdata/system/configs/emulationstation"
CUSTOM_SH="/userdata/system/custom.sh"

# Prints what, other than F1, still refers to the pattern: Ports launchers,
# services, other bat-drl packages, ES systems, custom.sh, and links in
# other add-ons (e.g. winconfig/bin/antimicrox). One name per line, nothing
# when unused.
users_of() {
    local pattern="$1" path link
    for path in "${BAT_DRL}"/* "${PORTS_DIR}"/*.sh /userdata/system/services/* \
                "${ES_DIR}"/es_systems_*.cfg "${CUSTOM_SH}"; do
        [ -e "${path}" ] || continue
        case "${path}" in
            "${ANTIMICROX_DIR}" | "${ANTIMICROX_PROFILE}" | "${PORT_SCRIPT}") continue ;;
        esac
        grep -rqsiI -e "${pattern}" "${path}" && basename "${path}"
    done
    find /userdata/system/add-ons -mindepth 2 -maxdepth 3 -ilname "*${pattern}*" 2>/dev/null |
        while IFS= read -r link; do
            link="${link#/userdata/system/add-ons/}"
            [ "${link%%/*}" = "${ADDON_DIR##*/}" ] && continue
            echo "${link%%/*} add-on"
        done
}

# Removes a shared file or dir, unless another installed app still uses it
# (the given users): then it is kept.
remove_shared() {
    local part="$1" users="$2" line
    [ -e "${part}" ] || return 0
    if [ -n "${users}" ]; then
        echo "Keeping ${part}, still used by:"
        while IFS= read -r line; do
            echo "  - ${line}"
        done <<< "${users}"
        return 0
    fi
    echo "Removing ${part}..."
    rm -rf "${part:?}"
}

main() {
    echo "Removing ${APP_NAME}..."

    # Read before anything is removed.
    local antimicrox_users="" profile_users=""
    [ -d "${ANTIMICROX_DIR}" ] && antimicrox_users="$(users_of "antimicrox" | sort -u)"
    [ -f "${ANTIMICROX_PROFILE}" ] && profile_users="$(users_of "Nav_Redist2" | sort -u)"

    # ES keeps a played game's stats in memory and writes them back to
    # gamelist.xml on the next reload, which brings back the entry removed
    # below. Removing the game through ES first, while its launcher still
    # exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    rm -f "${PORT_SCRIPT}" "${PORT_SCRIPT}.keys" "${LOGO_PATH}"

    rm -rf "${ADDON_DIR:?}"
    # BUA's symlink service links the files in the add-on's bin folder into
    # /usr/bin. Remove the links that pointed into it, now left dangling.
    find /usr/bin -maxdepth 1 -type l -lname "${ADDON_DIR}/*" -delete 2>/dev/null
    # If another add-on ships its own bin/antimicrox, link that one now
    # (the symlink service skipped it while F1's link was in the way).
    local other
    for other in /userdata/system/add-ons/*/bin/antimicrox; do
        if [ -e "${other}" ] && [ ! -e /usr/bin/antimicrox ]; then
            ln -s "${other}" /usr/bin/antimicrox 2>/dev/null
        fi
    done

    remove_shared "${ANTIMICROX_DIR}" "${antimicrox_users}"
    # AntiMicroX's own settings, written when F1 starts it
    [ -e "${ANTIMICROX_DIR}" ] || rm -rf "/userdata/system/.config/antimicrox"
    remove_shared "${ANTIMICROX_PROFILE}" "${profile_users}"
    rmdir "${BAT_DRL}" 2>/dev/null

    rm -rf "${TEMP_DIR:?}"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
