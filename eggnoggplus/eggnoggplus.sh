#!/bin/bash

# Variables to customize for each Linux game/app
APP_NAME="EGGNOGG+"  # Insert app name here, e.g., "AssaultCube"
LOGO_URL="https://img.itch.zone/aW1hZ2UvMzM5LzUxNjY1LnBuZw==/original/F%2F9iSJ.png"  # Insert the URL for the logo image here
FILE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/eggnoggplus.zip"  # Insert the download URL for the tar.bz2, tar.gz, or zip file
LAUNCH_CMD="./eggnoggplus"  # Insert the launch command/script, e.g., "./assaultcube.sh", "./game", etc.

# Directory configuration
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"

# Auto-detect archive type and extraction command from FILE_URL
if [[ "$FILE_URL" =~ \.tar\.bz2$ ]]; then
    ARCHIVE_EXTENSION="tar.bz2"
    EXTRACT_CMD="tar -xjvf"
    STRIP_COMPONENTS="--strip-components=1"
elif [[ "$FILE_URL" =~ \.tar\.gz$ ]] || [[ "$FILE_URL" =~ \.tgz$ ]]; then
    ARCHIVE_EXTENSION="tar.gz"
    EXTRACT_CMD="tar -xzvf"
    STRIP_COMPONENTS="--strip-components=1"
elif [[ "$FILE_URL" =~ \.tar\.xz$ ]]; then
    ARCHIVE_EXTENSION="tar.xz"
    EXTRACT_CMD="tar -xJvf"
    STRIP_COMPONENTS="--strip-components=1"
elif [[ "$FILE_URL" =~ \.zip$ ]]; then
    ARCHIVE_EXTENSION="zip"
    EXTRACT_CMD="unzip -j"
    STRIP_COMPONENTS=""
else
    echo "Error: Unsupported archive format in FILE_URL"
    exit 1
fi

# Detect logo file extension from LOGO_URL (default to .png if not provided)
if [[ -n "$LOGO_URL" ]]; then
    LOGO_EXT="${LOGO_URL##*.}"
    # Remove query parameters if present (e.g., ?raw=true)
    LOGO_EXT="${LOGO_EXT%%\?*}"
else
    LOGO_EXT="png"
fi

# Construct paths
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.${LOGO_EXT}"
DOWNLOAD_PATH="$ADDONS_DIR/${APP_NAME,,}/${APP_NAME}.${ARCHIVE_EXTENSION}"

# Step 1: Create necessary directories
echo "Setting up directories..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}" "$PORTS_DIR" "$LOGS_DIR" "$PORTS_DIR/images"

# Step 2: Download the file
echo "Downloading $APP_NAME..."
wget -q --show-progress -O "$DOWNLOAD_PATH" "$FILE_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME. Exiting."
    exit 1
fi

# Step 3: Extract the downloaded file
echo "Extracting $APP_NAME..."
cd "$ADDONS_DIR/${APP_NAME,,}"
$EXTRACT_CMD "$DOWNLOAD_PATH" $STRIP_COMPONENTS

if [ $? -ne 0 ]; then
    echo "Failed to extract $APP_NAME. Exiting."
    exit 1
fi

# Optional: Remove archive after extraction to save space
rm -f "$DOWNLOAD_PATH"

# Step 4: Create the app launch script
echo "Creating launch script..."
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Launch $APP_NAME
cd "$ADDONS_DIR/${APP_NAME,,}"
$LAUNCH_CMD "\$@"
EOF

chmod +x "$PORT_SCRIPT"

# Step 5: Download the logo if URL is provided
if [[ -n "$LOGO_URL" ]]; then
    echo "Downloading logo..."
    wget -q --show-progress -O "$LOGO_PATH" "$LOGO_URL"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to download logo from $LOGO_URL"
    fi
fi

# Step 6: Ensure gamelist.xml exists
if [ ! -f "$GAME_LIST" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAME_LIST"
fi

# Step 7: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.${LOGO_EXT}" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

if [ $? -ne 0 ]; then
    echo "Error: Failed to update gamelist.xml"
    exit 1
fi

# Step 8: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu!"
