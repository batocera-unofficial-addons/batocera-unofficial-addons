#!/usr/bin/env bash

# Variables
APPNAME="Amazon Luna"
APPDIR="/userdata/system/add-ons/google-chrome"
APPPATH="$APPDIR/GoogleChrome.AppImage"
CHROME_INSTALLER_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome.sh"
PORT_SCRIPT="/userdata/roms/ports/AmazonLuna.sh"
ICON_PATH="/userdata/roms/ports/images/amazonluna.png"
KEYS_PATH="/userdata/roms/ports/AmazonLuna.sh.keys"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/amazonluna/extra/amazonluna.png"
KEYS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/amazonluna/extra/AmazonLuna.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Show dialog to confirm
dialog --title "Install $APPNAME" \
  --yesno "This app requires you to install Google Chrome first.\nProceed with the setup?" 10 50

# Check the user's choice
if [[ $? -ne 0 ]]; then
  echo "Installation canceled by user."
  exit 1
fi

clear
# Step 3: Check if Chrome is installed
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

# Remove leftovers from the old Electron client (download source no longer exists)
rm -rf "/userdata/system/add-ons/amazonluna/temp"

# Step 4: Create the ports script
mkdir -p "$(dirname "$PORT_SCRIPT")"  # Ensure the ports directory exists
mkdir -p "$(dirname "$ICON_PATH")"   # Ensure the images directory exists

# Controllers reach Luna through Chrome's Gamepad API; the user agent
# avoids Luna's unsupported-browser page on Linux.
cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH --no-sandbox --test-type --start-fullscreen \\
  --user-agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36" \\
  'https://luna.amazon.com/'
EOF

chmod +x $PORT_SCRIPT

# Step 5: Download the icon
echo "Downloading Amazon Luna logo..."
curl -fL -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Download the key mapping file (Hotkey + Start closes Luna; all other
# buttons are left to the game)
echo "Downloading key mapping file..."
curl -fL -o "$KEYS_PATH" "$KEYS_URL"

# Step 7: Add Amazon Luna entry to gamelist.xml (replace any old entry)
echo "Updating gamelist.xml..."
if [[ -f "$GAMELIST" ]]; then
  xmlstarlet ed -d "/gameList/game[path='./AmazonLuna.sh']" \
    -s "/gameList" -t elem -n "game" -v "" \
    -s "/gameList/game[last()]" -t elem -n "path" -v "./AmazonLuna.sh" \
    -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
    -s "/gameList/game[last()]" -t elem -n "image" -v "./images/amazonluna.png" \
    "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"
fi

# Step 8: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access Amazon Luna through Ports!"
