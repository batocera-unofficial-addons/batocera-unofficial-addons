#!/bin/bash
# Uninstaller for Heroic Games Launcher, installed by heroic.sh.
# Removes the AppImage, its launchers and helper scripts, the umu runtime
# copy, the desktop entry and its persistent copy, the restore script and its
# custom.sh line, and the Heroic system for EmulationStation with the game
# launchers, images and gamelist the add-on creates in /userdata/roms/heroic.
# Heroic is started from the F1 menu, so it keeps its settings, store logins
# and downloaded Wine/Proton builds in /userdata/system/.config/heroic, and
# installs games to /userdata/system/Games/Heroic by default.
# Asks first when games installed through Heroic are found: Yes deletes them,
# their Wine prefixes (where Windows games keep their saves) and Heroic's
# settings; No keeps all three, so a reinstalled Heroic still finds the games.
# To remove everything without asking (in the BUA app: LB+RB on the installed
# apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/heroic/heroic_uninstall.sh | bash -s -- --ignore-warning

INSTALL_DIR="/userdata/system/add-ons/heroic"
DESKTOP_FILE="/usr/share/applications/heroic.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/heroic/heroic.desktop"
SYSTEMS_CFG="/userdata/system/configs/emulationstation/es_systems_heroic.cfg"
ROM_DIR="/userdata/roms/heroic"
RESTORE_SCRIPT="${PERSISTENT_DESKTOP%/*}/restore_desktop_entry.sh"
custom_startup="/userdata/system/custom.sh"

# Written by Heroic itself once it has run.
HEROIC_CONFIG_DIR="/userdata/system/.config/heroic"
GAMES_DIR="/userdata/system/Games/Heroic"
PREFIXES_DIR="${GAMES_DIR}/Prefixes"
# Steam Linux Runtime that umu downloads the first time a Windows game runs.
UMU_DATA_DIR="/userdata/system/.local/share/umu"
# Heroic's own logs, written on every start
HEROIC_STATE_DIR="/userdata/system/.local/state/Heroic"

ignore_warning=false   # set to true by --ignore-warning in main

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

# Only game folders well below /userdata or a mounted disk are deleted, so a
# damaged install record can't point the uninstaller at a top-level folder.
safe_game_dir() {
    case "$1" in
        *"/../"*|*"/.."|*"/./"*) return 1 ;;
        /userdata/*/*|/media/*/*) [ -d "$1" ] ;;
        *) return 1 ;;
    esac
}

# Games installed through Heroic, one "<path>|<title>" line each, read from
# the install records of its Epic (legendary), GOG and Amazon (nile) stores,
# plus any other folder in the default games folder.
installed_games() {
    local file
    {
        file="${HEROIC_CONFIG_DIR}/legendaryConfig/legendary/installed.json"
        [ -f "${file}" ] && jq -r '.[] | "\(.install_path)|\(.title)"' "${file}"
        file="${HEROIC_CONFIG_DIR}/gog_store/installed.json"
        [ -f "${file}" ] && jq -r '.installed[] | "\(.install_path)|"' "${file}"
        file="${HEROIC_CONFIG_DIR}/nile_config/nile/installed.json"
        [ -f "${file}" ] && jq -r '.[] | "\(.path)|"' "${file}"
        if [ -d "${GAMES_DIR}" ]; then
            find "${GAMES_DIR}" -mindepth 1 -maxdepth 1 -type d ! -path "${PREFIXES_DIR}" -printf '%p|\n'
        fi
    } 2>/dev/null | while IFS='|' read -r path title; do
        path="${path%/}"
        safe_game_dir "${path}" || continue
        echo "${path}|${title:-${path##*/}}"
    done | sort -t '|' -k 1,1 -u
}

main() {
    case "${1-}" in
        "") ;;
        --ignore-warning) ignore_warning=true ;;
        *) echo "Usage: heroic_uninstall.sh [--ignore-warning]"; exit 2 ;;
    esac

    local games line path list="" delete_games=true
    games="$(installed_games)"
    if [ -n "${games}" ] || [ -n "$(ls -A "${PREFIXES_DIR}" 2>/dev/null)" ]; then
        while IFS='|' read -r path line; do
            [ -n "${path}" ] && list+="  - ${line} (${path})\n"
        done <<< "${games}"
        [ -n "$(ls -A "${PREFIXES_DIR}" 2>/dev/null)" ] && list+="  - Wine prefixes, with Windows game saves (${PREFIXES_DIR})\n"
        echo "WARNING: these games were installed through Heroic and will be deleted,"
        echo "with Heroic's settings and store logins:"
        printf '%b\n' "${list}"
        if [ "${ignore_warning}" = "true" ]; then
            echo "Ignoring warnings: deleting them anyway."
        elif ! ask "Uninstall Heroic" "These games were installed through Heroic:\n\n${list}\nDelete them, with Heroic's settings and store logins?\n\nNo keeps them, so a reinstalled Heroic still finds the games."; then
            delete_games=false
        fi
    fi

    echo "Removing Heroic Games Launcher..."

    # The monitor rebuilds the game launchers every second while Heroic runs,
    # and the umu setup script waits in a loop until Heroic has installed umu.
    pkill -f "${INSTALL_DIR}/monitor_heroic.sh" 2>/dev/null
    pkill -f "${INSTALL_DIR}/setup_umu_symlink.sh" 2>/dev/null
    pkill -f "${INSTALL_DIR}/heroic.AppImage" 2>/dev/null
    pkill -f "/tmp/.mount_heroic" 2>/dev/null
    sleep 1

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload. Removing the games
    # through ES first, while their launchers still exist, drops them from
    # memory.
    local txt xml=""
    for txt in "${ROM_DIR}"/*.txt; do
        [ -f "${txt}" ] || continue
        txt="${txt//&/&amp;}"; txt="${txt//</&lt;}"
        xml+="<game><path>${txt}</path></game>"
    done
    if [ -n "${xml}" ]; then
        curl -s -X POST "http://127.0.0.1:1234/removegames/heroic" \
            -d "<gameList>${xml}</gameList>" >/dev/null 2>&1
    fi

    rm -rf "${INSTALL_DIR:?}"
    rm -f "${DESKTOP_FILE}" "${SYSTEMS_CFG}"
    rm -rf "${PERSISTENT_DESKTOP%/*}"
    if [ -f "${custom_startup}" ]; then
        sed -i "\|${RESTORE_SCRIPT}|d" "${custom_startup}"
    fi
    # The game launchers (.txt files holding a Heroic game ID), their images
    # and the gamelist. They only start games through Heroic, and Heroic
    # makes them again for the games it finds when it is reinstalled.
    rm -rf "${ROM_DIR:?}"
    rm -rf "${UMU_DATA_DIR:?}"
    rm -rf "${HEROIC_STATE_DIR:?}"
    rmdir "${HEROIC_STATE_DIR%/*}" 2>/dev/null

    if [ "${delete_games}" = "true" ]; then
        while IFS='|' read -r path line; do
            [ -n "${path}" ] && rm -rf "${path:?}"
        done <<< "${games}"
        rm -rf "${GAMES_DIR:?}" "${HEROIC_CONFIG_DIR:?}"
        rmdir "${GAMES_DIR%/*}" 2>/dev/null
        # Menu shortcuts Heroic makes for games when that setting is on.
        grep -lsF "heroic://launch" /userdata/system/.local/share/applications/*.desktop \
            /userdata/system/Desktop/*.desktop | while IFS= read -r line; do
            rm -f "${line}"
        done
    else
        echo "Kept the games, their Wine prefixes and Heroic's settings:"
        printf '%b' "${list}"
        echo "  - Heroic's settings and store logins (${HEROIC_CONFIG_DIR})"
    fi

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Heroic Games Launcher has been removed."
}

main "$@"
