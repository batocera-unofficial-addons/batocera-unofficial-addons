#!/usr/bin/env bash

# Variables
APPNAME="CS Portable"
APPDIR="/userdata/system/add-ons/cs-portable"
APPPATH="$APPDIR/CS-Portable.AppImage"
CS_PORTABLE_INSTALLER_URL="https://ocs-dl.fra1.cdn.digitaloceanspaces.com/data/files/1630461981/CS-Portable-x86-64.AppImage?response-content-disposition=attachment%3B%2520CS-Portable-x86-64.AppImage&X-Amz-Content-Sha256=UNSIGNED-PAYLOAD&X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=RWJAQUNCHT7V2NCLZ2AL%2F20250103%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20250103T181000Z&X-Amz-SignedHeaders=host&X-Amz-Expires=3600&X-Amz-Signature=192d07312a537d91fea31d03445f9a64032c87f8c09853ff58627fc9ce4e9b36"
PORT_SCRIPT="/userdata/roms/ports/CS-Portable.sh"
ICON_PATH="/userdata/roms/ports/images/cs-portable-logo.jpg"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/csportable/extra/cs-portable-logo.jpg"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 2: Check if CS Portable is installed
if [[ ! -f $APPPATH ]]; then
  echo "$APPNAME is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"  # Ensure the directory exists
  curl -L -o "$APPPATH" "$CS_PORTABLE_INSTALLER_URL"
  chmod +x "$APPPATH"
  echo "$APPNAME installation completed."
fi

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading CS Portable logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Add CS Portable entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./CS-Portable.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/cs-portable-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access CS Portable through Ports!"
