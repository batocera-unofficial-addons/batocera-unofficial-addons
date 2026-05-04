#!/bin/bash
# Uninstaller for WPS Office

echo "========================================="
echo "Uninstalling: WPS Office"
echo "========================================="
echo ""

for f in \
    "/userdata/system/configs/wps-office/WPS-Office.desktop" \
    "/usr/share/applications/WPS-Office.desktop" \
    "/userdata/system/add-ons/wps-office/WPS-Office.AppImage" \
    "/userdata/system/add-ons/wps-office/extra/icon.png" \
    "/userdata/system/configs/wps-office/restore_desktop_entry.sh"; do
    [ -f "$f" ] && echo "Removing $f" && rm -f "$f"
done

for d in \
    "/userdata/system/add-ons/wps-office/extra" \
    "/userdata/system/add-ons/wps-office" \
    "/userdata/system/configs/wps-office"; do
    [ -d "$d" ] && echo "Removing $d" && rm -rf "$d"
done

echo ""
echo "========================================="
echo "Uninstallation complete: WPS Office"
echo "========================================="
