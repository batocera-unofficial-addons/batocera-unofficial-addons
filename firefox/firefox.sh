#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://api.github.com/repos/srevinsaju/Firefox-Appimage/releases/latest | jq -r ".assets[] | select(.name | endswith(\"x86_64.AppImage\")) | .browser_download_url")
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Firefox AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/firefox/extra
wget -q --show-progress -O /userdata/system/add-ons/firefox/Firefox.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Firefox AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/firefox/Firefox.AppImage
echo "Firefox AppImage downloaded and marked as executable."

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the Firefox Script
echo "Creating Firefox script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Firefox.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/firefox"

# Directories and file paths
app_dir="/userdata/system/add-ons/firefox"
app_image="${app_dir}/Firefox.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/firefox.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Firefox"

# Launch Firefox AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Firefox.AppImage --no-sandbox --test-type "$@" > "${log_file}" 2>&1
    echo "Firefox exited."
else
    echo "Firefox.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Firefox.sh

APPNAME="Firefox"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/icon.png"

mkdir -p "/userdata/system/configs/${APPNAME,,}"
mkdir -p "/userdata/system/add-ons/${APPNAME,,}/extra"

echo "Downloading icon..."
wget --show-progress -qO "/userdata/system/add-ons/${APPNAME,,}/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=/userdata/roms/ports/${APPNAME}.sh
Icon=/userdata/system/add-ons/${APPNAME,,}/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring ${APPNAME} desktop entry is restored at startup..."
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
# Restore ${APPNAME} desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring ${APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "${APPNAME} desktop entry restored."
else
    echo "${APPNAME} desktop entry already exists."
fi
EOF

chmod +x "$RESTORE_SCRIPT"

# Add to startup script
CUSTOM_STARTUP="/userdata/system/custom.sh"

if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Firefox logo..."
curl -L -o /userdata/roms/ports/images/firefox-logo.png https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/firefox/extra/firefox-logo.png
echo "Adding logo to Firefox entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Firefox.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Firefox" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/firefox-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Firefox from the Ports menu."
