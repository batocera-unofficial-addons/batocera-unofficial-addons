#!/usr/bin/env bash

# Variables
APPNAME="Sandtrix"
APPDIR="/userdata/system/add-ons/sandtrix"
ZIP_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/sandtrix/extra/Sandtrix_3.0_LINUX.tar.gz"
ZIP_PATH="$APPDIR/Sandtrix_3.0_LINUX.tar.gz"
PORT_SCRIPT="/userdata/roms/ports/Sandtrix.sh"
ICON_PATH="/userdata/roms/ports/images/sandtrix-logo.png"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/sandtrix/extra/sandtrix-logo.png"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 2: Check if Sandtrix is installed
if [[ -d $APPDIR ]]; then
  echo "$APPDIR exists. Removing it to ensure a clean setup..."
  rm -rf "$APPDIR"
fi

if [[ ! -d $APPDIR || ! -f "$APPDIR/Sandtrix" ]]; then
  echo "$APPNAME is not installed. Downloading and setting up..."
  mkdir -p "$APPDIR"  # Ensure the directory exists

  # Download the ZIP file
  curl -L -o "$ZIP_PATH" "$ZIP_URL"

  # Extract the tar.gz file
  tar -xzf "$ZIP_PATH" -C "$APPDIR"

  # Remove the ZIP file after extraction
  rm "$ZIP_PATH"

  echo "$APPNAME setup completed."
fi

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 "$APPDIR/Sandtrix"
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading Sandtrix logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Add Sandtrix entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Sandtrix.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/sandtrix-logo.png" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Sandtrix through Ports!"
