#!/bin/bash
set -euo pipefail

###############################################################################
# RunImage Desktop Uninstaller for Batocera
###############################################################################

DEST_BASE="/userdata/system/add-ons/ri-desktop"
PORT_SCRIPT="/userdata/roms/ports/RunImageDesktop.sh"

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
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[i] Uninstall cancelled."
        exit 0
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

# Remove installation directory
if [ -d "${DEST_BASE}" ]; then
    echo "[*] Removing installation directory..."
    echo "    Location: ${DEST_BASE}"

    # Show disk space that will be freed
    SIZE=$(du -sh "${DEST_BASE}" 2>/dev/null | cut -f1 || echo "unknown")
    echo "    Size: ${SIZE}"

    rm -rf "${DEST_BASE}"
fi

# Refresh EmulationStation game list
echo "[*] Refreshing EmulationStation..."
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 || true

echo ""
echo "==================================================================="
echo "RunImage Desktop uninstalled successfully!"
echo "==================================================================="
echo ""
