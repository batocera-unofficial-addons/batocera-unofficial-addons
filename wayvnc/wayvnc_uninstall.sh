#!/bin/bash
# Uninstaller for WayVNC, installed by wayvnc.sh.
# Stops and disables the wayvnc service and removes its script and log.
# The WayVNC binaries in /userdata/system/add-ons/wayvnc are shared with
# WayVNC Headless (wayvnc_headless.sh installs the same files there), so
# they are removed only when WayVNC Headless isn't installed.

SERVICE_NAME="wayvnc"
OTHER_SERVICE="wayvnc_headless"
SERVICES_DIR="/userdata/system/services"
ADDON_DIR="/userdata/system/add-ons/wayvnc"
LOG_FILE="/userdata/system/logs/wayvnc.log"

main() {
    echo "Removing WayVNC..."

    batocera-services stop "${SERVICE_NAME}" >/dev/null 2>&1
    batocera-services disable "${SERVICE_NAME}" >/dev/null 2>&1
    rm -f "${SERVICES_DIR}/${SERVICE_NAME}" "${LOG_FILE}" /tmp/wayvnc.stop

    if [ -f "${SERVICES_DIR}/${OTHER_SERVICE}" ]; then
        echo "Keeping ${ADDON_DIR}: WayVNC Headless is installed and uses it."
    else
        rm -rf "${ADDON_DIR:?}"
        # BUA's symlink service links the add-on's bin and lib files into
        # /usr/bin and /usr/lib. Remove the links that pointed into it.
        find /usr/bin /usr/lib -maxdepth 1 -type l -lname "${ADDON_DIR}/*" -delete 2>/dev/null
    fi

    echo "WayVNC has been removed."
}

main "$@"
