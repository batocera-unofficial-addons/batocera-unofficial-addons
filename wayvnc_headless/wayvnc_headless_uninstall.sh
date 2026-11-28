#!/bin/bash
# Uninstaller for WayVNC Headless, installed by wayvnc_headless.sh.
# Stops and disables the wayvnc_headless service (which also stops the
# headless sway it started) and removes its script and logs.
# The WayVNC binaries in /userdata/system/add-ons/wayvnc are shared with
# WayVNC (wayvnc.sh installs the same files there), so they are removed
# only when WayVNC isn't installed.

SERVICE_NAME="wayvnc_headless"
OTHER_SERVICE="wayvnc"
SERVICES_DIR="/userdata/system/services"
ADDON_DIR="/userdata/system/add-ons/wayvnc"
LOG_FILE="/userdata/system/logs/wayvnc_headless.log"

# Stops the service without its own "stop": older versions of the service
# script ran "pkill sway" there, which also ended a desktop sway session.
# Only the headless sway (started with WLR_BACKENDS=headless) is stopped.
stop_service() {
    local pid
    touch /tmp/wayvnc_headless.stop
    pkill -f "/usr/bin/wayvnc 0.0.0.0" 2>/dev/null
    for pid in $(pgrep -x sway); do
        if tr '\0' '\n' < "/proc/${pid}/environ" 2>/dev/null | grep -qx "WLR_BACKENDS=headless"; then
            kill "${pid}" 2>/dev/null
        fi
    done
}

main() {
    echo "Removing WayVNC Headless..."

    if grep -q "pkill sway" "${SERVICES_DIR}/${SERVICE_NAME}" 2>/dev/null; then
        stop_service
    else
        batocera-services stop "${SERVICE_NAME}" >/dev/null 2>&1
    fi
    batocera-services disable "${SERVICE_NAME}" >/dev/null 2>&1
    rm -f "${SERVICES_DIR}/${SERVICE_NAME}" "${LOG_FILE}" /tmp/sway_headless.log \
        /tmp/wayvnc_headless.stop /tmp/wayvnc_headless_sway.pid

    if [ -f "${SERVICES_DIR}/${OTHER_SERVICE}" ]; then
        echo "Keeping ${ADDON_DIR}: WayVNC is installed and uses it."
    else
        rm -rf "${ADDON_DIR:?}"
        # BUA's symlink service links the add-on's bin and lib files into
        # /usr/bin and /usr/lib. Remove the links that pointed into it.
        find /usr/bin /usr/lib -maxdepth 1 -type l -lname "${ADDON_DIR}/*" -delete 2>/dev/null
    fi

    echo "WayVNC Headless has been removed."
}

main "$@"
