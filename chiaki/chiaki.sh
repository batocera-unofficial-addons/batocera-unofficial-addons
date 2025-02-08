#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/streetpea/chiaki-ng/releases/download/v1.9.3/chiaki-ng.AppImage_x86_64"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: ARM64 detected."
    appimage_url="https://github.com/streetpea/chiaki-ng/releases/download/v1.9.3/chiaki-ng.AppImage_arm64"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi


# Step 2: Prepare directories
echo "Setting up directories..."
mkdir -p /userdata/system/add-ons/chiaki
mkdir -p /userdata/system/add-ons/chiaki/extra
mkdir -p /userdata/system/logs
mkdir -p /userdata/roms/ports/images
mkdir -p /userdata/system/configs/chiaki
DESKTOP_FILE="/usr/share/applications/chiaki.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/chiaki/chiaki.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/chiaki/extra/icon.png"
INSTALL_DIR="/userdata/system/add-ons/chiaki"
# Step 3: Download the AppImage
echo "Downloading Chiaki AppImage..."
wget -q --show-progress -O /userdata/system/add-ons/chiaki/Chiaki.AppImage "$appimage_url"
if [ $? -ne 0 ]; then
    echo "Failed to download Chiaki AppImage. Exiting."
    exit 1
fi

chmod a+x /userdata/system/add-ons/chiaki/Chiaki.AppImage
echo "Chiaki AppImage downloaded and marked as executable."

echo "Downloading icon..."
wget --show-progress -qO "${INSTALL_DIR}/extra/icon.png" "$ICON_URL"

# Step 4: Create the Chiaki launch script
echo "Creating Chiaki launch script in Ports..."
cat << 'EOF' > /userdata/roms/ports/Chiaki.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/chiaki"
app_image="${app_dir}/Chiaki.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/chiaki.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Chiaki"

# Launch Chiaki AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Chiaki.AppImage > "${log_file}" 2>&1
    echo
fi
EOF

chmod +x /userdata/roms/ports/Chiaki.sh

# Create persistent desktop entry
echo "Creating persistent desktop entry for Chiaki..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Chiaki-NG
Exec=/userdata/roms/ports/Chiaki.sh
Icon=/userdata/system/add-ons/chiaki/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring Chiaki desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/chiaki/restore_desktop_entry.sh"
#!/bin/bash
# Restore Chiaki desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring Chiaki desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "Chiaki desktop entry restored."
else
    echo "Chiaki desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/chiaki/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/chiaki/restore_desktop_entry.sh" "$custom_startup"; then
    echo "Adding Chiaki restore script to startup..."
    echo "bash "/userdata/system/configs/chiaki/restore_desktop_entry.sh" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

# Step 5: Add Chiaki to Ports menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

echo "Adding Chiaki to Ports menu..."
curl -L -o /userdata/roms/ports/images/chiakilogo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/chiaki/extra/chiakilogo.png
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Chiaki.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Chiaki" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/chiakilogo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

# Step 6: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Chiaki from the Ports menu."
