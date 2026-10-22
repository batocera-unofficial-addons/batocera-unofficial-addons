#!/bin/bash
# Uninstaller for Bridge, installed by bridge.sh.
# Removes the AppImage and icon, the desktop entry and its persistent copy,
# the restore script and its custom.sh line, and the settings and cache
# Bridge creates in /userdata/system/.config/bridge on first run. Charts
# Bridge downloaded are kept: they are in the library folder the user chose.

APPNAME="Bridge"

ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APPNAME,,}"
DESKTOP_FILE="${DESKTOP_DIR}/${APPNAME,,}.desktop"
RESTORE_SCRIPT="${APP_CONFIG_DIR}/restore_desktop_entry.sh"
USER_DATA_DIR="/userdata/system/.config/${APPNAME,,}"

main() {
    echo "Removing ${APPNAME}..."

    if [ -f "${CUSTOM_SCRIPT}" ]; then
        sed -i "\|${RESTORE_SCRIPT}|d" "${CUSTOM_SCRIPT}"
    fi

    rm -f "${DESKTOP_FILE}"
    rm -rf "${ADDONS_DIR:?}/${APPNAME,,}" "${APP_CONFIG_DIR:?}" "${USER_DATA_DIR:?}"

    echo "${APPNAME} has been removed."
}

main "$@"
