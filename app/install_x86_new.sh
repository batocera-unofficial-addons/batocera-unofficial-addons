#!/bin/bash
set -euo pipefail

# URL of the script to download
SCRIPT_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # URL for symlink_manager.sh
BATOCERA_ADDONS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/BUA.sh"  # URL for batocera-unofficial-addons.sh
BATOCERA_ADDONS_LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons.png"
BATOCERA_ADDONS_WHEEL_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons-wheel.png"
XMLSTARLET_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/app/xmlstarlet"  # URL for xmlstarlet

# Destination path to download the script
DOWNLOAD_DIR="/userdata/system/services/"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Destination path for batocera-unofficial-addons.sh and keys.txt
ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/bua.sh"

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "/userdata/system/add-ons"

# Step 1: Download the symlink manager script
echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -fLs -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ ! -s "$SCRIPT_PATH" ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -fLs https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/dep.sh | bash

# Step 2: Remove the .sh extension
SCRIPT_WITHOUT_EXTENSION="${SCRIPT_PATH%.sh}"
mv "$SCRIPT_PATH" "$SCRIPT_WITHOUT_EXTENSION"

# Step 3: Make the symlink manager script executable
chmod +x "$SCRIPT_WITHOUT_EXTENSION"

# Step 4: Enable the batocera-unofficial-addons-symlinks service
echo "Enabling batocera-unofficial-addons-symlinks service..."
batocera-services enable symlink_manager

# Step 5: Start the batocera-unofficial-addons-symlinks service
echo "Starting batocera-unofficial-addons-symlinks service..."
batocera-services start symlink_manager &>/dev/null &

# Step 6: Download batocera-unofficial-addons.sh
echo "Downloading Batocera Unofficial Add-Ons Launcher from $BATOCERA_ADDONS_URL..."
curl -fLs -o "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

# Check if the download was successful
if [ ! -s "$BATOCERA_ADDONS_PATH" ]; then
    echo "Failed to download batocera-unofficial-addons.sh. Exiting."
    exit 1
fi

# Step 7: Make batocera-unofficial-addons.sh executable
chmod +x "$BATOCERA_ADDONS_PATH"

# Step 11: Download xmlstarlet
XMLSTARLET_DEST="/userdata/system/add-ons/.dep/xmlstarlet"
echo "Downloading xmlstarlet..."
curl -fLs -o "$XMLSTARLET_DEST" "$XMLSTARLET_URL"

# Check if download was successful
if [ ! -s "$XMLSTARLET_DEST" ]; then
    echo "Failed to download xmlstarlet. Exiting."
    exit 1
fi

# Make xmlstarlet executable
chmod +x "$XMLSTARLET_DEST"

# Step: Symlink xmlstarlet to /usr/bin
echo "Creating symlink for xmlstarlet in /usr/bin..."
ln -sf "$XMLSTARLET_DEST" /usr/bin/xmlstarlet

echo "xmlstarlet has been installed and symlinked to /usr/bin."
mkdir -p "/userdata/roms/ports/images"

APPNAME="BUA"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/extra/icon.png"

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
Name=Batocera Unofficial Add Ons
Exec=/userdata/roms/ports/bua.sh
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

# Step 10: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Ensure the gamelist.xml exists
if [ ! -f "/userdata/roms/ports/gamelist.xml" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "/userdata/roms/ports/gamelist.xml"
fi

# Download the logo image
echo "Downloading Batocera Unofficial Add-ons logo..."
BATOCERA_ADDONS_LOGO_DEST="/userdata/roms/ports/images/BatoceraUnofficialAddons.png"
curl -fLs -o "$BATOCERA_ADDONS_LOGO_DEST" "$BATOCERA_ADDONS_LOGO_URL"

# Check if download was successful
if [ ! -s "$BATOCERA_ADDONS_LOGO_DEST" ]; then
    echo "Failed to download logo. Exiting."
    exit 1
fi

# Download the wheel image
echo "Downloading Batocera Unofficial Add-ons wheel image from $BATOCERA_ADDONS_WHEEL_URL..."
BATOCERA_ADDONS_WHEEL_DEST="/userdata/roms/ports/images/BatoceraUnofficialAddons_Wheel.png"
curl -fLs -o "$BATOCERA_ADDONS_WHEEL_DEST" "$BATOCERA_ADDONS_WHEEL_URL"

# Check if download was successful
if [ ! -s "$BATOCERA_ADDONS_WHEEL_DEST" ]; then
    echo "Failed to download wheel image. Exiting."
    exit 1
fi

echo "Adding logo to Batocera Unofficial Add-ons entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./bua.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Batocera Unofficial Add-Ons Installer" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/BatoceraUnofficialAddons.png" \
  -s "/gameList/game[last()]" -t elem -n "marquee" -v "./images/BatoceraUnofficialAddons_Wheel.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Batocera Unofficial Add-Ons from the Ports menu."
