#!/bin/bash

# Define variables
ARIA2C_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wine-custom/extra/aria2c"
DOWNLOAD_DIR="/userdata/system/wine/exe"
DOWNLOAD_URL="https://download2284.mediafire.com/njntbvzq57qgQs3G8R4u7McQKy0e3D7gXWicGQCF62zfy3zPQv4DYMGtbwDzM3owvOI7urBMTHbgU_AlGMg-U63JoqFwMMjLJ3HuAZcnxWf4ziPgbZL9BmJDqA1B6dPdfr9vOBAwrtbhEqI-_0lqCT6YrYwmSVyUISubAvOD17s/2w61oygu1o2k1mv/STEAMY-AiO.exe"
DOWNLOAD_FILE="steamy.exe"

# Fetch aria2c
echo "Downloading aria2c..."
wget -q "$ARIA2C_URL" -O /userdata/system/add-ons/.dep/aria2c && chmod +x /userdata/system/add-ons/.dep/aria2c
if ! command -v aria2c &> /dev/null; then
    echo "Failed to symlink or execute aria2c. Exiting."
    exit 1
fi

# Create the download directory if it doesn't exist
mkdir -p "$DOWNLOAD_DIR"

# Download the file using aria2c
echo "Downloading $DOWNLOAD_FILE..."
aria2c -x 5 -s 5 -d "$DOWNLOAD_DIR" -o "$DOWNLOAD_FILE" "$DOWNLOAD_URL"
if [ -f "$DOWNLOAD_DIR/$DOWNLOAD_FILE" ]; then
    echo "$DOWNLOAD_FILE downloaded successfully to $DOWNLOAD_DIR."
else
    echo "Download failed or $DOWNLOAD_FILE not found."
    exit 1
fi

# Output success message
echo ""
echo "Steamy-AIO downloaded to $DOWNLOAD_DIR."
echo "If needed, rename $DOWNLOAD_DIR.bak to $DOWNLOAD_DIR to launch the Steamy-AIO dependency installer before starting the Windows game."
