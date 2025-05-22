#!/bin/bash

echo "Preparing dark mode install..."

# Define paths
DEST_DIR="/userdata/system/add-ons/darkmode"
SERVICE_DIR="/userdata/system/services"
ZIP_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/dark/extra/Adwaita-dark.zip"
SERVICE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/dark/extra/dark_mode"
ZIP_FILE="${DEST_DIR}/Adwaita-dark.zip"
SERVICE_FILE="${SERVICE_DIR}/dark_mode"

# Create destination folders
mkdir -p "$DEST_DIR" "$SERVICE_DIR"

# Download and extract theme
echo "Downloading Adwaita-dark.zip..."
wget -q -O "$ZIP_FILE" "$ZIP_URL"

if [ -f "$ZIP_FILE" ]; then
    echo "Extracting theme..."
    unzip -oq "$ZIP_FILE" -d "$DEST_DIR"
    rm -f "$ZIP_FILE"
else
    echo "Error: Failed to download Adwaita-dark.zip"
    exit 1
fi

# Download service script
echo "Downloading dark_mode service..."
wget -q -O "$SERVICE_FILE" "$SERVICE_URL"
chmod +x "$SERVICE_FILE"

echo "Dark mode install complete. You can toggle dark mode on and off via the services menu."
