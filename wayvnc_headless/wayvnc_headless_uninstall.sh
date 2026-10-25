#!/bin/bash
# Uninstaller for WayVNC Headless

echo "========================================="
echo "Uninstalling: WayVNC Headless"
echo "========================================="
echo ""

# Stop and disable service
batocera-services stop wayvnc_headless >/dev/null 2>&1
batocera-services disable wayvnc_headless >/dev/null 2>&1

# Remove service script
if [ -f "/userdata/system/services/wayvnc_headless" ]; then
    echo "Removing file: /userdata/system/services/wayvnc_headless"
    rm -f "/userdata/system/services/wayvnc_headless"
fi

# Remove addon directory
if [ -d "/userdata/system/add-ons/wayvnc" ]; then
    echo "Removing directory: /userdata/system/add-ons/wayvnc"
    rm -rf "/userdata/system/add-ons/wayvnc"
fi

echo ""
echo "========================================="
echo "Uninstallation complete: WayVNC Headless"
echo "========================================="
