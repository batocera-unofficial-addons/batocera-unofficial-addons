#!/usr/bin/env bash

# Variables
APPNAME="UnderTaker141"
APPDIR="/userdata/system/add-ons/undertaker141"
APPPATH="$APPDIR/UnderTaker141.AppImage"
UNDERTAKER_INSTALLER_URL="https://github.com/AbdelrhmanNile/UnderTaker141/releases/download/latest/UnderTaker141.AppImage"
PORT_SCRIPT="/userdata/roms/ports/UnderTaker141.sh"
ICON_PATH="/userdata/roms/ports/images/undertaker-logo.jpg"
KEYS_PATH="/userdata/roms/ports/UnderTaker141.sh.keys"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/undertaker/extra/undertaker-logo.jpg"
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/undertaker/extra/UnderTaker141.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Show dialog to confirm
dialog --title "Install $APPNAME" \
  --yesno "Do you want to install UnderTaker141?" 10 50

# Check the user's choice
if [[ $? -ne 0 ]]; then
  echo "Installation canceled by user."
  exit 1
fi

clear
# Step 2: Check if UnderTaker141 is installed
if [[ ! -f $APPPATH ]]; then
  echo "$APPNAME is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"  # Ensure the directory exists
  curl -L -o "$APPPATH" "$UNDERTAKER_INSTALLER_URL"
  chmod +x "$APPPATH"
  echo "$APPNAME installation completed."
fi

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 LD_LIBRARY_PATH=/userdata/system/pro/.dep:\$LD_LIBRARY_PATH $APPPATH
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading UnderTaker141 logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "$KEYS_PATH" "$KEYS_URL"

# Step 6: Add UnderTaker141 entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./UnderTaker141.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/undertaker-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access UnderTaker141 through Ports!"
