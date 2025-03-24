#!/bin/bash

# Create the target directory
mkdir -p /userdata/system/add-ons/zenity/.tmp 2>/dev/null && cd /userdata/system/add-ons/zenity/.tmp

# Define the GitHub API URL
API_URL="https://api.github.com/repos/DTJW92/batocera-unofficial-addons/contents/zenity"

# Fetch the file list from the GitHub API
curl -s "$API_URL/bin" | grep '"download_url":' | cut -d '"' -f 4 > bin_list.txt
curl -s "$API_URL/lib" | grep '"download_url":' | cut -d '"' -f 4 > lib_list.txt

# Check if any list is empty
if [ ! -s bin_list.txt ] && [ ! -s lib_list.txt ]; then
    echo "No files found in the zenity folder on GitHub. Exiting."
    exit 1
fi

# Create destination folders
mkdir -p /userdata/system/add-ons/zenity/bin
mkdir -p /userdata/system/add-ons/zenity/lib

# Download bin files
if [ -s bin_list.txt ]; then
    while read -r FILE_URL; do
        FILE_NAME=$(basename "$FILE_URL")
        echo "Downloading $FILE_NAME..."
        wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/userdata/system/add-ons/zenity/bin/$FILE_NAME" "$FILE_URL"
    done < bin_list.txt
fi

# Download lib files
if [ -s lib_list.txt ]; then
    while read -r FILE_URL; do
        FILE_NAME=$(basename "$FILE_URL")
        echo "Downloading $FILE_NAME..."
        wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/userdata/system/add-ons/zenity/lib/$FILE_NAME" "$FILE_URL"
    done < lib_list.txt
fi

# Set permissions
chmod 755 /userdata/system/add-ons/zenity/bin/*
chmod 644 /userdata/system/add-ons/zenity/lib/*

# Cleanup
rm -rf /userdata/system/add-ons/zenity/.tmp

echo "Zenity installed successfully."
