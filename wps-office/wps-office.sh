#!/bin/bash

APP_NAME="wps-office"
ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_DIR="$ADDONS_DIR/$APP_NAME"
APP_CONFIG_DIR="$CONFIGS_DIR/$APP_NAME"
APPIMAGE="$APP_DIR/WPS-Office.AppImage"
DESKTOP_FILE="$DESKTOP_DIR/WPS-Office.desktop"
PERSISTENT_DESKTOP="$APP_CONFIG_DIR/WPS-Office.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/wps-office/extra/icon.png"
ICON_PATH="$APP_DIR/extra/icon.png"

echo "Creating directories..."
mkdir -p "$APP_DIR/extra" "$APP_CONFIG_DIR/home"

# Architecture check
arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
    echo "WPS Office AppImage is only available for x86_64. Exiting."
    exit 1
fi

# Get latest AppImage URL from continuous release
echo "Fetching latest WPS Office AppImage URL..."
appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/WPS-Office-appimage/releases/tags/continuous \
    | jq -r '.assets[] | select(.name | endswith("x86_64.AppImage")) | .browser_download_url' | head -1)

if [ -z "$appimage_url" ]; then
    echo "Failed to fetch AppImage URL. Exiting."
    exit 1
fi

echo "Downloading WPS Office from $appimage_url..."
wget -q --show-progress -O "$APPIMAGE" "$appimage_url"
if [ $? -ne 0 ]; then
    echo "Failed to download WPS Office AppImage."
    exit 1
fi
chmod a+x "$APPIMAGE"
echo "WPS Office downloaded and marked as executable."

# Download icon
echo "Downloading icon..."
wget -q --show-progress -O "$ICON_PATH" "$ICON_URL"

# Desktop entry
echo "Creating desktop entry..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=WPS Office
Exec=bash -c "HOME=$APP_CONFIG_DIR/home DISPLAY=:0.0 $APPIMAGE %U"
Icon=$ICON_PATH
Terminal=false
Categories=Office;WordProcessor;Spreadsheet;Presentation;
EOF
chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Restore script
RESTORE_SCRIPT="$APP_CONFIG_DIR/restore_desktop_entry.sh"
cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF
chmod +x "$RESTORE_SCRIPT"

if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_SCRIPT" 2>/dev/null; then
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_SCRIPT"
fi
chmod +x "$CUSTOM_SCRIPT"

echo ""
echo "WPS Office installation complete."
