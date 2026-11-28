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

SAVE_DIR="$APPDIR/save"

# Step 2: Install (or replace) the game files
# The game keeps saves, settings and high scores in $SAVE_DIR. A reinstall
# only replaces the program files, so they are kept.
echo "Downloading and setting up $APPNAME..."
mkdir -p "$APPDIR"

# Download the archive
curl -L -o "$ZIP_PATH" "$ZIP_URL"
if [ $? -ne 0 ] || [ ! -s "$ZIP_PATH" ]; then
  rm -f "$ZIP_PATH"
  dialog --title "$APPNAME" --msgbox "Failed to download $APPNAME." 8 60
  exit 1
fi

# Remove the previous program files (not save/)
rm -rf "$APPDIR/jre"
rm -f "$APPDIR/Sandtrix" "$APPDIR/Sandtrix.json" "$APPDIR/sandtrix-1.0-SNAPSHOT-jar-with-dependencies.jar"

# Extract the tar.gz file
tar -xzf "$ZIP_PATH" -C "$APPDIR"

# Remove the archive after extraction
rm -f "$ZIP_PATH"

echo "$APPNAME setup completed."
[ -d "$SAVE_DIR" ] && echo "Kept your saves and high scores in $SAVE_DIR."

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

# The game writes save/ in its working directory, so start it from $APPDIR.
cat << EOF > $PORT_SCRIPT
#!/bin/bash
cd "$APPDIR" || exit 1
DISPLAY=:0.0 "$APPDIR/Sandtrix"
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading Sandtrix logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Add Sandtrix entry to gamelist.xml
echo "Updating gamelist.xml..."
if [ ! -f "$GAMELIST" ]; then
  echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAMELIST"
fi
# -d drops an entry left by an earlier install, so a reinstall doesn't add a second one
xmlstarlet ed -d "/gameList/game[path='./Sandtrix.sh']" \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Sandtrix.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/sandtrix-logo.png" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Sandtrix through Ports!"
