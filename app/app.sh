#!/bin/bash

# URL of the script to download
SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/symlinks.sh"  # Replace with the actual URL of the .sh script

# Destination path to download the script
DOWNLOAD_DIR="/userdata/system/services/symlink_manager"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

# Step 1: Download the script
echo "Downloading the script from $SCRIPT_URL..."
curl -L -o "$SCRIPT_PATH" "$SCRIPT_URL"

# Check if the download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download the script. Exiting."
    exit 1
fi

# Step 2: Remove the .sh extension
SCRIPT_WITHOUT_EXTENSION="${SCRIPT_PATH%.sh}"
mv "$SCRIPT_PATH" "$SCRIPT_WITHOUT_EXTENSION"

# Step 3: Make the script executable
chmod +x "$SCRIPT_WITHOUT_EXTENSION"

# Step 4: Enable the batocera-unofficial-addons-symlinks service
echo "Enabling batocera-unofficial-addons-symlinks service..."
batocera-services enable $SCRIPT_WITHOUT_EXTENSION

# Step 5: Start the batocera-unofficial-addons-symlinks service
echo "Starting batocera-unofficial-addons-symlinks service..."
batocera-services start $SCRIPT_WITHOUT_EXTENSION

echo "Script setup completed!"

