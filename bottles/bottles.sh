#!/bin/bash

# Define app name
APPNAME="Bottles"

# Define URLs
DOWNLOAD_LINK_FILE="https://github.com/ivan-hc/Bottles-appimage/blob/main/latest-release.txt?raw=true"
ICON_URL="https://cdn2.steamgriddb.com/logo/b6971181414fe808396c6883eb262e8d.png"

# Define directories
ADDONS_DIR="/userdata/system/add-ons/${APPNAME,,}"
CONFIGS_DIR="/userdata/system/configs/${APPNAME,,}"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"

# Ensure necessary directories exist
mkdir -p "${ADDONS_DIR}/extra" "${CONFIGS_DIR}"

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
  echo "❌ ${APPNAME} is only available for x86_64 systems. Exiting."
  exit 1
fi

# Fetch the full download URL from latest-release.txt
APPIMAGE_URL=$(curl -sL "${DOWNLOAD_LINK_FILE}" | grep -i ".AppImage" | head -n1)

if [[ -z "$APPIMAGE_URL" ]]; then
  echo "❌ Failed to retrieve AppImage URL from latest-release.txt"
  exit 1
fi

# Download the AppImage
curl -L -o "${ADDONS_DIR}/${APPNAME,,}.AppImage" "${APPIMAGE_URL}"
chmod +x "${ADDONS_DIR}/${APPNAME,,}.AppImage"

# Download the icon
curl -L -o "${ADDONS_DIR}/extra/${APPNAME,,}-icon.png" "${ICON_URL}"

# Create .desktop entry
cat <<EOF > "${CONFIGS_DIR}/${APPNAME,,}.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=${ADDONS_DIR}/${APPNAME,,}.AppImage --appimage-extract-and-run
Icon=${ADDONS_DIR}/extra/${APPNAME,,}-icon.png
Terminal=false
Categories=Utility;batocera.linux;
EOF

# Copy desktop entry to applications dir
cp "${CONFIGS_DIR}/${APPNAME,,}.desktop" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
chmod +x "${CONFIGS_DIR}/${APPNAME,,}.desktop" "${DESKTOP_DIR}/${APPNAME,,}.desktop"

# Create restore script
cat <<EOF > "${CONFIGS_DIR}/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "${DESKTOP_DIR}/${APPNAME,,}.desktop" ]; then
    cp "${CONFIGS_DIR}/${APPNAME,,}.desktop" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
    chmod +x "${DESKTOP_DIR}/${APPNAME,,}.desktop"
fi
EOF
chmod +x "${CONFIGS_DIR}/restore_desktop_entry.sh"

# Add to custom.sh if not already present
if ! grep -q "${CONFIGS_DIR}/restore_desktop_entry.sh" "${CUSTOM_SCRIPT}"; then
    echo "\"${CONFIGS_DIR}/restore_desktop_entry.sh\" &" >> "${CUSTOM_SCRIPT}"
fi

echo "✅ ${APPNAME} installed! You can lauch ${APPNAME} from F1 - Applications"
sleep 5
