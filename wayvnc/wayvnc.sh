#!/bin/bash

# === CONFIG ===
TAR_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/extra/wayvnc.tar.gz"
SERVICE_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/extra/wayvnc"
ADDONS_DIR="/userdata/system/add-ons"
SERVICES_DIR="/userdata/system/services"
TAR_NAME="wayvnc.tar.gz"
SERVICE_NAME="wayvnc"
PORT="5900"

# === STEP 1: Create destination directories ===
echo "Creating addon and service directories..."
mkdir -p "$ADDONS_DIR"
mkdir -p "$SERVICES_DIR"

# === STEP 2: Download .tar.gz file ===
echo "Downloading $TAR_NAME..."
curl -L "$TAR_URL" -o "$ADDONS_DIR/$TAR_NAME"

# === STEP 3: Extract the .tar.gz ===
echo "Extracting $TAR_NAME to $ADDONS_DIR..."
tar -xzf "$ADDONS_DIR/$TAR_NAME" -C "$ADDONS_DIR"

# === STEP 4: Set executable permissions for binary
echo "Setting executable permissions..."
chmod +x "$ADDONS_DIR/wayvnc/wayvnc"

# === STEP 5: Remove .tar.gz ===
echo "Cleaning up $TAR_NAME..."
rm "$ADDONS_DIR/$TAR_NAME"

# === STEP 6: Download the service script ===
echo "Downloading service script..."
curl -L "$SERVICE_URL" -o "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 7: Make the service script executable ===
echo "Making service script executable..."
chmod +x "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 8: Enable and start the service ===
batocera-services enable wayvnc &
batocera-services start wayvnc &>/dev/null &

# === STEP 9: Show completion message ===
dialog --msgbox "WayVNC add-on and service installed successfully!\n\nYou can connect via VNC on port $PORT." 8 55

