#!/bin/bash

# Define application name
APPNAME="Bridge"

# GitHub API endpoint
REPO_API_URL="https://api.github.com/repos/Geomitron/Bridge/releases/latest"
ICON_URL="https://avatars.githubusercontent.com/u/22552797?v=4"

# Directories
ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APPNAME,,}"
PERSISTENT_DESKTOP="${APP_CONFIG_DIR}/${APPNAME,,}.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${APPNAME,,}.desktop"
EXTRA_DIR="${ADDONS_DIR}/${APPNAME,,}/extra"

# Ensure required directories exist
mkdir -p "$APP_CONFIG_DIR" "$EXTRA_DIR"

# Detect system architecture
arch=$(uname -m)
case "$arch" in
    x86_64)
        SUFFIX="AppImage"
        ;;
    aarch64)
        dialog --title "$APPNAME" --msgbox "No ARM64 AppImage available for ${APPNAME}. Exiting." 8 60
        exit 1
        ;;
    *)
        dialog --title "$APPNAME" --msgbox "Unsupported architecture: $arch. Exiting." 8 60
        exit 1
        ;;
esac

# Get the latest AppImage download URL
APPIMAGE_URL=$(curl -s "$REPO_API_URL" | grep "browser_download_url" | grep -i "$SUFFIX" | cut -d '"' -f 4 | head -n 1)

# Validate the download URL
if [[ -z "$APPIMAGE_URL" ]]; then
    dialog --title "$APPNAME" --msgbox "Could not find a valid AppImage URL for ${APPNAME}." 8 60
    exit 1
fi

# Download the AppImage
if ! wget -q --show-progress -O "$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage" "$APPIMAGE_URL"; then
    dialog --title "$APPNAME" --msgbox "Failed to download ${APPNAME} AppImage. Exiting." 8 60
    exit 1
fi
chmod a+x "$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage"

# Download icon
if ! wget -q --show-progress -O "$EXTRA_DIR/${APPNAME,,}-icon.png" "$ICON_URL"; then
    echo "⚠️ Could not download icon for ${APPNAME}. Using default icon."
fi

# Create persistent desktop entry with --no-sandbox flag
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=$APPNAME
Exec=$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage --no-sandbox
Icon=$EXTRA_DIR/${APPNAME,,}-icon.png
Terminal=false
Categories=Game;batocera.linux;
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

# Register the restore script in custom.sh, which Batocera runs at boot
# (on Batocera 43 and later through BUA's custom_service_handler service).
# /usr/share/applications is not persistent, so the entry is copied back each boot.
[ -f "$CUSTOM_SCRIPT" ] || echo "#!/bin/bash" > "$CUSTOM_SCRIPT"
if ! grep -qF "${APP_CONFIG_DIR}/restore_desktop_entry.sh" "$CUSTOM_SCRIPT"; then
    echo "\"${APP_CONFIG_DIR}/restore_desktop_entry.sh\" &" >> "$CUSTOM_SCRIPT"
fi
chmod a+x "$CUSTOM_SCRIPT"

echo "✅ ${APPNAME} setup complete with --no-sandbox."
