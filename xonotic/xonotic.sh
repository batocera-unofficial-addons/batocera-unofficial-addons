#!/bin/bash

# Variables to update for different apps
APP_NAME="Xonotic"
AMD_SUFFIX="xonotic-0.8.6.zip"
ARM_SUFFIX=""
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/xonotic/extra/xonotic-logo.jpg"
REPO_BASE_URL="https://dl.unvanquished.net/share/xonotic/release"

# -----------------------------------------------------------------------------------------------------------------

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    zip_url="${REPO_BASE_URL}/${AMD_SUFFIX}"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    if [ -n "$ARM_SUFFIX" ]; then
        zip_url="${REPO_BASE_URL}/${ARM_SUFFIX}"
    else
        echo "No ARM64 zip suffix provided. Skipping download. Exiting."
        exit 1
    fi
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

if [ -z "$zip_url" ]; then
    echo "No suitable zip found for architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the zip
echo "Downloading $APP_NAME zip from $zip_url..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}"
ZIP_FILE="$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}.zip"
wget -q --show-progress -O "$ZIP_FILE" "$zip_url"

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME zip."
    exit 1
fi

# Step 3: Extract the zip
echo "Extracting $APP_NAME zip to $ADDONS_DIR/${APP_NAME,,}..."
unzip -o "$ZIP_FILE" -d "$ADDONS_DIR/${APP_NAME,,}"

if [ $? -ne 0 ]; then
    echo "Failed to extract $APP_NAME zip."
    exit 1
fi

# Step 4: Remove the zip file
echo "Cleaning up: Removing the ZIP file..."
rm -f "$ZIP_FILE"

if [ $? -eq 0 ]; then
    echo "$APP_NAME has been successfully downloaded and extracted."
else
    echo "Failed to remove the ZIP file."
    exit 1
fi


chmod a+x "$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}/$APP_NAME/xonotic-linux-sdl.sh"
echo "$APP_NAME downloaded and marked as executable."

# Create persistent log directory
mkdir -p "$LOGS_DIR"

# Step 3: Create the app launch script
echo "Creating $APP_NAME script in Ports..."
mkdir -p "$PORTS_DIR"
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="$ADDONS_DIR/${APP_NAME,,}"
xono="\${app_dir}/$APP_NAME/xonotic-linux-sdl.sh"
log_dir="$LOGS_DIR"
log_file="\${log_dir}/${APP_NAME,,}.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\$log_file")
echo "\$(date): Launching $APP_NAME"

# Launch Xonotic
    \${xono} "\$@" > "\${log_file}" 2>&1
    echo "$APP_NAME exited."
else
    echo "$APP_NAME not found or not executable."
    exit 1
fi
EOF

chmod +x "$PORT_SCRIPT"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the logo
echo "Downloading $APP_NAME logo..."
curl -L -o "$LOGO_PATH" "$LOGO_URL"
echo "Adding logo to $APP_NAME entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
