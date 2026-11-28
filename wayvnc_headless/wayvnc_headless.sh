#!/bin/bash

# === CONFIG ===
REPO_BASE="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/extra"
SERVICE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc_headless/extra/wayvnc_headless"
ADDONS_DIR="/userdata/system/add-ons"
SERVICES_DIR="/userdata/system/services"
TAR_NAME="wayvnc.tar.gz"
SERVICE_NAME="wayvnc_headless"
PORT="5900"

# === STEP 1: Check for sway ===
# The service starts its own headless sway session, so no display (or
# running Wayland session) is needed, only the sway compositor that
# Batocera's Wayland builds ship. X11 builds don't have it.
if ! command -v sway >/dev/null 2>&1; then
    X11_SOCK=$(ls /tmp/.X11-unix/X* 2>/dev/null | head -n1)
    if [ -n "$X11_SOCK" ] || command -v Xorg >/dev/null 2>&1; then
        if dialog --yesno "This Batocera build uses X11 and has no sway.\n\nWayVNC Headless needs sway (Wayland builds). Would you like to install x11vnc instead?" 10 60; then
            curl -s "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/x11vnc.sh" | bash
        fi
    else
        dialog --msgbox "ERROR: sway was not found.\n\nWayVNC Headless needs a Batocera build that ships sway (Wayland)." 8 60
    fi
    exit 0
fi

# === STEP 2: Detect architecture ===
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        TAR_URL="$REPO_BASE/wayvnc_x86_64.tar.gz"
        ;;
    aarch64)
        TAR_URL="$REPO_BASE/wayvnc.tar.gz"
        ;;
    *)
        dialog --title "WayVNC" --msgbox "Unsupported architecture: $ARCH" 8 60
        exit 1
        ;;
esac
echo "Architecture: $ARCH"

# === STEP 3: Create destination directories ===
echo "Creating addon and service directories..."
mkdir -p "$ADDONS_DIR"
mkdir -p "$SERVICES_DIR"

# === STEP 4: Download .tar.gz file ===
echo "Downloading $TAR_NAME..."
curl -L "$TAR_URL" -o "$ADDONS_DIR/$TAR_NAME"

# === STEP 5: Extract the .tar.gz ===
echo "Extracting $TAR_NAME to $ADDONS_DIR..."
tar -xzf "$ADDONS_DIR/$TAR_NAME" -C "$ADDONS_DIR"

# === STEP 6: Set executable permissions for binary ===
echo "Setting executable permissions..."
chmod +x "$ADDONS_DIR/wayvnc/bin/wayvnc"
chmod +x "$ADDONS_DIR/wayvnc/bin/wayvncctl"

# === STEP 7: Remove .tar.gz ===
echo "Cleaning up $TAR_NAME..."
rm "$ADDONS_DIR/$TAR_NAME"

# === STEP 8: Download the service script ===
echo "Downloading service script..."
curl -L "$SERVICE_URL" -o "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 9: Make the service script executable ===
echo "Making service script executable..."
chmod +x "$SERVICES_DIR/$SERVICE_NAME"

# === STEP 10: Enable and start the service ===
batocera-services enable wayvnc_headless &
batocera-services start wayvnc_headless &>/dev/null &

# === STEP 11: Show completion message ===
dialog --msgbox "WayVNC headless add-on and service installed successfully!\n\nYou can connect via VNC on port $PORT." 8 55
