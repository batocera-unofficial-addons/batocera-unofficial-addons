#!/bin/bash

APPNAME="Freej2me"
TEMP_DIR="/userdata/tmp/${APPNAME,,}"
ZIP_FILE="$TEMP_DIR/${APPNAME,,}.zip"
DEST_DIR="/"

# Create temporary download directory
echo "Creating temporary directory for download..."
mkdir -p "$TEMP_DIR"

# Download the file
echo "Downloading the ${APPNAME,,}.zip file..."
curl -L -o "$ZIP_FILE" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/${APPNAME}/extra/${APPNAME,,}.zip"

# Extract the file and set permissions
echo "Extracting files and adjusting permissions..."
unzip -o "$ZIP_FILE" -d "$TEMP_DIR"
chmod -R 777 "$TEMP_DIR"

# Copy extracted files to the destination directory
echo "Copying extracted files..."
cp -r "$TEMP_DIR"/* "$DEST_DIR"

# Creating symbolic links
echo "Creating symbolic links..."
create_symlink() {
    local target=$1
    local link=$2
    if [ -e "$link" ]; then
        rm -f "$link"
    fi
    ln -s "$target" "$link"
}

create_symlink "/userdata/system/add-ons/configs/bat-drl/AntiMicroX" "/opt/AntiMicroX"
create_symlink "/userdata/system/add-ons/configs/bat-drl/AntiMicroX/antimicrox" "/usr/bin/antimicrox"
create_symlink "/userdata/system/add-ons/configs/bat-drl/${APPNAME}" "/opt/${APPNAME}"
create_symlink "/userdata/system/add-ons/configs/bat-drl/python2.7" "/usr/lib/python2.7"

# Set specific permissions
echo "Setting specific permissions..."
chmod 777 /userdata/system/add-ons/configs/bat-drl/${APPNAME,,}/${APPNAME,,}.sh
chmod 777 /userdata/system/add-ons/configs/bat-drl/python2.7/site-packages/configgen/emulatorlauncher.sh
chmod 777 /userdata/system/add-ons/configs/bat-drl/AntiMicroX/antimicrox
chmod 777 /userdata/system/add-ons/configs/bat-drl/AntiMicroX/antimicrox.sh

# Remove the ZIP file and clean up the temporary directory
echo "Cleaning up temporary files..."
rm -rf "$ZIP_FILE" "$TEMP_DIR"

# Check if the Java directory already exists
if [ -d "/userdata/system/add-ons/java" ]; then
    echo "The Java directory already exists. Exiting the script."
    exit 0
fi

# Run the Java installation script
echo "Installing Java..."
curl -L "https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/java/java.sh" | bash

# Save changes
echo "Saving changes..."
batocera-save-overlay 300

echo "Installation successfully completed."
