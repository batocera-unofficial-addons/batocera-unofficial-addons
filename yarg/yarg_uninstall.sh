#!/bin/bash
# Uninstaller for YARG, installed by yarg.sh.
# Removes the YARC Launcher AppImage, its start script and icon, the desktop
# entry and its persistent copy, the restore script and its custom.sh line,
# the Ports launcher, logo and gamelist entry, and the log the launcher
# creates. Both launchers set HOME to the add-on folder, so the launcher's
# settings and the YARG game it installs (in .local/share/YARC) are removed
# with it.

APP_NAME="YARG"
INSTALL_DIR="/userdata/system/add-ons/yarg"
LOGS_DIR="/userdata/system/logs"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
LOGO_PATH="${PORTS_DIR}/images/yarg-logo.png"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
DESKTOP_FILE="/usr/share/applications/YARC-Launcher.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/yarg/YARC-Launcher.desktop"
CUSTOM_SH="/userdata/system/custom.sh"
CONFIG_DIR="${PERSISTENT_DESKTOP%/*}"

main() {
    echo "Removing ${APP_NAME}..."

    # ES keeps a played game's stats (playcount, lastplayed) in memory and
    # writes them back to gamelist.xml on the next reload, which brings back
    # the entry removed below. Removing the game through ES first, while its
    # launcher still exists, drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    if [ -f "${CUSTOM_SH}" ]; then
        sed -i "\|${CONFIG_DIR}/restore_desktop_entry.sh|d" "${CUSTOM_SH}"
    fi

    rm -f "${DESKTOP_FILE}"
    rm -rf "${INSTALL_DIR:?}" "${CONFIG_DIR:?}"
    rm -f "${PORT_SCRIPT}" "${LOGO_PATH}"
    rm -f "${LOGS_DIR}/${APP_NAME,,}.log"

    if [ -f "${GAME_LIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" "${GAME_LIST}" > "${GAME_LIST}.tmp" \
            && mv "${GAME_LIST}.tmp" "${GAME_LIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "${APP_NAME} has been removed."
}

main "$@"
