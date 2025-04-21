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
        echo "No ARM64 AppImage available for ${APPNAME}. Exiting."
        exit 1
        ;;
    *)
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
        ;;
esac

# Get the latest AppImage download URL
APPIMAGE_URL=$(curl -s "$REPO_API_URL" | grep "browser_download_url" | grep -i "$SUFFIX" | cut -d '"' -f 4 | head -n 1)

# Validate the download URL
if [[ -z "$APPIMAGE_URL" ]]; then
    echo "❌ Could not find a valid AppImage URL for ${APPNAME}."
    exit 1
fi

# Download the AppImage
if ! wget -q --show-progress -O "$ADDONS_DIR/${APPNAME,,}/${APPNAME,,}.AppImage" "$APPIMAGE_URL"; then
    echo "❌ Failed to download ${APPNAME} AppImage. Exiting."
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

# Register restore script in custom.sh if not already present
if ! grep -q "${APP_CONFIG_DIR}/restore_desktop_entry.sh" "$CUSTOM_SCRIPT"; then
    echo "\"${APP_CONFIG_DIR}/restore_desktop_entry.sh\" &" >> "$CUSTOM_SCRIPT"
fi

echo "✅ ${APPNAME} setup complete with --no-sandbox."
