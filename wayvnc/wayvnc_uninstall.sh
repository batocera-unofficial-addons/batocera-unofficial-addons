#!/bin/bash
# Uninstaller for WayVNC

echo "========================================="
echo "Uninstalling: WayVNC"
echo "========================================="
echo ""

# Stop and disable service
batocera-services stop wayvnc >/dev/null 2>&1
batocera-services disable wayvnc >/dev/null 2>&1

# Remove service script
if [ -f "/userdata/system/services/wayvnc" ]; then
    echo "Removing file: /userdata/system/services/wayvnc"
    rm -f "/userdata/system/services/wayvnc"
fi

# Remove addon directory
if [ -d "/userdata/system/add-ons/wayvnc" ]; then
    echo "Removing directory: /userdata/system/add-ons/wayvnc"
    rm -rf "/userdata/system/add-ons/wayvnc"
fi

echo ""
echo "========================================="
echo "Uninstallation complete: WayVNC"
echo "========================================="
