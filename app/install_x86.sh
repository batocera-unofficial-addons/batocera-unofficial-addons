#!/bin/bash

# URL of the script to download
SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # URL for symlink_manager.sh
BATOCERA_ADDONS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/BatoceraUnofficialAddOns.sh"  # URL for batocera-unofficial-addons.sh
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/keys.txt"  # URL for keys.txt
XMLSTARLET_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/xmlstarlet"  # URL for xmlstarlet
DIO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/.dialogrc"

# Destination path to download the script
DOWNLOAD_DIR="/userdata/system/services/"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Destination path for batocera-unofficial-addons.sh and keys.txt
ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/bua.sh"
KEYS_FILE="$ROM_PORTS_DIR/keys.txt"
DIO_FILE="/userdata/system/add-ons/.dialogrc"

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "/userdata/system/add-ons"

# Step 1: Download the symlink manager script
echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -Ls -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -Ls https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/app/dep.sh | bash

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
echo "Downloading Batocera Unofficial Add-Ons Launcher..."
curl -Ls -o "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download batocera-unofficial-addons.sh. Exiting."
    exit 1
fi

# Step 7: Make batocera-unofficial-addons.sh executable
chmod +x "$BATOCERA_ADDONS_PATH"

# Step 8: Download keys.txt
echo "Downloading keys.txt..."
curl -Ls -o "$KEYS_FILE" "$KEYS_URL"
curl -Ls -o "$DIO_FILE" "$DIO_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download keys.txt. Exiting."
    exit 1
fi

# Step 9: Rename keys.txt to match the .sh file name with .sh.keys extension
RENAME_KEY_FILE="${BATOCERA_ADDONS_PATH}.keys"
echo "Renaming $KEYS_FILE to $RENAME_KEY_FILE..."
mv "$KEYS_FILE" "$RENAME_KEY_FILE"

# Step: Download xmlstarlet
echo "Downloading xmlstarlet..."
curl -Ls -o "/userdata/system/add-ons/.dep/xmlstarlet" "$XMLSTARLET_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download xmlstarlet. Exiting."
    exit 1
fi

# Make xmlstarlet executable
chmod +x /userdata/system/add-ons/.dep/xmlstarlet

# Step: Symlink xmlstarlet to /usr/bin
echo "Creating symlink for xmlstarlet in /usr/bin..."
ln -sf /userdata/system/add-ons/.dep/xmlstarlet /usr/bin/xmlstarlet

echo "xmlstarlet has been installed and symlinked to /usr/bin."
mkdir -p "/userdata/roms/ports/images"

#!/bin/bash

APPNAME="BUA"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/extra/icon.png"

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

# Download the image
echo "Downloading Batocera Unofficial Add-ons logo..."
curl -Ls -o /userdata/roms/ports/images/BatoceraUnofficialAddons.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons.png
curl -Ls -o /userdata/roms/ports/images/BatoceraUnofficialAddons_Wheel.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons-wheel.png
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
