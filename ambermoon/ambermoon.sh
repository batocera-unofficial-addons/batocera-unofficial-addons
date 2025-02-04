#!/bin/bash

# Variables specific to Ambermoon
APP_NAME="Ambermoon"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/ambermoon/extra/ambermoon-logo.png"
FILE_URL="https://github.com/Pyrdacor/Ambermoon.net/releases/download/v1.10.4/Ambermoon.net-Linux.tar.gz"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"
CONFIG_FILE="${ADDONS_DIR}/${APP_NAME,,}/ambermoon.cfg"
TAR_FILE="$ADDONS_DIR/${APP_NAME,,}/Ambermoon.tar.gz"

# Step 1: Create necessary directories
echo "Setting up directories..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}" "$PORTS_DIR" "$LOGS_DIR" "$PORTS_DIR/images"

# Step 2: Download and extract Ambermoon
echo "Downloading $APP_NAME..."
wget -q --show-progress -O "$TAR_FILE" "$FILE_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME. Exiting."
    exit 1
fi

# Extract the downloaded file
echo "Extracting $APP_NAME..."
tar -xzvf "$TAR_FILE" -C "$ADDONS_DIR/${APP_NAME,,}"

if [ $? -ne 0 ]; then
    echo "Failed to extract $APP_NAME. Exiting."
    exit 1
fi

# Remove the .tar.gz file after extraction
echo "Cleaning up..."
rm -f "$TAR_FILE"

# Step 3: Create ambermoon.cfg if it doesn't exist
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Creating default configuration file for $APP_NAME..."
    cat << EOF > "$CONFIG_FILE"
{
  "UsePatcher": true,
  "PatcherTimeout": 1250,
  "UseProxyForPatcher": false,
  "PatcherProxy": "",
  "WindowX": 0,
  "WindowY": 0,
  "MonitorIndex": 0,
  "Fullscreen": true,
  "UseDataPath": false,
  "DataPath": "/userdata/system/add-ons/ambermoon",
  "SaveOption": 0,
  "GameVersionIndex": 1,
  "LegacyMode": false,
  "Music": true,
  "Volume": 100,
  "ExternalMusic": false,
  "BattleSpeed": 0,
  "AutoDerune": true,
  "EnableCheats": false,
  "ShowButtonTooltips": true,
  "ShowFantasyIntro": true,
  "ShowIntro": false,
  "GraphicFilter": 0,
  "GraphicFilterOverlay": 0,
  "Effects": 0,
  "ShowPlayerStatsTooltips": true,
  "ShowPyrdacorLogo": true,
  "ShowFloor": true,
  "ShowCeiling": true,
  "ShowFog": true,
  "ExtendedSavegameSlots": true,
  "AdditionalSavegameSlots": [],
  "ShowSaveLoadMessage": false,
  "Movement3D": 0,
  "TurnWithArrowKeys": true,
  "Language": 0
}
EOF
else
    echo "Configuration file already exists. Skipping creation."
fi

# Step 4: Create the app launch script
echo "Creating launch script..."
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Launch Ambermoon
cd "$ADDONS_DIR/${APP_NAME,,}"
./Ambermoon.net "\$@"
EOF

chmod +x "$PORT_SCRIPT"

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 6: Download the logo
echo "Downloading logo..."
curl -L -o "$LOGO_PATH" "$LOGO_URL"

# Step 7: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
