#!/usr/bin/env bash

# Variables
APPNAME="flathub"
APPDIR="/userdata/system/add-ons/google-chrome"
APPPATH="$APPDIR/GoogleChrome.AppImage"
CHROME_INSTALLER_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome.sh"
PORT_SCRIPT="/userdata/roms/ports/flathub.sh"
ICON_PATH="/userdata/roms/ports/images/flathub-logo.jpg"
KEYS_PATH="/userdata/roms/ports/flathub.sh.keys"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/flathub/extra/flathub-logo.jpg"
KEYS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/flathub/extra/flathub.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Show dialog to confirm
dialog --title "Install $APPNAME" \
  --yesno "This app requires you to install Google Chrome first.\nProceed with the setup?" 10 50

# Check the user's choice
if [[ $? -ne 0 ]]; then
  echo "Installation canceled by user."
  exit 1
fi

clear
# Step 2: Check if Chrome is installed
if [[ ! -f $APPPATH ]]; then
  echo "Google Chrome is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"  # Ensure the directory exists
  curl -L -o "$APPDIR/chrome.sh" "$CHROME_INSTALLER_URL"
  chmod +x "$APPDIR/chrome.sh"
  echo "Running the Google Chrome installer..."
  bash "$APPDIR/chrome.sh"
  if [[ ! -f $APPPATH ]]; then
    echo "Google Chrome installation failed. Exiting."
    exit 1
  fi
fi

# Step 3: Create the ports script using EOF
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH --no-sandbox --test-type --start-fullscreen --force-device-scale-factor=1.6 'flathub.org'
EOF

chmod +x $PORT_SCRIPT

# Step 4: Download the icon
echo "Downloading flathub logo..."
curl -L -o "$ICON_PATH" "$LOGO_URL"

# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "$KEYS_PATH" "$KEYS_URL"

# Step 6: Add flathub entry to gamelist.xml
echo "Updating gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./flathub.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/flathub-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Flathub through Ports!"
