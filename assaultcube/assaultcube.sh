#!/bin/bash

# Variables specific to AssaultCube
APP_NAME="AssaultCube"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/assaultcube/extra/assaultcube-logo.png"
FILE_URL="https://github.com/assaultcube/AC/releases/download/v1.3.0.2/AssaultCube_v1.3.0.2_LockdownEdition_RC1.tar.bz2"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"

# Step 1: Create necessary directories
echo "Setting up directories..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}" "$PORTS_DIR" "$LOGS_DIR" "$PORTS_DIR/images"

# Step 2: Download and extract AssaultCube
echo "Downloading $APP_NAME..."
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/AssaultCube.tar.bz2" "$FILE_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME. Exiting."
    exit 1
fi

# Extract the downloaded file
echo "Extracting $APP_NAME..."
tar -xjvf "$ADDONS_DIR/${APP_NAME,,}/AssaultCube.tar.bz2" -C "$ADDONS_DIR/${APP_NAME,,}"

if [ $? -ne 0 ]; then
    echo "Failed to extract $APP_NAME. Exiting."
    exit 1
fi

# Step 3: Create the app launch script
echo "Creating launch script..."
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Launch AssaultCube
cd "$ADDONS_DIR/${APP_NAME,,}"
./assaultcube.sh "\$@"
EOF

chmod +x "$PORT_SCRIPT"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 5: Download the logo
echo "Downloading logo..."
curl -L -o "$LOGO_PATH" "$LOGO_URL"

# Step 6: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames
echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu!"
