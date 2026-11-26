#!/usr/bin/env bash

# Variables
APPNAME="YouTube TV"
APPDIR="/userdata/system/add-ons/google-chrome"
APPPATH="$APPDIR/GoogleChrome.AppImage"
CHROME_INSTALLER_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome.sh"
PORT_SCRIPT="/userdata/roms/ports/YouTubeTV.sh"
ICON_PATH="/userdata/roms/ports/images/youtubetv-logo.jpg"
KEYS_PATH="/userdata/roms/ports/YoutubeTV.sh.keys"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/youtubetv/extra/youtubetv-logo.jpg"
KEYS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/youtubetv/extra/YoutubeTV.sh.keys"
GAMELIST="/userdata/roms/ports/gamelist.xml"

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)
if [ "$arch" != "x86_64" ] && [ "$arch" != "aarch64" ]; then
    dialog --title "$APPNAME" --msgbox "Unsupported architecture: $arch. Exiting." 8 60
    exit 1
fi

# Step 2: Show dialog to confirm
dialog --title "Install $APPNAME" \
  --yesno "This app requires you to install Google Chrome first.\nProceed with the setup?" 10 50

if [[ $? -ne 0 ]]; then
  dialog --title "$APPNAME" --msgbox "Installation canceled by user." 8 60
  exit 1
fi

clear

# Step 3: Check if Chrome is installed
if [[ ! -f $APPPATH ]]; then
  echo "Google Chrome is not installed. Downloading and installing..."
  mkdir -p "$APPDIR"
  curl -L -o "$APPDIR/chrome.sh" "$CHROME_INSTALLER_URL"
  chmod +x "$APPDIR/chrome.sh"
  echo "Running the Google Chrome installer..."
  bash "$APPDIR/chrome.sh"
  if [[ ! -f $APPPATH ]]; then
    dialog --title "$APPNAME" --msgbox "Google Chrome installation failed. Exiting." 8 60
    exit 1
  fi
fi

# Remove leftovers from the old Electron-based YouTube TV client
rm -rf "/userdata/system/add-ons/youtube-tv"

# Step 4: Create the ports script
mkdir -p "$(dirname "$PORT_SCRIPT")"
mkdir -p "$(dirname "$ICON_PATH")"

cat << EOF > $PORT_SCRIPT
#!/bin/bash
DISPLAY=:0.0 $APPPATH --no-sandbox --test-type --start-fullscreen \\
  --user-agent="Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/5.0 TV Safari/538.1" \\
  'https://www.youtube.com/tv'
EOF

chmod +x $PORT_SCRIPT

# Step 5: Download the icon
echo "Downloading YouTube TV logo..."
curl -fL -o "$ICON_PATH" "$LOGO_URL"

# Step 6: Download the key mapping file
echo "Downloading key mapping file..."
curl -fL -o "$KEYS_PATH" "$KEYS_URL"

# Step 7: Add YouTube TV entry to gamelist.xml (replace any old entry)
echo "Updating gamelist.xml..."
if [[ ! -f "$GAMELIST" ]]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAMELIST"
fi

xmlstarlet ed -d "/gameList/game[path='./YouTubeTV.sh']" \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./YouTubeTV.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APPNAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/youtubetv-logo.jpg" \
  "$GAMELIST" > "${GAMELIST}.tmp" && mv "${GAMELIST}.tmp" "$GAMELIST"

# Step 8: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo "$APPNAME port setup completed. You can now access YouTube TV through Ports!"
