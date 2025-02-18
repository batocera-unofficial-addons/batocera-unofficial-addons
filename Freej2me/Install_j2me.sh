#!/bin/bash

# Welcome message
echo "Welcome to the automatic installer for the J2ME game emulator by DRL Edition."

# Temporary directory for download
TEMP_DIR="/userdata/tmp/freej2me"
DRL_FILE="$TEMP_DIR/freej2me.zip"
DEST_DIR="/"

# Create the temporary directory
echo "Creating temporary directory for download..."
mkdir -p $TEMP_DIR

# Download the drl file
echo "Downloading the freej2me.drl file..."
curl -L -o $DRL_FILE "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/Freej2me/extra/freej2me.zip"

# Extract the drl file with a progress bar and change permissions for each extracted file
echo "Extracting the drl file and setting permissions for each file..."
unzip -o $DRL_FILE -d $TEMP_DIR | while IFS= read -r file; do
    if [ -f "$TEMP_DIR/$file" ]; then
        chmod 777 "$TEMP_DIR/$file"
    fi
done

# Copy the extracted files to the root directory, replacing existing ones
echo "Copying extracted files to the root directory..."
cp -r $TEMP_DIR/* $DEST_DIR

# Create symbolic links
echo "Creating symbolic links..."

# Function to create a symbolic link and replace it if it already exists
# Function to create a symbolic link and remove the target if it already exists
create_symlink() {
    local target="$1"
    local link="$2"

    # Remove existing file or directory
    if [ -e "$link" ] || [ -L "$link" ]; then
        echo "Removing existing link or file: $link"
        rm -rf "$link"
    fi

    # Create the new symbolic link
    ln -s "$target" "$link"
    echo "Created symlink: $link → $target"
}

create_symlink "/userdata/system/configs/bat-drl/AntiMicroX" "/opt/AntiMicroX"
create_symlink "/userdata/system/configs/bat-drl/AntiMicroX/antimicrox" "/usr/bin/antimicrox"
create_symlink "/userdata/system/configs/bat-drl/Freej2me" "/opt/Freej2me"
create_symlink "/userdata/system/configs/bat-drl/python2.7" "/usr/lib/python2.7"

# Set permissions for specific files
echo "Setting permissions for specific files..."
chmod 777 /media/SHARE/system/configs/bat-drl/Freej2me/freej2me.sh
chmod 777 /media/SHARE/system/configs/bat-drl/python2.7/site-packages/configgen/emulatorlauncher.sh
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox
chmod 777 /userdata/system/configs/bat-drl/AntiMicroX/antimicrox.sh

# Delete the freej2me.zip file from the root directory
echo "Deleting the freej2me.zip file from the root directory..."
rm -rf $TEMP_DIR/freej2me.zip
rm -rf /freej2me.zip

# Rename es_system_j2me.cfg to es_systems_j2me.cfg
mv /userdata/system/configs/emulationstation/es_system_j2me.cfg /userdata/system/configs/emulationstation/es_systems_j2me.cfg

# Clean up the temporary directory
echo "Cleaning up temporary directory..."
rm -rf $TEMP_DIR

# Check if the /userdata/system/add-ons/java directory exists
if [ -d "/userdata/system/add-ons/java" ]; then
    echo "The directory /userdata/system/add-ons/java already exists. Exiting script."
    exit 0
fi

# Execute the java.sh script if the /userdata/system/pro/java directory does not exist
echo "Executing the java.sh script..."
curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/java/java.sh | bash

echo "Setting permissions for specific files..."
create_symlink "/userdata/system/add-ons/java/bin/java" "/usr/bin/java"

# Save changes
echo "Saving changes..."
batocera-save-overlay 300

echo "Installation completed successfully."
killall -9 emulationstation
