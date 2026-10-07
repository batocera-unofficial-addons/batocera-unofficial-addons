#!/bin/bash
# netwatch uninstaller for Batocera. Removes netwatch, its service, its
# settings and its logs, including logs moved elsewhere in netwatch.conf.
#   curl -L https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/netwatch/netwatch_uninstall.sh | bash

INSTALL_DIR="/userdata/system/add-ons/netwatch"
SERVICE="/userdata/system/services/netwatch"

main() {
    # Read netwatch.conf the same way the service does, to find the logs.
    NETWATCH_HOME="${INSTALL_DIR}"
    NETWATCH_LOG=""
    NETWATCH_SERVICE_LOG=""
    [ -f "${INSTALL_DIR}/netwatch.conf" ] && . "${INSTALL_DIR}/netwatch.conf"
    NETWATCH_LOG="${NETWATCH_LOG:-${INSTALL_DIR}/netwatch.log}"
    NETWATCH_SERVICE_LOG="${NETWATCH_SERVICE_LOG:-$(dirname "${NETWATCH_LOG}")/netwatch-service.log}"

    echo "Stopping netwatch..."
    batocera-services stop netwatch 2>/dev/null
    batocera-services disable netwatch 2>/dev/null
    [ -x "${SERVICE}" ] && "${SERVICE}" stop >/dev/null 2>&1   # in case batocera-services didn't

    echo "Removing netwatch..."
    rm -f "${SERVICE}" /var/run/netwatch.pid
    rm -f "${NETWATCH_LOG}" "${NETWATCH_LOG}".[0-9]* "${NETWATCH_SERVICE_LOG}" "${NETWATCH_SERVICE_LOG}".[0-9]*
    rm -rf "${INSTALL_DIR}"

    echo "netwatch has been removed."
}

main "$@"