#!/bin/bash

# Define URLs for split files
URL_PART1="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/v40wine/ge-customv40.tar.xz.0011"
URL_PART2="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/v40wine/ge-customv40.tar.xz.002"

# Define the download directory and target extraction path
DOWNLOAD_DIR="/tmp/ge-custom-download"
EXTRACT_DIR="/userdata/system/wine/custom"

# Create the directories
mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$EXTRACT_DIR"

# Download the split files
echo "Downloading split files..."
curl -o "$DOWNLOAD_DIR/ge-customv40.tar.xz.001" "$URL_PART1"
curl -o "$DOWNLOAD_DIR/ge-customv40.tar.xz.002" "$URL_PART2"

# Combine the files into a single archive
cd "$DOWNLOAD_DIR"
echo "Combining files..."
cat ge-customv40.tar.xz.001 ge-customv40.tar.xz.002 > ge-customv40.tar.xz

# Verify the combined file exists
if [[ ! -f "ge-customv40.tar.xz" ]]; then
    echo "Error: Failed to combine files."
    exit 1
fi

# Decompress the .xz file
echo "Decompressing the .xz file..."
xz -d ge-customv40.tar.xz

# Verify the decompressed file exists
if [[ ! -f "ge-customv40.tar" ]]; then
    echo "Error: Decompression failed."
    exit 1
fi

# Extract the .tar archive
echo "Extracting the archive..."
tar -xf ge-customv40.tar -C "$EXTRACT_DIR"

# Check if extraction was successful
if [[ $? -eq 0 ]]; then
    echo "Extraction complete! Files are in $EXTRACT_DIR."
else
    echo "Error: Extraction failed."
    exit 1
fi

# Clean up temporary files
echo "Cleaning up..."
rm -rf "$DOWNLOAD_DIR"

# Done
echo "Done!"
