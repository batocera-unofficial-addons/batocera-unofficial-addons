#!/bin/bash

# Define your variables for easy customization
URL="https://drive.usercontent.google.com/download?id=1Qizzji8stAHTDQSwHX3QoBq3vf6iXNrN&export=download&authuser=0&confirm=t"
KEYS_URL=""  # Leave empty if no keys file is needed
DEST_DIR="/userdata/roms/windows"
MESSAGE="Needs DXVK set to OFF"  # Leave empty if no message is needed
GAME_LIST="/userdata/roms/windows/gamelist.xml"
APP_NAME="Super Smash Bros CMC+"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/windows/extra/cmc.jpg"
LOGO_PATH="/userdata/roms/windows/images/cmc+-logo.jpg"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"
mkdir -p "$(dirname "$LOGO_PATH")"

# Download the main .wsquashfs file
wget -q --show-progress --no-check-certificate -O "$DEST_DIR/CMC+.wsquashfs" "$URL"
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

curl http://127.0.0.1:1234/reloadgames

# Ensure the gamelist.xml exists
if [ ! -f "/userdata/roms/windows/gamelist.xml" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "/userdata/roms/windows/gamelist.xml"
fi

# Add game entry to gamelist.xml
if [[ -f "$GAME_LIST" ]]; then
# Download the logo
echo "Downloading $APP_NAME logo..."
curl -L -o "$LOGO_PATH" "$LOGO_URL"
echo "Adding logo to $APP_NAME entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./CMC+.wsquashfs" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/cmc+-logo.jpg" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames
  
  # Reload game list
  curl http://127.0.0.1:1234/reloadgames
else
  echo "Game list file not found: $GAME_LIST"
fi

# Clear dialog box after execution
clear
