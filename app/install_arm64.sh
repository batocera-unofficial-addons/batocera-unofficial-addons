#!/bin/bash
set -euo pipefail

# URL of the script to download
SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # URL for symlink_manager.sh
BATOCERA_ADDONS_URL="https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/app/BatoceraUnofficialAddons_ARM64.sh"  # URL for batocera-unofficial-addons.sh
BATOCERA_ADDONS_LOGO_URL=https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/extra/batocera-unofficial-addons.png
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/keys.txt"  # URL for keys.txt
XMLSTARLET_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/xmlstarlet-arm64"  # URL for xmlstarlet
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
curl -fLs -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ ! -s "$SCRIPT_PATH" ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -fLs https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/app/dep_arm64.sh | bash

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
curl -fLs -o "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

if [ ! -s "$BATOCERA_ADDONS_PATH" ]; then
    echo "Failed to download batocera-unofficial-addons.sh. Exiting."
    exit 1
fi

# Step 7: Make batocera-unofficial-addons.sh executable
chmod +x "$BATOCERA_ADDONS_PATH"

# Step 8.1: Download keys.txt
echo "Downloading keys.txt..."
curl -fLs -o "$KEYS_FILE" "$KEYS_URL"

if [ ! -s "$KEYS_FILE" ]; then
    echo "Failed to download keys.txt. Exiting."
    exit 1
fi

# Step 8.2: Download .dialogrc
curl -fLs -o "$DIO_FILE" "$DIO_URL"
if [ ! -s "$DIO_FILE" ]; then
    echo "Failed to download .dialogrc. Exiting."
    exit 1
fi

# Step 9: Rename keys.txt to match the .sh file name with .sh.keys extension
RENAME_KEY_FILE="${BATOCERA_ADDONS_PATH}.keys"
echo "Renaming $KEYS_FILE to $RENAME_KEY_FILE..."
mv "$KEYS_FILE" "$RENAME_KEY_FILE"

# Step: Download xmlstarlet
echo "Downloading xmlstarlet..."
curl -fLs -o "/userdata/system/add-ons/.dep/xmlstarlet" "$XMLSTARLET_URL"

# Check if download was successful
if [ ! -s /userdata/system/add-ons/.dep/xmlstarlet ]; then
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
BATOCERA_ADDONS_LOGO_DEST="/userdata/roms/ports/images/BatoceraUnofficialAddons.png"
curl -fLs -o "$BATOCERA_ADDONS_LOGO_DEST" "$BATOCERA_ADDONS_LOGO_URL"
if [ ! -s /userdata/roms/ports/images/BatoceraUnofficialAddons.png ]; then
    echo "Failed to download logo. Exiting."
    exit 1
fi

echo "Adding logo to Batocera Unofficial Add-ons entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./bua.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Batocera Unofficial Add-Ons Installer" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/BatoceraUnofficialAddons.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

# Add to startup script
custom_startup="/userdata/system/custom.sh"

# Create file if it doesn't exist
if [ ! -f "$custom_startup" ]; then
    touch "$custom_startup"
fi

# Append modprobe line if not already present
if ! grep -q "modprobe fuse" "$custom_startup"; then
    echo "Adding FUSE to startup..."
    echo "modprobe fuse &" >> "$custom_startup"
fi

# Ensure it's executable
chmod +x "$custom_startup"

modprobe fuse

echo
echo "Installation complete! You can now launch Batocera Unofficial Add-Ons from the Ports menu."
