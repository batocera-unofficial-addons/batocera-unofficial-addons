#!/bin/bash

# Define variables
URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/gamescope/extra/gamescope.tar"
DEST_DIR="/userdata/system/add-ons"
ARCHIVE_NAME="gamescope.tar"

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Change to the destination directory
cd "$DEST_DIR" || { echo "❌ Failed to navigate to $DEST_DIR"; exit 1; }

# Download the tar file
echo "📥 Downloading $ARCHIVE_NAME..."
wget -O "$ARCHIVE_NAME" "$URL" || { echo "❌ Failed to download $ARCHIVE_NAME"; exit 1; }

# Extract the archive (it already contains a 'gamescope/' folder)
echo "📂 Extracting $ARCHIVE_NAME..."
tar -xf "$ARCHIVE_NAME" || { echo "❌ Failed to extract $ARCHIVE_NAME"; exit 1; }

# Verify extraction and remove the tar file
if [ -d "$DEST_DIR/gamescope" ]; then
    echo "🗑️ Removing $ARCHIVE_NAME..."
    rm -f "$ARCHIVE_NAME"
else
    echo "⚠️ Extraction failed or folder missing, tar file not removed."
fi
echo "Making Gamescope executable"
chmod +x -R /userdata/system/add-ons/gamescope

echo "✅ Gamescope installed successfully in $DEST_DIR/gamescope!"

