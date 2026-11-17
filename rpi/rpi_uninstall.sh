#!/bin/bash
# Uninstaller for Raspberry Pi Imager, installed by rpi.sh (x86_64 and ARM64).
# Removes the AppImage and icon, the desktop entry and its persistent copy,
# the restore script and its custom.sh lines, and what Imager creates in
# /userdata/system on first run: its settings, its cache (OS list and the
# last downloaded image), and the rpi-imager:// URL handler entry with its
# mimeapps.list line.

APP_NAME="rpi"
DISPLAY_NAME="Raspberry Pi Imager"

ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APP_NAME,,}"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_NAME,,}.desktop"
RESTORE_SCRIPT="${APP_CONFIG_DIR}/restore_desktop_entry.sh"

# Imager runs from the F1 menu with HOME=/userdata/system. Qt keeps its
# settings and cache under the organisation folder "Raspberry Pi", which
# other Raspberry Pi apps may share, so only Imager's own entries go.
USER_HOME="/userdata/system"
ORG_CONFIG_DIR="${USER_HOME}/.config/Raspberry Pi"
ORG_CACHE_DIR="${USER_HOME}/.cache/Raspberry Pi"
URI_HANDLER="${USER_HOME}/.local/share/applications/com.raspberrypi.rpi-imager-uri-handler.desktop"
MIMEAPPS_LIST="${USER_HOME}/.config/mimeapps.list"

main() {
    echo "Removing ${DISPLAY_NAME}..."

    # Anchored, so it only matches the AppImage itself, not a shell whose
    # command line mentions its path
    pkill -f "^${ADDONS_DIR}/${APP_NAME,,}/${APP_NAME,,}.AppImage" >/dev/null 2>&1

    if [ -f "${CUSTOM_SCRIPT}" ]; then
        # The installer adds a blank line, a comment and the restore call
        sed -i -e "\|${RESTORE_SCRIPT}|d" "${CUSTOM_SCRIPT}"
        sed -i -e "/^$/{N;/^\n# Restore ${APP_NAME} desktop entry at startup$/d;P;D}" \
            -e "/^# Restore ${APP_NAME} desktop entry at startup$/d" "${CUSTOM_SCRIPT}"
    fi

    rm -f "${DESKTOP_FILE}"
    rm -rf "${ADDONS_DIR:?}/${APP_NAME,,}" "${APP_CONFIG_DIR:?}"

    rm -f "${ORG_CONFIG_DIR}/${DISPLAY_NAME}.conf"
    rm -rf "${ORG_CACHE_DIR:?}/${DISPLAY_NAME}"
    rmdir "${ORG_CONFIG_DIR}" "${ORG_CACHE_DIR}" 2>/dev/null

    rm -f "${URI_HANDLER}"
    if [ -f "${MIMEAPPS_LIST}" ]; then
        sed -i "\|^x-scheme-handler/rpi-imager=|d" "${MIMEAPPS_LIST}"
    fi

    echo "${DISPLAY_NAME} has been removed."
    exit 0
}

main "$@"
