#!/bin/bash

# Variables to update for different apps
APP_NAME="Hydra"
REPO="hydralauncher/hydra"
AMD_SUFFIX=".AppImage"
ARM_SUFFIX=""
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/hydra/extra/hydra-icon.png"
MONITOR_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/hydra/extra/monitor-hydra.sh"
SYNC_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/hydra/extra/aria2-sync.sh"
BIN_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/hydra/extra/aria2c"
# Directories
ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APP_NAME,,}"
PERSISTENT_DESKTOP="${APP_CONFIG_DIR}/${APP_NAME,,}.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_NAME,,}.desktop"

# Ensure directories exist
echo "Creating necessary directories..."
mkdir -p "$APP_CONFIG_DIR" "$ADDONS_DIR/${APP_NAME,,}/extra" "$ADDONS_DIR/${APP_NAME,,}/usr/bin"


# Step 1: Detect system architecture and fetch the latest release
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r ".assets[] | select(.name | endswith(\"$AMD_SUFFIX\")) | .browser_download_url")
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    if [ -n "$ARM_SUFFIX" ]; then
        appimage_url=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r ".assets[] | select(.name | endswith(\"$ARM_SUFFIX\")) | .browser_download_url")
    else
        echo "No ARM64 AppImage suffix provided. Skipping download. Exiting."
        exit 1
    fi
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

if [ -z "$appimage_url" ]; then
    echo "No suitable AppImage found for architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading $APP_NAME AppImage from $appimage_url..."
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}.AppImage" "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME AppImage."
    exit 1
fi

chmod a+x "$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}.AppImage"
echo "$APP_NAME AppImage downloaded and marked as executable."

# Step 2.5: Download the application icon
echo "Downloading $APP_NAME icon..."
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/extra/${APP_NAME,,}-icon.png" "$ICON_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME icon."
    exit 1
fi
echo "Downloading necessary scripts..."
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/extra/monitor-hydra.sh" "$MONITOR_URL"
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/extra/aria2-sync.sh" "$SYNC_URL"
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/usr/bin/aria2" "$BIN_URL"
chmod +x "$ADDONS_DIR/${APP_NAME,,}/extra/monitor-hydra.sh"
chmod +x "$ADDONS_DIR/${APP_NAME,,}/extra/aria2-sync.sh"
chmod +x "$ADDONS_DIR/${APP_NAME,,}/usr/bin/aria2c"

# Step 3: Create persistent desktop entry
echo "Creating persistent desktop entry for $APP_NAME..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APP_NAME
Exec=$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}.AppImage --no-sandbox && $ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}/extra/monitor-hydra.sh &
Icon=$ADDONS_DIR/${APP_NAME,,}/extra/${APP_NAME,,}-icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring $APP_NAME desktop entry is restored at startup..."
cat <<EOF > "${APP_CONFIG_DIR}/restore_desktop_entry.sh"
#!/bin/bash
# Restore $APP_NAME desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring $APP_NAME desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "$APP_NAME desktop entry restored."
else
    echo "$APP_NAME desktop entry already exists."
fi
EOF
chmod +x "${APP_CONFIG_DIR}/restore_desktop_entry.sh"

if ! grep -q "${APP_CONFIG_DIR}/restore_desktop_entry.sh" "$CUSTOM_SCRIPT"; then
    echo "Adding desktop entry restore script to startup..."
    echo "bash \"${APP_CONFIG_DIR}/restore_desktop_entry.sh\" &" >> "$CUSTOM_SCRIPT"
else
    echo "Restore script already exists in $CUSTOM_SCRIPT."
fi

echo "$APP_NAME desktop entry creation complete."
