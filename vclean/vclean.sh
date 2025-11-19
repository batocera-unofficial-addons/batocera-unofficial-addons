#!/bin/bash

# === CONFIG ===
SERVICE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/vclean/extra/versionclean"
SERVICES_DIR="/userdata/system/services"
SERVICE_NAME="versionclean"

# === STEP 1: Create service directory ===
echo "Creating service directory..."
mkdir -p "$SERVICES_DIR"

# === STEP 2: Download the service script ===
echo "Downloading service script..."
curl -L "$SERVICE_URL" -o "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 3: Make the service script executable ===
echo "Making service script executable..."
chmod +x "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 4: Enable and start the service ===
echo "Enabling and starting service..."
batocera-services enable "$SERVICE_NAME" &
batocera-services start "$SERVICE_NAME" &>/dev/null &

# === STEP 5: Final success message via dialog ===
dialog --msgbox "VersionClean service installed successfully!\n\nThe Batocera version string will now show without extra flags. You can disable this by running batocera-services stop versionclean, if for whatever reason that's what you want to do" 8 65
