#!/bin/bash
# netwatch installer for Batocera. Run it again to update; your
# netwatch.conf and aliases.conf are kept.
#   curl -L https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/netwatch/netwatch.sh | bash

REPO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/netwatch"
INSTALL_DIR="/userdata/system/add-ons/netwatch"
SERVICE="/userdata/system/services/netwatch"

# Print the dashboard's addresses, using the --web-port, --web-bind and
# --web-auth set in netwatch.conf (the service reads the same file). Each line
# carries its URL, because the BUA app's end dialog only shows lines with one.
dashboard_addresses() {
    local args port="8686" bind="0.0.0.0" login="" ifname addr found=""
    # Read the file in a subshell, as the service does, so its settings stay there.
    args="$(
        set +eu
        # shellcheck disable=SC2034  # netwatch.conf may use it, as it can in the service
        NETWATCH_HOME="${INSTALL_DIR}"
        NETWATCH_ARGS=""
        # shellcheck disable=SC1091  # netwatch.conf is installed above
        . "${INSTALL_DIR}/netwatch.conf" >/dev/null 2>&1
        printf '%s' "${NETWATCH_ARGS}"
    )"
    # Split the arguments into words the way the service does.
    # shellcheck disable=SC2086
    set -- ${args}
    while [ "$#" -gt 0 ]; do
        case "$1" in
            --web-port) port="${2:-${port}}"; [ "$#" -gt 1 ] && shift ;;
            --web-port=*) port="${1#*=}" ;;
            --web-bind) bind="${2:-${bind}}"; [ "$#" -gt 1 ] && shift ;;
            --web-bind=*) bind="${1#*=}" ;;
            --web-auth|--web-auth=*) login=" (login required)" ;;
        esac
        shift
    done

    if [ "${port}" = "0" ]; then
        echo "Dashboard: turned off (--web-port 0 in netwatch.conf)"
        return 0
    fi

    # IPv4 address of every interface, skipping loopback and container bridges.
    while read -r ifname addr; do
        addr="${addr%/*}"
        case "${ifname}" in
            lo|docker*|br-*|veth*|virbr*|cni*) continue ;;
        esac
        if [ "${bind}" != "0.0.0.0" ] && [ "${bind}" != "${addr}" ]; then
            continue
        fi
        case "${ifname}" in
            tailscale*) echo "Dashboard over Tailscale: http://${addr}:${port}/${login}" ;;
            *)          echo "Dashboard on your network: http://${addr}:${port}/${login}" ;;
        esac
        found=1
    done < <(ip -o -4 addr show 2>/dev/null | awk '{print $2, $4}')

    if [ -z "${found}" ]; then
        case "${bind}" in
            0.0.0.0) echo "Dashboard: http://<this device's IP>:${port}/${login}" ;;
            127.*)   echo "Dashboard (this device only): http://${bind}:${port}/${login}" ;;
            *)       echo "Dashboard: http://${bind}:${port}/${login}" ;;
        esac
    fi
}

# main runs in a subshell, so its set and trap stay inside it. The BUA app
# sources this script and has its own EXIT trap, which would be replaced.
main() (
    set -euo pipefail
    local tmp f
    tmp="$(mktemp -d)"
    trap "rm -rf '${tmp}'" EXIT   # path expanded now; the local is gone by exit time

    echo "Downloading NetWatch..."
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

    echo "NetWatch is installed and running."
    dashboard_addresses
    echo "Settings:  ${INSTALL_DIR}/netwatch.conf"
)

# Called on the last line so the whole script is downloaded before it runs.
main "$@"