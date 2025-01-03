#!/usr/bin/env bash

# Variables
APPNAME="Speed Dreams"
APPDIR="/userdata/system/add-ons/speed-dreams"
APPPATH="$APPDIR/speed-dreams.AppImage"
SPEED_DREAMS_INSTALLER_URL="https://altushost-swe.dl.sourceforge.net/project/speed-dreams/2.3.0/speed-dreams-2.3.0-x86_64.AppImage?viasf=1"
PORT_SCRIPT="/userdata/roms/ports/Speed-Dreams.sh"
ICON_PATH="/userdata/roms/ports/images/speed-dreams-logo.png"
KEYS_PATH="/userdata/roms/ports/Speed-Dreams.sh.keys"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/speed-dreams/extra/speed-dreams-logo.jpg"
KEYS_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/speed-dreams/extra/Speed-Dreams.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Show dialog to confirm
dialog --title "Install $APPNAME" \
  --yesno "Do you want to install Speed Dreams?" 10 50

# Check the user's choice
if [[ $? -ne 0 ]]; then
  echo "Installation canceled by user."
  exit 1
fi

clear
# Step 2: Check if Speed Dreams is installed
if [[ ! -f $APPPATH ]]; then
  echo "$APPNAME is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"  # Ensure the directory exists
  curl -L -o "$APPPATH" "$SPEED_DREAMS_INSTALLER_URL"
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
echo "Downloading Speed Dreams logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "$KEYS_PATH" "$KEYS_URL"

# Step 6: Add Speed Dreams entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Speed-Dreams.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/speed-dreams-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Speed Dreams through Ports!"
