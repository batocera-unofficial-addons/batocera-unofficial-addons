#!/bin/bash

# === CONFIG ===
TAR_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/extra/x11vnc.tar.gz"
SERVICE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/extra/x11vnc"
ADDONS_DIR="/userdata/system/add-ons"
SERVICES_DIR="/userdata/system/services"
TAR_NAME="x11vnc.tar.gz"
SERVICE_NAME="x11vnc"
PORT="5900"

# === STEP 1: Check display server ===
X11_SOCK=$(ls /tmp/.X11-unix/X* 2>/dev/null | head -n1)
WAYLAND_SOCK=$(ls /run/user/0/wayland-* 2>/dev/null | head -n1)

if [ -z "$X11_SOCK" ]; then
    if [ -n "$WAYLAND_SOCK" ]; then
        if dialog --yesno "This system is using Wayland, not X11.\n\nx11vnc requires X11. Would you like to install wayvnc instead?" 9 55; then
            curl -s "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/wayvnc.sh" | bash
        fi
    else
        dialog --msgbox "ERROR: No display server detected.\n\nMake sure X11 is running before installing x11vnc." 8 55
    fi
    exit 0
fi

# === STEP 2: Create destination directories ===
echo "Creating addon and service directories..."
mkdir -p "$ADDONS_DIR"
mkdir -p "$SERVICES_DIR"

# === STEP 3: Download .tar.gz file ===
echo "Downloading $TAR_NAME..."
curl -L "$TAR_URL" -o "$ADDONS_DIR/$TAR_NAME"

# === STEP 4: Extract the .tar.gz ===
echo "Extracting $TAR_NAME to $ADDONS_DIR..."
tar -xzf "$ADDONS_DIR/$TAR_NAME" -C "$ADDONS_DIR"

# === STEP 5: Set executable permissions for bin/*
echo "Setting executable permissions..."
chmod -R +x "$ADDONS_DIR/x11vnc"

# === STEP 6: Remove .tar.gz ===
echo "Cleaning up $TAR_NAME..."
rm "$ADDONS_DIR/$TAR_NAME"

# === STEP 7: Download the service script ===
echo "Downloading service script..."
curl -L "$SERVICE_URL" -o "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 8: Make the service script executable ===
echo "Making service script executable..."
chmod +x "$SERVICES_DIR/$SERVICE_NAME"

batocera-services enable x11vnc &
batocera-services start x11vnc &>/dev/null &
# === STEP 9: Final success message via dialog ===
dialog --msgbox "x11vnc add-on and service installed successfully!\n\nYou can connect via VNC on port $PORT." 8 55
