#!/bin/bash

# === CONFIG ===
TAR_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/extra/x11vnc.tar.gz"
SERVICE_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/extra/x11vnc"
ADDONS_DIR="/userdata/system/add-ons"
SERVICES_DIR="/userdata/system/services"
TAR_NAME="x11vnc.tar.gz"
SERVICE_NAME="x11vnc"
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

# === STEP 4: Set executable permissions for bin/*
echo "Setting executable permissions..."
chmod -R +x "$ADDONS_DIR/x11vnc"

# === STEP 5: Remove .tar.gz ===
echo "Cleaning up $TAR_NAME..."
rm "$ADDONS_DIR/$TAR_NAME"

# === STEP 6: Download the service script ===
echo "Downloading service script..."
curl -L "$SERVICE_URL" -o "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 7: Make the service script executable ===
echo "Making service script executable..."
chmod +x "$SERVICES_DIR/$SERVICE_NAME"

batocera-services enable x11vnc &
batocera-services start x11vnc &>/dev/null &
# === STEP 8: Final success message via dialog ===
dialog --msgbox "x11vnc add-on and service installed successfully!\n\nYou can connect via VNC on port $PORT." 8 55
