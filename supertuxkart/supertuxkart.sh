#!/bin/bash

# Variables for SuperTuxKart
APP_NAME="SuperTuxKart"

# URLs for different architectures
ARCH_X86_64="https://github.com/supertuxkart/stk-code/releases/download/1.4/SuperTuxKart-1.4-linux-x86_64.tar.xz"
ARCH_ARM64="https://github.com/supertuxkart/stk-code/releases/download/1.4/SuperTuxKart-1.4-linux-arm64.tar.xz"

LOGO_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/supertuxkart/extra/supertuxkart-logo.png"

# Determine system architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "x86_64" ]]; then
    ARCHIVE_URL="$ARCH_X86_64"
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    ARCHIVE_URL="$ARCH_ARM64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Directories
ADDONS_DIR="/userdata/system/add-ons"
TUX_DIR="${ADDONS_DIR}/supertuxkart"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"

# Step 1: Ensure the target directories exist
echo "Creating required directories..."
mkdir -p "$TUX_DIR"
mkdir -p "$PORTS_DIR/images"
mkdir -p "$LOGS_DIR"

# Step 2: Download and extract SuperTuxKart
echo "Downloading $APP_NAME for architecture $ARCH..."
wget -q --show-progress -O "${TUX_DIR}/SuperTuxKart.tar.xz" "$ARCHIVE_URL"
if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME. Exiting."
    exit 1
fi

echo "Extracting $APP_NAME..."
tar -xf "${TUX_DIR}/SuperTuxKart.tar.xz" -C "$TUX_DIR"
rm "${TUX_DIR}/SuperTuxKart.tar.xz"
chmod -R a+x "$TUX_DIR"
echo "$APP_NAME extracted to $TUX_DIR."

# Step 3: Create the app launch script
echo "Creating $APP_NAME script in Ports..."
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="${TUX_DIR}/SuperTuxKart-1.4-linux-x86_64"
log_dir="$LOGS_DIR"
log_file="\${log_dir}/${APP_NAME,,}.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\$log_file")
echo "\$(date): Launching $APP_NAME"

# Launch SuperTuxKart
if [ -d "\${app_dir}" ]; then
    cd "\${app_dir}"
    ./run_game.sh "\$@" > "\${log_file}" 2>&1
    echo "$APP_NAME exited."
else
    echo "$APP_NAME directory not found."
    exit 1
fi
EOF

chmod +x "$PORT_SCRIPT"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 5: Download the logo
echo "Downloading $APP_NAME logo..."
wget -q -O "$LOGO_PATH" "$LOGO_URL"
if [ $? -ne 0 ]; then
    echo "Failed to download logo. Continuing without logo."
fi

# Step 6: Add to gamelist.xml
echo "Adding $APP_NAME to Ports menu..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
