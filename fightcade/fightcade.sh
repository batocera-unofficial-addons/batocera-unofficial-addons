#!/bin/bash

# Define directories and URLs
DOWNLOAD_DIR="/userdata/system/add-ons/fightcade"
FIGHTCADE_URL="https://www.fightcade.com/download/linux"
LIBS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/lib/libs.zip"

# Create necessary directories if they don't exist
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$DOWNLOAD_DIR/lib"

# Step 1: Download Fightcade tar.gz
echo "Downloading Fightcade from $FIGHTCADE_URL..."
curl -L "$FIGHTCADE_URL" -o "$DOWNLOAD_DIR/fightcade-linux.tar.gz"

# Check if the download was successful
if [[ $? -eq 0 ]]; then
    echo "Fightcade downloaded successfully."
else
    echo "Error downloading Fightcade. Exiting."
    exit 1
fi

# Step 2: Unpack Fightcade tar.gz into the directory
echo "Unpacking Fightcade into $DOWNLOAD_DIR..."
tar -xvzf "$DOWNLOAD_DIR/fightcade-linux.tar.gz" -C "$DOWNLOAD_DIR"

# Check if unpacking was successful
if [[ $? -eq 0 ]]; then
    echo "Fightcade unpacked successfully."
else
    echo "Error unpacking Fightcade. Exiting."
    exit 1
fi

# Step 3: Delete the tar.gz file
echo "Deleting Fightcade tar.gz file..."
rm "$DOWNLOAD_DIR/fightcade-linux.tar.gz"

# Check if the deletion was successful
if [[ $? -eq 0 ]]; then
    echo "Fightcade tar.gz file deleted successfully."
else
    echo "Error deleting Fightcade tar.gz file."
fi

# Step 4: Download dependencies
echo "Downloading dependencies from $LIBS_URL..."
curl -L "$LIBS_URL" -o "$DOWNLOAD_DIR/libs.zip"

# Check if the download was successful
if [[ $? -eq 0 ]]; then
    echo "Dependencies downloaded successfully."
else
    echo "Error downloading dependencies. Exiting."
    exit 1
fi

# Step 5: Unzip dependencies into the lib directory
echo "Unzipping dependencies into $DOWNLOAD_DIR/lib..."
unzip -o "$DOWNLOAD_DIR/libs.zip" -d "$DOWNLOAD_DIR/lib"

# Check if unzipping was successful
if [[ $? -eq 0 ]]; then
    echo "Dependencies unzipped successfully."
else
    echo "Error unzipping dependencies. Exiting."
    exit 1
fi

# Step 6: Delete the libs.zip file
echo "Deleting libs.zip file..."
rm "$DOWNLOAD_DIR/libs.zip"

# Check if the deletion was successful
if [[ $? -eq 0 ]]; then
    echo "libs.zip file deleted successfully."
else
    echo "Error deleting libs.zip file."
fi

# Installation complete
echo "Fightcade installation completed successfully!"

