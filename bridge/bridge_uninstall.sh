#!/bin/bash
# Uninstaller for Bridge, installed by bridge.sh.
# Removes the AppImage and icon, the desktop entry and its persistent copy,
# and the restore script and its custom.sh line. Kept: Bridge's settings in
# /userdata/system/.config/bridge and the charts it downloaded (in the
# library folder the user chose).

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
    rm -rf "${ADDONS_DIR:?}/${APPNAME,,}" "${APP_CONFIG_DIR:?}"

    echo "${APPNAME} has been removed."
    if [ -d "${USER_DATA_DIR}" ]; then
        echo "Bridge settings were kept in ${USER_DATA_DIR}."
    fi
    echo "Downloaded charts were kept in your chart library folder."
}

main "$@"
