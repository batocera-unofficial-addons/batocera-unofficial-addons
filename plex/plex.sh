#!/usr/bin/env bash

# Variables
APPNAME="Plex"
APPDIR="/userdata/system/add-ons/plex"
APPPATH="$APPDIR/Plex_Media_Player.AppImage"
PLEX_INSTALLER_URL="https://github.com/knapsu/plex-media-player-appimage/releases/download/v2.58.1-ae73e074/Plex_Media_Player_2.58.1-ae73e074_x64.AppImage"
PORT_SCRIPT="/userdata/roms/ports/Plex.sh"
ICON_PATH="/userdata/roms/ports/images/plex-logo.jpg"
KEYS_PATH="/userdata/roms/ports/Plex.sh.keys"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/plex/extra/plex-logo.jpg"
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/plex/extra/Plex.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 2: Check if Plex is installed
if [[ -d $APPDIR ]]; then
  echo "$APPDIR exists. Removing it to ensure a clean setup..."
  rm -rf "$APPDIR"
fi

# Ensure the directory exists
mkdir -p "$APPDIR"

# Download and install
echo "$APPNAME is not installed. Downloading and setting up..."
curl -L -o "$APPPATH" "$PLEX_INSTALLER_URL"

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to download $APPNAME. Exiting."
  exit 1
fi

chmod +x "$APPPATH"
echo "$APPNAME installation completed successfully."

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading Plex logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "$KEYS_PATH" "$KEYS_URL"

# Step 6: Add Plex entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Plex.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/plex-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Plex through Ports!"
