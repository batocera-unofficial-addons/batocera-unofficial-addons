#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    app_url="https://github.com/unknownskl/greenlight/releases/download/v2.3.3/Greenlight-2.3.3.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the application
echo "Downloading Greenlight from $app_url..."
app_dir="/userdata/system/add-ons/greenlight"
mkdir -p "$app_dir"
temp_dir="${app_dir}/temp"
mkdir -p "$temp_dir"

wget -q --show-progress -O "${temp_dir}/greenlight.AppImage" "$app_url"
if [ $? -ne 0 ]; then
    echo "Failed to download Greenlight. Exiting."
    exit 1
fi
mv "${temp_dir}/greenlight.AppImage" "$app_dir/"
chmod a+x "${app_dir}/greenlight.AppImage"
rm -rf "$temp_dir"
echo "Greenlight installed successfully."

# Step 4: Create launcher script
echo "Creating Greenlight script in Ports..."
ports_dir="/userdata/roms/ports"
mkdir -p "$ports_dir"
cat << 'EOF' > "${ports_dir}/Greenlight.sh"
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/greenlight"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=XFCE
export LD_LIBRARY_PATH="/userdata/system/add-ons/.dep:${LD_LIBRARY_PATH}"

# Configure system settings
sysctl -w vm.max_map_count=2097152
ulimit -H -n 819200
ulimit -S -n 819200
ulimit -H -l 61634
ulimit -S -l 61634
ulimit -H -s 61634
ulimit -S -s 61634

# Paths
app_bin="/userdata/system/add-ons/greenlight"
log_dir="/userdata/system/logs"
log_file="${log_dir}/greenlight.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Greenlight"

# Launch Greenlight
if [ -x "${app_bin}" ]; then
    cd "/userdata/system/add-ons/greenlight"
    ./greenlight.AppImage --no-sandbox > "${log_file}" 2>&1
    echo "Greenlight exited."
else
    echo "Greenlight not found or not executable."
    exit 1
fi
EOF

chmod +x "${ports_dir}/Greenlight.sh"

APPNAME="Greenlight"
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

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Greenlight logo..."
curl -L -o /userdata/roms/ports/images/greenlight.png https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/greenlight/extra/greenlight.png
echo "Adding logo to Greenlight entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Greenlight.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Greenlight" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/greenlight.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
  
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Greenlight from the Ports menu."
