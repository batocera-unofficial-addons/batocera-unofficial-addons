#!/bin/bash

# Create the target directory
mkdir -p ~/add-ons/.dep 2>/dev/null && cd ~/add-ons/.dep

# Define the GitHub API URL
API_URL="https://api.github.com/repos/DTJW92/batocera-unofficial-addons/contents/.dep"

# Fetch the file list from the GitHub API
curl -s "$API_URL" | grep '"download_url":' | cut -d '"' -f 4 > file_list.txt

# Check if file_list.txt is not empty
if [ ! -s file_list.txt ]; then
    echo "No files found in the .dep folder on GitHub. Exiting."
    exit 1
fi

# Download each file from the list
while read -r FILE_URL; do
    FILE_NAME=$(basename "$FILE_URL")
    echo "Downloading $FILE_NAME..."
    wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "$FILE_NAME" "$FILE_URL"
done < file_list.txt

# Set permissions
chmod 777 ~/add-ons/.dep/*

# Cleanup
rm file_list.txt

echo "All dependencies downloaded."
