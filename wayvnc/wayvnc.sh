#!/bin/bash

# === CONFIG ===
REPO_BASE="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/extra"
SERVICE_URL="$REPO_BASE/wayvnc"
ADDONS_DIR="/userdata/system/add-ons"
SERVICES_DIR="/userdata/system/services"
TAR_NAME="wayvnc.tar.gz"
SERVICE_NAME="wayvnc"
PORT="5900"

# === STEP 1: Check display server ===
WAYLAND_SOCK=$(ls /run/user/0/wayland-* 2>/dev/null | head -n1)
X11_SOCK=$(ls /tmp/.X11-unix/X* 2>/dev/null | head -n1)

if [ -z "$WAYLAND_SOCK" ]; then
    if [ -n "$X11_SOCK" ]; then
        if dialog --yesno "This system is using X11, not Wayland.\n\nWayVNC requires Wayland. Would you like to install x11vnc instead?" 9 55; then
            curl -s "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/x11vnc/x11vnc.sh" | bash
        fi
    else
        dialog --msgbox "ERROR: No display server detected.\n\nMake sure Wayland is running before installing WayVNC." 8 55
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
        echo "Unsupported architecture: $ARCH"
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
batocera-services enable wayvnc &
batocera-services start wayvnc &>/dev/null &

# === STEP 11: Show completion message ===
dialog --msgbox "WayVNC add-on and service installed successfully!\n\nYou can connect via VNC on port $PORT." 8 55
