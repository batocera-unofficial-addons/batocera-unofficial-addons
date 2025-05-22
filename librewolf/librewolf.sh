#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://gitlab.com/api/v4/projects/24386000/releases | grep -o 'https://[^ "]*librewolf[^ "]*x86_64\.AppImage' | head -n 1)
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: aarch64 detected."
    appimage_url=$(curl -s https://gitlab.com/api/v4/projects/24386000/releases | grep -o 'https://[^ "]*librewolf[^ "]*aarch64\.AppImage' | head -n 1)
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading LibreWolf AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/librewolf/extra
wget -q --show-progress -O /userdata/system/add-ons/librewolf/LibreWolf.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download LibreWolf AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/librewolf/LibreWolf.AppImage
echo "LibreWolf AppImage downloaded and marked as executable."

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the LibreWolf Script
echo "Creating LibreWolf script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/LibreWolf.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/librewolf"

# Directories and file paths
app_dir="/userdata/system/add-ons/librewolf"
app_image="${app_dir}/LibreWolf.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/librewolf.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching LibreWolf"

# Launch LibreWolf AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./LibreWolf.AppImage "$@"
    echo "LibreWolf exited."
else
    echo "LibreWolf AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/LibreWolf.sh

APPNAME="LibreWolf"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/librewolficon.png"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

# Download icon
echo "Downloading icon..."
wget --show-progress -qO "/userdata/system/add-ons/librewolf/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=LibreWolf
Exec=/userdata/roms/ports/LibreWolf.sh
Icon=/userdata/system/add-ons/librewolf/extra/icon.png
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
echo "Downloading LibreWolf logo..."
curl -L -o /userdata/roms/ports/images/librewolf-logo.png https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/librewolf/extra/librewolf.png

# Add to gamelist.xml
echo "Adding logo to LibreWolf entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./LibreWolf.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "LibreWolf" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/librewolf-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch LibreWolf from the Ports menu."
