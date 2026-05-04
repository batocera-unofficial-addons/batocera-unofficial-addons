#!/bin/bash
# BUA - Remove Batocera Boot Overlay
# Properly removes /boot/boot/overlay

OVERLAY_FILE="/boot/boot/overlay"

echo "## BUA - Remove Batocera Boot Overlay"
echo

# Check running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must be run as root."
    exit 1
fi

# Check file exists
if [ ! -f "$OVERLAY_FILE" ]; then
    echo "No overlay file found at $OVERLAY_FILE"
    echo "Nothing to do."
    exit 0
fi

# Remount /boot read-write
echo "Remounting /boot as read-write..."
if ! mount -o remount,rw /boot; then
    echo "Error: failed to remount /boot as read-write."
    exit 1
fi

# Remove overlay
echo "Removing $OVERLAY_FILE..."
rm -f "$OVERLAY_FILE"
sync

# Remount /boot read-only
echo "Remounting /boot as read-only..."
mount -o remount,ro /boot || true

echo
echo "Overlay removed successfully."
echo "Please reboot for the change to take effect."
