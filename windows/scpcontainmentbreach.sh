#!/bin/bash

# Variables to customize for each game
APP_NAME="SCP Containment Breach"  # Insert game name here, e.g., "Maldita Castilla"
URL_SUFFIX="SCP-ContainmentBreach.wsquashfs"  # Insert the specific .wsquashfs filename here, e.g., "maldita_castilla.wsquashfs"
KEYS_URL=""  # Leave empty if no keys file is needed
MESSAGE=""  # Leave empty if no message is needed
LOGO_URL="https://super142.wordpress.com/wp-content/uploads/2021/11/scp-containment-breach.jpg"  # Insert the URL for the logo image here

# Define your variables for easy customization
URL_PREFIX="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/"
DEST_DIR="/userdata/roms/windows"
GAME_LIST="/userdata/roms/windows/gamelist.xml"

# Construct full URL
URL="${URL_PREFIX}${URL_SUFFIX}"

# Strip .wsquashfs extension from URL_SUFFIX for logo filename
GAME_BASENAME="${URL_SUFFIX%.wsquashfs}"

# Detect logo file extension from LOGO_URL (default to .jpg if not provided)
if [[ -n "$LOGO_URL" ]]; then
  LOGO_EXT="${LOGO_URL##*.}"
  # Remove query parameters if present (e.g., ?raw=true)
  LOGO_EXT="${LOGO_EXT%%\?*}"
else
  LOGO_EXT="jpg"
fi

LOGO_PATH="/userdata/roms/windows/images/${GAME_BASENAME}-logo.${LOGO_EXT}"

# Ensure destination directory exists
mkdir -p "$DEST_DIR"
mkdir -p "/userdata/roms/windows/images"

# Download the main .wsquashfs file
echo "Downloading $APP_NAME..."
wget -q --show-progress -O "$DEST_DIR/$URL_SUFFIX" "$URL"
if [[ $? -ne 0 ]]; then
  echo "Error downloading $URL"
  exit 1
fi

# Download the keys file if KEYS_URL is provided and accessible
if [[ -n "$KEYS_URL" ]]; then
  if wget --spider "$KEYS_URL" 2>/dev/null; then
    echo "Downloading keys file..."
    wget -q --show-progress -O "$DEST_DIR/$(basename "$KEYS_URL")" "$KEYS_URL"
  else
    echo "No keys file found at $KEYS_URL. Skipping download."
  fi
fi

# Show message using dialog if MESSAGE is set
if [[ -n "$MESSAGE" ]]; then
  dialog --msgbox "$MESSAGE" 6 50
fi

# Ensure the gamelist.xml exists
if [ ! -f "$GAME_LIST" ]; then
  echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAME_LIST"
fi

# Add game entry to gamelist.xml
if [[ -f "$GAME_LIST" ]]; then
  # Download the logo if URL is provided
  if [[ -n "$LOGO_URL" ]]; then
    echo "Downloading $APP_NAME logo..."
    wget -q --show-progress -O "$LOGO_PATH" "$LOGO_URL"
    if [[ $? -ne 0 ]]; then
      echo "Warning: Failed to download logo from $LOGO_URL"
    fi
  fi

  # Add game entry to gamelist.xml
  echo "Adding $APP_NAME entry to gamelist.xml..."
  xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
    -s "/gameList/game[last()]" -t elem -n "path" -v "./$URL_SUFFIX" \
    -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
    -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${GAME_BASENAME}-logo.${LOGO_EXT}" \
    "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

  if [[ $? -ne 0 ]]; then
    echo "Error: Failed to update gamelist.xml"
    exit 1
  fi

  # Reload game list
  echo "Reloading game list..."
  curl -s http://127.0.0.1:1234/reloadgames
else
  echo "Error: Game list file not found: $GAME_LIST"
  exit 1
fi

# Clear dialog box after execution
clear

echo "$APP_NAME installation complete!"
