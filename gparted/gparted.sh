#!/bin/bash

# Define variables
APPNAME="GParted"
REPO_BASE_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/gparted/extra/"
AMD_SUFFIX="gparted.AppImage"
ARM_SUFFIX=""
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/gparted/extra/icon.png"

# Directories
ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APPNAME,,}"
PERSISTENT_DESKTOP="${APP_CONFIG_DIR}/${APPNAME,,}.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${APPNAME,,}.desktop"

# Ensure directories exist
mkdir -p "$APP_CONFIG_DIR" "$ADDONS_DIR/${APPNAME,,}/extra"

# Detect system architecture
arch=$(uname -m)
case "$arch" in
    x86_64)
        appimage_url="${REPO_BASE_URL}${AMD_SUFFIX}"
        ;;
    aarch64)
        if [ -n "$ARM_SUFFIX" ]; then
            appimage_url="${REPO_BASE_URL}${ARM_SUFFIX}"
        else
            echo "No ARM64 AppImage available. Exiting."
            exit 1
        fi
        ;;
    *)
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
        ;;
esac

# Download the AppImage
if ! wget -q --show-progress -O "$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage" "$appimage_url"; then
    echo "Failed to download $APPNAME AppImage. Exiting."
    exit 1
fi
chmod a+x "$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage"

# Download the application icon
if ! wget -q --show-progress -O "$ADDONS_DIR/${APPNAME,,}/extra/${APPNAME,,}-icon.png" "$ICON_URL"; then
    echo "Failed to download $APPNAME icon. Exiting."
    exit 1
fi

# Create persistent desktop entry
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APPNAME
Exec=$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage
Icon=$ADDONS_DIR/${APPNAME,,}/extra/${APPNAME,,}-icon.png
Terminal=false
Categories=Utility;batocera.linux;
EOF
chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Create restore script
cat <<EOF > "${APP_CONFIG_DIR}/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF
chmod +x "${APP_CONFIG_DIR}/restore_desktop_entry.sh"

# Add restore script to startup
if ! grep -q "${APP_CONFIG_DIR}/restore_desktop_entry.sh" "$CUSTOM_SCRIPT"; then
    echo "\"${APP_CONFIG_DIR}/restore_desktop_entry.sh\" &" >> "$CUSTOM_SCRIPT"
fi

echo "$APPNAME setup complete."
