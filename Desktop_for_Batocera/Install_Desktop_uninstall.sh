#!/bin/bash

ADDON_NAME="desktop_drl"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
SERVICE_PATH="/userdata/system/services/${ADDON_NAME}"
TEMP_DIR="/userdata/tmp/Desktop_for_Batocera"

echo "========================================="
echo "Uninstalling: DESKTOP_FOR_BATOCERA"
echo "========================================="
echo ""

if command -v batocera-services >/dev/null 2>&1; then
    echo "Stopping service: ${ADDON_NAME}"
    batocera-services stop "${ADDON_NAME}" 2>/dev/null || true
    echo "Disabling service: ${ADDON_NAME}"
    batocera-services disable "${ADDON_NAME}" 2>/dev/null || true
fi

if [ -f "$SERVICE_PATH" ]; then
    echo "Removing service file: $SERVICE_PATH"
    rm -f "$SERVICE_PATH"
fi

if [ -d "$ADDON_DIR" ]; then
    echo "Removing addon data: $ADDON_DIR"
    rm -rf "$ADDON_DIR"
fi

if [ -d "$TEMP_DIR" ]; then
    echo "Removing temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
fi

echo ""
echo "========================================="
echo "Uninstallation complete: DESKTOP_FOR_BATOCERA"
echo "========================================="
