#!/bin/bash

# URL of the script to download
SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # URL for symlink_manager.sh
BATOCERA_ADDONS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/BatoceraUnofficialAddOns.sh"  # URL for batocera-unofficial-addons.sh
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/keys.txt"  # URL for keys.txt

# Destination path to download the script
DOWNLOAD_DIR="/userdata/system/services/"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Destination path for batocera-unofficial-addons.sh and keys.txt
ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/BatoceraUnofficialAddOns.sh"
KEYS_FILE="$ROM_PORTS_DIR/keys.txt"

# Step 1: Download the symlink manager script
echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -L -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Step 2: Remove the .sh extension
SCRIPT_WITHOUT_EXTENSION="${SCRIPT_PATH%.sh}"
mv "$SCRIPT_PATH" "$SCRIPT_WITHOUT_EXTENSION"

# Step 3: Make the symlink manager script executable
chmod +x "$SCRIPT_WITHOUT_EXTENSION"

# Step 4: Enable the batocera-unofficial-addons-symlinks service
echo "Enabling batocera-unofficial-addons-symlinks service..."
batocera-services enable $SCRIPT_WITHOUT_EXTENSION

# Step 5: Start the batocera-unofficial-addons-symlinks service
echo "Starting batocera-unofficial-addons-symlinks service..."
batocera-services start $SCRIPT_WITHOUT_EXTENSION

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

echo "Script setup completed!"
