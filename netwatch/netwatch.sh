#!/bin/bash
# netwatch installer for Batocera. Run it again to update; your
# netwatch.conf and aliases.conf are kept.
#   curl -L https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/netwatch/netwatch.sh | bash

REPO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/netwatch"
INSTALL_DIR="/userdata/system/add-ons/netwatch"
SERVICE="/userdata/system/services/netwatch"

main() {
    set -euo pipefail
    local tmp f
    tmp="$(mktemp -d)"
    trap "rm -rf '${tmp}'" EXIT   # path expanded now; the local is gone by exit time

    echo "Downloading netwatch..."
    for f in netwatch.py overlay.py dashboard.html netwatch-service.sh netwatch.conf aliases.conf; do
        wget -q -O "${tmp}/${f}" "${REPO_URL}/${f}" || { echo "Failed to download ${f}"; exit 1; }
    done

    # Stop a running copy (an update) only once the download has succeeded.
    if [ -x "${SERVICE}" ]; then
        batocera-services stop netwatch || true
    fi

    echo "Installing to ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}" "$(dirname "${SERVICE}")"
    cp "${tmp}/netwatch.py" "${tmp}/overlay.py" "${tmp}/dashboard.html" "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/netwatch.py" "${INSTALL_DIR}/overlay.py"
    for f in netwatch.conf aliases.conf; do
        [ -f "${INSTALL_DIR}/${f}" ] || cp "${tmp}/${f}" "${INSTALL_DIR}/${f}"   # never overwrite your settings
    done

    # Point the service at INSTALL_DIR, in case it was changed above.
    sed "s#^NETWATCH_HOME=.*#NETWATCH_HOME=\"${INSTALL_DIR}\"#" "${tmp}/netwatch-service.sh" > "${SERVICE}"
    chmod +x "${SERVICE}"

    batocera-services enable netwatch
    batocera-services start netwatch

    echo "netwatch is installed and running."
    echo "Dashboard: http://$(hostname -i 2>/dev/null | awk '{print $1}'):8686/"
    echo "Settings:  ${INSTALL_DIR}/netwatch.conf"
}

# Called on the last line so the whole script is downloaded before it runs.
main "$@"