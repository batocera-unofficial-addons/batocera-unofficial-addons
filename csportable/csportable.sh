#!/usr/bin/env bash

# Variables
APPNAME="CS Portable"
APPDIR="/userdata/system/add-ons/csportable"
ZIP_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/csportable/extra/CS-Portable-2023.zip"
ZIP_PATH="$APPDIR/CS-Portable-2023.zip"
PORT_SCRIPT="/userdata/roms/ports/CSPortable.sh"
ICON_PATH="/userdata/roms/ports/images/cs-portable-logo.jpg"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/csportable/extra/cs-portable-logo.jpg"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 2: Check if CS Portable is installed
if [[ ! -d $APPDIR || ! -f "$APPDIR/CS Portable" ]]; then
  echo "$APPNAME is not installed. Downloading and setting up..."
  mkdir -p "$APPDIR"  # Ensure the directory exists

  # Download the ZIP file
  curl -L -o "$ZIP_PATH" "$ZIP_URL"

  # Extract the ZIP file
  unzip "$ZIP_PATH" -d "$APPDIR"

  # Remove the ZIP file after extraction
  rm "$ZIP_PATH"

  echo "$APPNAME setup completed."
fi

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 "$APPDIR/CS Portable"
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading CS Portable logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Add CS Portable entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./CSPortable.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/cs-portable-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access CS Portable through Ports!"
