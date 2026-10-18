#!/bin/bash
set -euo pipefail

###############################################################################
# RunImage Desktop Uninstaller for Batocera
#
# Asks first when RunImage Desktop is running. To close it and uninstall
# without asking (in the BUA app: LB+RB on the installed apps screen):
#   curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/desktop/ri-desktop_uninstall.sh | bash -s -- --ignore-warning
###############################################################################

DEST_BASE="/userdata/system/add-ons/ri-desktop"
PORT_SCRIPT="/userdata/roms/ports/RunImageDesktop.sh"
PORTS_DIR="/userdata/roms/ports"
PAD2KEY_PROFILE="${PORTS_DIR}/RunImageDesktop.sh.keys"

ignore_warning=false
case "${1-}" in
    "") ;;
    --ignore-warning) ignore_warning=true ;;
    *) echo "Usage: ri-desktop_uninstall.sh [--ignore-warning]"; exit 2 ;;
esac

# Asks a yes/no question in the BUA app, or in the terminal. Returns 0 for
# Yes, 1 for No, a timeout, or no terminal at all. With --ignore-warning,
# every question is answered yes without asking.
ask() {
    local title="$1" text="$2"
    [ "${ignore_warning}" = "true" ] && return 0
    dialog --title "${title}" --clear --timeout 60 --yesno "${text}" 0 0
}

echo "==================================================================="
echo "RunImage Desktop Uninstaller"
echo "==================================================================="

# Check if any RunImage desktop processes are running
if pgrep -f "runimage.*rim-desktop" >/dev/null 2>&1 || \
   pgrep -f "Xephyr.*rim-desktop" >/dev/null 2>&1; then
    echo "[!] Warning: RunImage Desktop appears to be running."
    echo "[!] Please close it before uninstalling."
    echo ""
    echo "Active processes:"
    pgrep -fa "runimage.*rim-desktop" || true
    pgrep -fa "Xephyr.*rim-desktop" || true
    echo ""
    if ! ask "Uninstall RunImage Desktop" "RunImage Desktop appears to be running.\n\nClose it and uninstall anyway?"; then
        echo "[i] Uninstall cancelled."
        exit 1
    fi
    if [ "${ignore_warning}" = "true" ]; then
        echo "[i] Ignoring warnings: closing it and uninstalling anyway."
    fi

    echo "[*] Attempting to terminate RunImage Desktop..."
    pkill -f "runimage.*rim-desktop" 2>/dev/null || true
    pkill -f "Xephyr.*rim-desktop" 2>/dev/null || true
    sleep 2
fi

# Remove port entry
if [ -f "${PORT_SCRIPT}" ]; then
    echo "[*] Removing port entry..."
    rm -f "${PORT_SCRIPT}"
fi

# Remove pad-to-key profile and images
echo "[*] Removing pad-to-key profile and images..."
rm -f "${PAD2KEY_PROFILE}" "${PORTS_DIR}/images/desktop-logo.png" "${PORTS_DIR}/images/desktop-marquee.png"

# Remove installation directory
if [ -d "${DEST_BASE}" ]; then
    echo "[*] Removing installation directory..."
    echo "    Location: ${DEST_BASE}"

    # Show disk space that will be freed
    SIZE=$(du -sh "${DEST_BASE}" 2>/dev/null | cut -f1 || echo "unknown")
    echo "    Size: ${SIZE}"

    rm -rf "${DEST_BASE}"
fi

# Remove gamelist.xml entry
if [ -f "${PORTS_DIR}/gamelist.xml" ]; then
    echo "[*] Removing gamelist.xml entry..."
    xmlstarlet ed -d "/gameList/game[path='./RunImageDesktop.sh']" \
      "${PORTS_DIR}/gamelist.xml" > "${PORTS_DIR}/gamelist.xml.tmp" && \
      mv "${PORTS_DIR}/gamelist.xml.tmp" "${PORTS_DIR}/gamelist.xml" || true
fi

# Refresh EmulationStation game list
echo "[*] Refreshing EmulationStation..."
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 || true

echo ""
echo "==================================================================="
echo "RunImage Desktop uninstalled successfully!"
echo "==================================================================="
echo ""
