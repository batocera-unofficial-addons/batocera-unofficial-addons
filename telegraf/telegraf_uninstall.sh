#!/bin/bash
# Uninstaller for Telegraf, installed by telegraf.sh.
# Stops and disables the telegraf service and removes it, the Telegraf
# binary, the default config copy, the unit file and the log folder.
# Kept: your configuration (telegraf.conf and telegraf.d) and the install log.

SERVICE_NAME="telegraf"
SERVICE_SCRIPT="/userdata/system/services/${SERVICE_NAME}"
INSTALL_DIR="/userdata/system/add-ons/telegraf"
CONF_DIR="${INSTALL_DIR}/etc/telegraf"

remove_file() {
    if [ -f "$1" ]; then
        echo "Removing: $1"
        rm -f "$1"
    fi
}

main() {
    echo "========================================="
    echo "Uninstalling: Telegraf"
    echo "========================================="
    echo ""

    if [ -f "$SERVICE_SCRIPT" ]; then
        echo "Stopping and disabling the ${SERVICE_NAME} service..."
        batocera-services stop "$SERVICE_NAME" >/dev/null 2>&1
        batocera-services disable "$SERVICE_NAME" >/dev/null 2>&1
    fi
    pkill -f "${INSTALL_DIR}/telegraf" >/dev/null 2>&1
    remove_file "$SERVICE_SCRIPT"

    remove_file "${INSTALL_DIR}/telegraf"
    remove_file "${INSTALL_DIR}/telegraf.service"
    remove_file "${CONF_DIR}/telegraf.conf.default"
    if [ -d "${INSTALL_DIR}/log" ]; then
        echo "Removing: ${INSTALL_DIR}/log"
        rm -rf "${INSTALL_DIR:?}/log"
    fi
    if [ -d /userdata/temp-telegraf ]; then
        echo "Removing: /userdata/temp-telegraf"
        rm -rf /userdata/temp-telegraf
    fi

    # Remove the folders only if no configuration is left in them
    rmdir "${CONF_DIR}/telegraf.d" "$CONF_DIR" "${INSTALL_DIR}/etc" "$INSTALL_DIR" 2>/dev/null

    echo ""
    if [ -d "$CONF_DIR" ]; then
        echo "Your Telegraf configuration was kept in ${CONF_DIR}."
    fi
    echo ""
    echo "========================================="
    echo "Uninstallation complete: Telegraf"
    echo "========================================="
}

main "$@"
