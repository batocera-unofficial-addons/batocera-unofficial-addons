#!/bin/bash
# Uninstaller for Prism Launcher, installed by prismlauncher.sh.
# Removes the AppImage, launch wrapper and icon, the Ports launcher, logo
# and gamelist entry, the desktop entry, its restore script and custom.sh
# line, and the log.
# Keeps your Minecraft data (instances, worlds, accounts, settings) in
# /userdata/system/add-ons/prismlauncher/data, so a reinstall picks it up
# again.

INSTALL_DIR="/userdata/system/add-ons/prismlauncher"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="/userdata/system/configs/prismlauncher"
RESTORE_SCRIPT="${CONFIG_DIR}/restore_desktop_entry.sh"
PORTS_DIR="/userdata/roms/ports"
GAMELIST="${PORTS_DIR}/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/PrismLauncher.sh"

main() {
    echo "Uninstalling Prism Launcher..."

    pkill -f "${INSTALL_DIR}/prismlauncher.AppImage" 2>/dev/null

    # ES keeps a played game's stats in memory and writes them back to
    # gamelist.xml on the next reload, which brings back the entry removed
    # below. Removing the game through ES first drops it from memory.
    curl -s -X POST "http://127.0.0.1:1234/removegames/ports" \
        -d "<gameList><game><path>${PORT_SCRIPT}</path></game></gameList>" >/dev/null 2>&1

    # Program files only; the data folder is kept.
    rm -f "${INSTALL_DIR}/prismlauncher.AppImage" "${INSTALL_DIR}/launch.sh"
    rm -rf "${INSTALL_DIR}/extra" "${INSTALL_DIR}/.cache"
    rmdir "${INSTALL_DIR}" 2>/dev/null

    rm -f "/usr/share/applications/prismlauncher.desktop"
    rm -f "${CONFIG_DIR}/prismlauncher.desktop" "${RESTORE_SCRIPT}"
    rmdir "${CONFIG_DIR}" 2>/dev/null
    if [ -f /userdata/system/custom.sh ]; then
        sed -i "\|${RESTORE_SCRIPT}|d" /userdata/system/custom.sh
    fi

    rm -f "${PORT_SCRIPT}" "${PORT_SCRIPT}.keys" "${PORTS_DIR}/images/PrismLauncher-logo.png"
    rm -f /userdata/system/logs/prismlauncher.log

    if [ -f "${GAMELIST}" ]; then
        xmlstarlet ed -d "/gameList/game[path='./PrismLauncher.sh']" "${GAMELIST}" > "${GAMELIST}.tmp" \
            && mv "${GAMELIST}.tmp" "${GAMELIST}"
    fi
    curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1

    echo "Prism Launcher uninstalled."
    if [ -d "${DATA_DIR}" ]; then
        echo "Your Minecraft instances, worlds and accounts were kept in:"
        echo "  ${DATA_DIR}"
        echo "Delete that folder to free the space, or reinstall to use it again."
    fi
}

main "$@"
