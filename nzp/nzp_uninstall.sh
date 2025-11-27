#!/bin/bash
set -euo pipefail

###############################################################################
# Nazi Zombies: Portable Uninstaller for Batocera
###############################################################################

INSTALL_DIR="/userdata/roms/ports/nzp"
LAUNCHER_SCRIPT="/userdata/roms/ports/Nazi Zombies Portable.sh"
PORTS_DIR="/userdata/roms/ports"

echo "==================================================================="
echo "Nazi Zombies: Portable Uninstaller"
echo "==================================================================="

# Check if any NZP processes are running
if pgrep -f "nzportable" >/dev/null 2>&1; then
    echo "[!] Warning: Nazi Zombies: Portable appears to be running."
    echo "[!] Please close it before uninstalling."
    echo ""
    echo "Active processes:"
    pgrep -fa "nzportable" || true
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[i] Uninstall cancelled."
        exit 0
    fi

    echo "[*] Attempting to terminate Nazi Zombies: Portable..."
    pkill -f "nzportable" 2>/dev/null || true
    sleep 2
fi

# Remove launcher script
if [ -f "${LAUNCHER_SCRIPT}" ]; then
    echo "[*] Removing launcher script..."
    rm -f "${LAUNCHER_SCRIPT}"
fi

# Remove logo
if [ -f "${PORTS_DIR}/images/nzp-logo.png" ]; then
    echo "[*] Removing logo..."
    rm -f "${PORTS_DIR}/images/nzp-logo.png"
fi

# Remove installation directory
if [ -d "${INSTALL_DIR}" ]; then
    echo "[*] Removing installation directory..."
    echo "    Location: ${INSTALL_DIR}"

    # Show disk space that will be freed
    SIZE=$(du -sh "${INSTALL_DIR}" 2>/dev/null | cut -f1 || echo "unknown")
    echo "    Size: ${SIZE}"

    rm -rf "${INSTALL_DIR}"
fi

# Remove gamelist.xml entry
echo "[*] Removing gamelist.xml entry..."
if [ -f /userdata/roms/ports/gamelist.xml ]; then
    xmlstarlet ed -d "/gameList/game[path='./Nazi Zombies Portable.sh']" \
      /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && \
      mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml 2>/dev/null || true
fi

# Refresh EmulationStation game list
echo "[*] Refreshing EmulationStation..."
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 || true

echo ""
echo "==================================================================="
echo "Nazi Zombies: Portable uninstalled successfully!"
echo "==================================================================="
echo ""
