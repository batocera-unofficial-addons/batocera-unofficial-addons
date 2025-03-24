#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/Vencord/Vesktop/releases/download/v1.5.4/Vesktop-1.5.4.AppImage"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    appimage_url="https://github.com/Vencord/Vesktop/releases/download/v1.5.4/Vesktop-1.5.4-arm64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Vesktop AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/vesktop
wget -q --show-progress -O /userdata/system/add-ons/vesktop/Vesktop.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Vesktop AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/vesktop/Vesktop.AppImage
echo "Vesktop AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/logs
mkdir -p /userdata/system/configs/vesktop
mkdir -p /userdata/system/add-ons/vesktop/extra
DESKTOP_FILE="/usr/share/applications/Vesktop.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/vesktop/Vesktop.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/vesktop/extra/icon.png"
INSTALL_DIR="/userdata/system/add-ons/vesktop"

# Step 3: Create the Vesktop Launcher Script
echo "Creating Vesktop launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Vesktop.sh
#!/bin/bash
export HOME=/userdata/system/add-ons/vesktop

# Function to ensure the quickCss.css file exists
ensure_quick_css() {
    config_settings_dir="${HOME}/.config/vesktop/settings"
    quickCss="${config_settings_dir}/quickCss.css"

    # Ensure the .config/vesktop/settings directory exists
    mkdir -p "$config_settings_dir"

    # Ensure quickCss.css exists (you can create an empty file or add some default content)
    if [ ! -f "$quickCss" ]; then
        echo "/* Default CSS for Vesktop */" > "$quickCss"
        echo "$(date): Created default quickCss.css."
    fi
}

# Call functions
ensure_quick_css

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0

# Directories and file paths
app_dir="/userdata/system/add-ons/vesktop"
app_image="${app_dir}/Vesktop.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/vesktop.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Vesktop"

# Launch Vesktop AppImage
if [ -x "$app_image" ]; then
    echo "$(date): AppImage is executable, launching..."
    cd "$app_dir"
    ./Vesktop.AppImage --no-sandbox --trace-warnings > "$log_file" 2>&1
    echo "$(date): Vesktop exited."
else
    echo "$(date): Vesktop.AppImage not found or not executable."
    exit 1
fi

EOF

chmod +x /userdata/roms/ports/Vesktop.sh

echo "Downloading icon..."
wget --show-progress -qO "${INSTALL_DIR}/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for Vesktop..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Vesktop
Exec=/userdata/roms/ports/Vesktop.sh
Icon=/userdata/system/add-ons/vesktop/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring Vesktop desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/vesktop/restore_desktop_entry.sh"
#!/bin/bash
# Restore Vesktop desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring Vesktop desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "Vesktop desktop entry restored."
else
    echo "Vesktop desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/vesktop/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/vesktop/restore_desktop_entry.sh" "$custom_startup"; then
    echo "Adding Vesktop restore script to startup..."
    echo "bash "/userdata/system/configs/vesktop/restore_desktop_entry.sh" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

KEYS_URL="https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/netflix/extra/Netflix.sh.keys"
# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "/userdata/roms/ports/Vesktop.sh.keys" "$KEYS_URL"
# Download the image
echo "Downloading Vesktop logo..."
curl -L -o /userdata/roms/ports/images/vesktoplogo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/vesktop/extra/vesktoplogo.png

echo "Adding logo to Vesktop entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Vesktop.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Vesktop" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/vesktoplogo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Vesktop from the Ports menu."

