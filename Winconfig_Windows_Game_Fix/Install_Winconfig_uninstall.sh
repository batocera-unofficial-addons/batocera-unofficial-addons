#!/bin/bash
# Uninstaller for Winconfig - Windows Game Fix (DRL Edition), installed by
# Install_Winconfig.sh and the Winconfig_gamelist_config.sh it runs.
# Removes the WinConfig programs and the links BUA's symlink service makes to
# them, the Ports launcher, keys, images and gamelist entry, the F1 menu and
# desktop entries, the redist Wine prefix, DRL Edition's own remover, and the
# settings, logs and Winetricks cache WinConfig creates when used.
# Changes WinConfig made to Windows games (autorun.cmd and batocera.plus
# files, renamed or compressed game folders) are kept: the games still start
# without it, and the originals can't be brought back.
# Game backups WinConfig made, and AntiMicroX and its controller profile when
# another installed add-on still uses them, are removed after a question. To
# answer yes to everything without asking (in the BUA app: LB+RB on the
# installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/Winconfig_Windows_Game_Fix/Install_Winconfig_uninstall.sh | bash -s -- --ignore-warning

TEMP_DIR="/userdata/tmp/Winconfig"
PORTS_DIR="/userdata/roms/ports"
ADDON_BIN="/userdata/system/add-ons/winconfig/bin"
DEPS_INSTALLER="- Windows Game Fix.sh"
ATALHO="/userdata/system/.local/share/applications/WinConfig.desktop"
GAMELIST_FILE_PATH="${PORTS_DIR}/gamelist.xml"

ADDON_DIR="${ADDON_BIN%/bin}"
BAT_DRL="/userdata/system/configs/bat-drl"
WINCONFIG_DIR="${BAT_DRL}/WinConfig"
BACKUP_DIR="${WINCONFIG_DIR}/backup"
REDIST_DIR="${BAT_DRL}/redist"
ANTIMICROX_DIR="${BAT_DRL}/AntiMicroX"
ANTIMICROX_PROFILE="${BAT_DRL}/Nav_Redist2.joystick.amgp"
WINETRICKS_CACHE="/userdata/saves/winetricks_manager_cache"
APPLICATIONS_DIR="/userdata/system/.local/share/applications"
DESKTOP_DIR="/userdata/system/Desktop"
ES_DIR="/userdata/system/configs/emulationstation"
CUSTOM_SH="/userdata/system/custom.sh"

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

# Prints what, other than WinConfig and the given shared part, still refers
# to the pattern: Ports launchers, services, other bat-drl packages, ES
# systems, custom.sh, and symlinks in other add-ons (e.g. f1/bin/antimicrox).
# One name per line, nothing when unused.
users_of() {
    local pattern="$1" path link
    for path in "${BAT_DRL}"/* "${PORTS_DIR}"/*.sh /userdata/system/services/* \
                "${ES_DIR}"/es_systems_*.cfg "${CUSTOM_SH}"; do
        [ -e "${path}" ] || continue
        case "${path}" in
            "${ANTIMICROX_DIR}" | "${ANTIMICROX_PROFILE}" | "${WINCONFIG_DIR}" | "${REDIST_DIR}" | \
                "${BAT_DRL}/Remover_WinConfig.sh" | "${PORTS_DIR}/${DEPS_INSTALLER}") continue ;;
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

# Removes a shared file or dir. When another installed app still uses it
# (the given users), asks first: Yes removes it, No keeps it.
remove_shared() {
    local part="$1" users="$2" line list=""
    [ -e "${part}" ] || return 0
    if [ -n "${users}" ]; then
        while IFS= read -r line; do
            list+="  - ${line}\n"
        done <<< "${users}"
        echo "WARNING: ${part} is still used by:"
        printf '%b\n' "${list}"
        if ! ask "Uninstall Winconfig" "${part} came with Winconfig, and these apps still use it:\n\n${list}\nRemove it anyway? They may stop working."; then
            echo "Keeping ${part}."
            return 0
        fi
        [ "${ignore_warning}" = "true" ] && echo "Ignoring warnings: removing ${part} anyway."
    fi
    echo "Removing ${part}..."
    rm -rf "${part:?}"
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: Install_Winconfig_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    # Read before anything is removed.
    local antimicrox_users profile_users
    [ -d "${ANTIMICROX_DIR}" ] && antimicrox_users="$(users_of "antimicrox" | sort -u)"
    [ -f "${ANTIMICROX_PROFILE}" ] && profile_users="$(users_of "Nav_Redist2" | sort -u)"

    echo "Removing Winconfig - Windows Game Fix..."
    pkill -f "[w]inconfig-redist" 2>/dev/null
    pkill -f "[r]edist-winetricks" 2>/dev/null

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORTS_DIR}/${DEPS_INSTALLER}</path></game></gameList>" >/dev/null 2>&1

    rm -f "${PORTS_DIR}/${DEPS_INSTALLER}" "${PORTS_DIR}/${DEPS_INSTALLER}.keys"
    rm -f "${PORTS_DIR}/images/WindowsGameFix-marquee.png" "${PORTS_DIR}/images/WindowsGameFix-thumb.png"

    rm -rf "${ADDON_DIR:?}"
    # BUA's symlink service links the files in the add-on's bin folder into
    # /usr/bin. Remove the links that pointed into it, now left dangling.
    # This comes after removing the folder so the service can't make them
    # again.
    find /usr/bin -maxdepth 1 -type l -lname "${ADDON_DIR}/*" -delete 2>/dev/null

    rm -f "${ATALHO}" "${APPLICATIONS_DIR}/Remover_WinConfig.desktop"
    if [ "$(readlink "${DESKTOP_DIR}/WinConfig.desktop")" = "${ATALHO}" ]; then
        rm -f "${DESKTOP_DIR}/WinConfig.desktop"
    fi
    rmdir "${DESKTOP_DIR}" 2>/dev/null

    rm -f "${BAT_DRL}/WindowsGameFix-icon.png" "${BAT_DRL}/Remover_WinConfig.png" "${BAT_DRL}/Remover_WinConfig.sh"
    echo "Removing the redist Wine prefix..."
    rm -rf "${REDIST_DIR:?}"

    # Game backups (.bkpdrl) in WinConfig's default backup folder, and Wine
    # prefix backups in the Winetricks cache. Backups in a folder chosen in
    # WinConfig's settings are not touched.
    local backups list=""
    backups="$(find "${BACKUP_DIR}" -type f 2>/dev/null; find "${WINETRICKS_CACHE}" -type f -name "*_prefix_backup_*" 2>/dev/null)"
    if [ -n "${backups}" ]; then
        local line
        while IFS= read -r line; do
            list+="  - ${line##*/}\n"
        done <<< "${backups}"
        echo "WARNING: WinConfig made these game backups:"
        printf '%b\n' "${list}"
        if ask "Uninstall Winconfig" "WinConfig made these game backups:\n\n${list}\nRemove them? No keeps them in ${BACKUP_DIR} and ${WINETRICKS_CACHE}."; then
            [ "${ignore_warning}" = "true" ] && echo "Ignoring warnings: removing the backups anyway."
            rm -rf "${WINCONFIG_DIR:?}" "${WINETRICKS_CACHE:?}"
        else
            echo "Keeping the backups."
            find "${WINCONFIG_DIR}" -mindepth 1 -maxdepth 1 ! -name backup -exec rm -rf {} + 2>/dev/null
            find "${WINETRICKS_CACHE}" -type f ! -name "*_prefix_backup_*" -delete 2>/dev/null
            find "${WINETRICKS_CACHE}" -mindepth 1 -type d -empty -delete 2>/dev/null
        fi
    else
        rm -rf "${WINCONFIG_DIR:?}" "${WINETRICKS_CACHE:?}"
    fi

    remove_shared "${ANTIMICROX_DIR}" "${antimicrox_users}"
    # AntiMicroX's own settings, written when Winconfig starts it
    [ -e "${ANTIMICROX_DIR}" ] || rm -rf "/userdata/system/.config/antimicrox"
    remove_shared "${ANTIMICROX_PROFILE}" "${profile_users}"
    rmdir "${BAT_DRL}" 2>/dev/null

    rm -rf "${TEMP_DIR:?}"
    rm -f /tmp/gamelistconfig.sh

    if [ -f "${GAMELIST_FILE_PATH}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${DEPS_INSTALLER}']" "${GAMELIST_FILE_PATH}" > "${GAMELIST_FILE_PATH}.tmp" \
            && mv "${GAMELIST_FILE_PATH}.tmp" "${GAMELIST_FILE_PATH}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Winconfig - Windows Game Fix has been removed."
    echo "Changes it made to Windows games in /userdata/roms/windows were kept."
}

main "$@"
