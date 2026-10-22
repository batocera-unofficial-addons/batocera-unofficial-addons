#!/bin/bash
# Uninstaller for ShadPS4 Plus, installed by shadps4plus.sh.
# Removes the AppImage and its scripts, the desktop entry and its custom.sh
# line, the ES system override for PS4 (Batocera's own PS4 system comes back
# after the next ES restart), and what the add-on creates while it runs: the
# per-game launchers, keys files and gamelist entries in the PS4 roms folder,
# the box art, the log, and the emulator's settings and saves in
# /userdata/system/.local/share/shadPS4. Game folders in /userdata/roms/ps4
# are kept.

APP_NAME="ShadPS4 Plus"

install_dir="/userdata/system/add-ons/shadps4"
custom_startup="/userdata/system/custom.sh"
desktop_file="/usr/share/applications/shadps4.desktop"
emulationstation_config_dir="/userdata/system/configs/emulationstation"
output_dir="/userdata/roms/ps4"
gamelist_path="${output_dir}/gamelist.xml"
processed_list="/userdata/system/.local/share/shadPS4/processed_games.txt"
log_file="/userdata/system/logs/shadps4_installer.log"
csv_file="/tmp/PS4_Title_ID_List.csv"

main() {
    echo "Removing ${APP_NAME}..."

    # While the emulator runs, the monitor recreates the game launchers every
    # second, so stop both before removing anything.
    pkill -f "${install_dir}/monitor_shadps4.sh" >/dev/null 2>&1
    pkill -f "${install_dir}/shadps4plus.AppImage" >/dev/null 2>&1

    # The monitor writes a launcher, a keys file and a gamelist entry for
    # each game folder it finds, and lists the folder in processed_games.txt.
    # Remove those launchers only; the game folders are the user's.
    if [ -f "${processed_list}" ]; then
        while read -r processed_game; do
            [ -n "${processed_game}" ] || continue
            sanitized_name=$(echo "${processed_game}" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
            [ -n "${sanitized_name}" ] || continue

            # ES keeps a played game's stats (playcount, lastplayed) in memory
            # and writes them back to gamelist.xml on the next reload, which
            # brings back the entry removed below. Removing the game through
            # ES first, while its launcher still exists, drops it from memory.
            curl -s -X POST "http://127.0.0.1:1234/removegames/ps4" \
                -d "<gameList><game><path>${output_dir}/${sanitized_name}.sh</path></game></gameList>" >/dev/null 2>&1

            rm -f "${output_dir}/${sanitized_name}.sh" "${output_dir}/${sanitized_name}.sh.keys"

            if [ -f "${gamelist_path}" ]; then
                xmlstarlet ed -d "/gameList/game[path='./${sanitized_name}.sh']" "${gamelist_path}" > "${gamelist_path}.tmp" \
                    && mv "${gamelist_path}.tmp" "${gamelist_path}"
            fi
        done < "${processed_list}"
    fi

    if [ -f "${custom_startup}" ]; then
        sed -i "\|${install_dir}/restore_desktop_entry.sh|d" "${custom_startup}"
    fi

    rm -f "${desktop_file}"
    rm -f "${emulationstation_config_dir}/es_features_ps4.cfg" "${emulationstation_config_dir}/es_systems_ps4.cfg"
    rm -rf "${install_dir:?}" "/userdata/system/.local/share/shadPS4"
    rm -f "${log_file}" "${csv_file}"

    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
