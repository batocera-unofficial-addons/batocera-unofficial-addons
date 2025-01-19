#!/bin/bash

# Define your variables for easy customization
URL="https://github.com/trashbus99/profork/releases/download/r1/Zelda2_Remake.wsquashfs"
KEYS_URL=""  # Leave empty if no keys file is needed
DEST_DIR="/userdata/roms/windows"
MESSAGE="Zelda 2 PC Remake - Needs Enable DXVK in Adv settings for game and change video mode resolution to 1280x720x60 for best results"  # Leave empty if no message is needed

# Ensure destination directory exists
mkdir -p "$DEST_DIR"

# Download the main .wsquashfs file
wget -O "$DEST_DIR/$(basename "$URL")" "$URL"
if [[ $? -ne 0 ]]; then
  echo "Error downloading $URL"
  exit 1
fi

# Download the keys file if KEYS_URL is provided and accessible
if [[ -n "$KEYS_URL" ]]; then
  if wget --spider "$KEYS_URL" 2>/dev/null; then
    wget -O "$DEST_DIR/$(basename "$KEYS_URL")" "$KEYS_URL"
  else
    echo "No keys file found at $KEYS_URL. Skipping download."
  fi
fi

# Show message using dialog if MESSAGE is set
if [[ -n "$MESSAGE" ]]; then
  dialog --msgbox "$MESSAGE" 6 50
fi

# Clear dialog box after execution
clear
