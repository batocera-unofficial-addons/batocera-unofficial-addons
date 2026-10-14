#!/bin/bash
# Uninstaller for Armagetron Advanced, installed by armagetron.sh.
# Removes the AppImage, its settings, the Ports launcher, keys, logo and
# gamelist entry, and the log and config link the launcher creates.

app_dir="/userdata/system/add-ons/armagetron"
config_dir="${app_dir}/armagetron-config"
log_file="/userdata/system/logs/armagetron.log"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="${PORTS_DIR}/gamelist.xml"

main() {
    echo "Removing Armagetron Advanced..."
    rm -rf "${app_dir:?}"
    rm -f "${PORTS_DIR}/Armagetron.sh" "${PORTS_DIR}/Armagetron.sh.keys" "${PORTS_DIR}/images/armagetron-logo.png"
    rm -f "${log_file}"

    # The launcher links ${HOME}/.config/armagetron to the config dir. It
    # exports PID 1's environment first, where HOME is /, so the link is
    # usually /.config/armagetron.
    local config_symlink
    for config_symlink in "/.config/armagetron" "/userdata/system/.config/armagetron"; do
        if [ "$(readlink "${config_symlink}")" = "${config_dir}" ]; then
            rm -f "${config_symlink}"
        fi
    done

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./Armagetron.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Armagetron Advanced has been removed."
}

main "$@"
