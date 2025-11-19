#!/bin/bash

# === CONFIG ===
SERVICE_NAME="versionclean"
SERVICES_DIR="/userdata/system/services"
SERVICE_FILE="$SERVICES_DIR/$SERVICE_NAME"

echo "Uninstalling VersionClean service..."

# === STEP 1: Stop the service ===
if batocera-services list | grep -q "$SERVICE_NAME"; then
    echo "Stopping service: $SERVICE_NAME"
    batocera-services stop "$SERVICE_NAME" 2>/dev/null
fi

# === STEP 2: Disable the service ===
if batocera-services list | grep -q "$SERVICE_NAME"; then
    echo "Disabling service: $SERVICE_NAME"
    batocera-services disable "$SERVICE_NAME" 2>/dev/null
fi

# === STEP 3: Remove the service script ===
if [ -f "$SERVICE_FILE" ]; then
    echo "Removing file: $SERVICE_FILE"
    rm -f "$SERVICE_FILE"
fi

echo "VersionClean service uninstalled successfully!"
