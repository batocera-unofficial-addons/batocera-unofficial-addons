#!/bin/bash

# Variables specific to Jellyfin
APP_NAME="Jellyfin"
LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/jellyfin/extra/jellyfin-logo.png"
AMD64_FILE_URL="https://repo.jellyfin.org/files/server/linux/latest-stable/amd64-musl/jellyfin_10.10.3-amd64-musl.tar.gz"
ARM_FILE_URL="https://repo.jellyfin.org/files/server/linux/latest-stable/arm64-musl/jellyfin_10.10.3-arm64-musl.tar.gz"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    FILE_URL="$AMD64_FILE_URL"
elif [ "$ARCH" = "aarch64" ]; then
    FILE_URL="$ARM_FILE_URL"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Step 1: Create necessary directories
echo "Setting up directories..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}" "$PORTS_DIR" "$LOGS_DIR" "$PORTS_DIR/images"

# Step 2: Download and extract Jellyfin
echo "Downloading $APP_NAME..."
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/Jellyfin.tar.gz" "$FILE_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME. Exiting."
    exit 1
fi

# Extract the downloaded file
echo "Extracting $APP_NAME..."
tar -xzvf "$ADDONS_DIR/${APP_NAME,,}/Jellyfin.tar.gz" -C "$ADDONS_DIR/${APP_NAME,,}"

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

# Launch Jellyfin
cd "$ADDONS_DIR/${APP_NAME,,}"
./jellyfin "\$@"
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
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
