#!/bin/bash
# Uninstaller for LUTRIS (v2 — RunImage build)

echo "========================================="
echo "Uninstalling: LUTRIS"
echo "========================================="
echo ""

# Remove desktop files
rm -f "/userdata/system/configs/lutris/Lutris.desktop"
rm -f "/usr/share/applications/Lutris.desktop"

# Clean up custom.sh entries
sed -i '/restore_desktop_entry\.sh/d' /userdata/system/custom.sh 2>/dev/null || true

# Remove batocera.conf emulator entries
sed -i '/^lutris\.emulator=/d; /^lutris\.core=/d' /userdata/system/batocera.conf 2>/dev/null || true

# Remove EmulationStation config
rm -f "/userdata/system/configs/emulationstation/es_systems_lutris.cfg"
rm -f "/userdata/system/configs/emulationstation/es_features_lutris.cfg"

# Remove Lutris system roms (launchers + generated game entries)
rm -rf "/userdata/roms/lutris"

# Remove install directory and configs
rm -rf "/userdata/system/add-ons/lutris"
rm -rf "/userdata/system/configs/lutris"

echo ""
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo ""
echo "========================================="
echo "Uninstallation complete: LUTRIS"
echo "========================================="
