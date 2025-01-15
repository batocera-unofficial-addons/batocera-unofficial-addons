#!/bin/bash

# URL of the script to download
SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # URL for symlink_manager.sh
BATOCERA_ADDONS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/BatoceraUnofficialAddOns.sh"  # URL for batocera-unofficial-addons.sh
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/keys.txt"  # URL for keys.txt
XMLSTARLET_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/xmlstarlet"  # URL for xmlstarlet

# Destination path to download the script
DOWNLOAD_DIR="/userdata/system/services/"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Destination path for batocera-unofficial-addons.sh and keys.txt
ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/BatoceraUnofficialAddOns.sh"
KEYS_FILE="$ROM_PORTS_DIR/keys.txt"

mkdir -p "$DOWNLOAD_DIR"

# Step 1: Download the symlink manager script
echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -L -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -L https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/app/dep.sh | bash

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
curl -L -o "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download batocera-unofficial-addons.sh. Exiting."
    exit 1
fi

# Step 7: Make batocera-unofficial-addons.sh executable
chmod +x "$BATOCERA_ADDONS_PATH"

# Step 8: Download keys.txt
echo "Downloading keys.txt..."
curl -L -o "$KEYS_FILE" "$KEYS_URL"

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
curl -L -o "/userdata/system/add-ons/.dep/xmlstarlet" "$XMLSTARLET_URL"

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
# Step 10: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Ensure the gamelist.xml exists
if [ ! -f "/userdata/roms/ports/gamelist.xml" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "/userdata/roms/ports/gamelist.xml"
fi

# Download the image
echo "Downloading Batocera Unofficial Add-ons logo..."
curl -L -o /userdata/roms/ports/images/BatoceraUnofficialAddons.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons.png
echo "Adding logo to Batocera Unofficial Add-ons entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./BatoceraUnofficialAddOns.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Batocera Unofficial Add-Ons Installer" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/BatoceraUnofficialAddons.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Batocera Unofficial Add-Ons from the Ports menu."
