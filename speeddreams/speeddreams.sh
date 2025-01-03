#!/usr/bin/env bash

# Variables
APPNAME="Speed Dreams"
APPDIR="/userdata/system/add-ons/speed-dreams"
APPPATH="$APPDIR/speed-dreams.AppImage"
SPEED_DREAMS_INSTALLER_URL="https://altushost-swe.dl.sourceforge.net/project/speed-dreams/2.3.0/speed-dreams-2.3.0-x86_64.AppImage?viasf=1"
PORT_SCRIPT="/userdata/roms/ports/Speed-Dreams.sh"
ICON_PATH="/userdata/roms/ports/images/speed-dreams-logo.png"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/speed-dreams/extra/speed-dreams-logo.jpg"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Check if Speed Dreams is installed
if [[ ! -f $APPPATH ]]; then
  echo "$APPNAME is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"  # Ensure the directory exists
  curl -L -o "$APPPATH" "$SPEED_DREAMS_INSTALLER_URL"
  chmod +x "$APPPATH"
  echo "$APPNAME installation completed."
fi

# Step 2: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH
EOF

chmod +x $PORT_SCRIPT

# Step 3: Download the icon
echo "Downloading Speed Dreams logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"


# Step 4: Add Speed Dreams entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Speed-Dreams.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/speed-dreams-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Speed Dreams through Ports!"
