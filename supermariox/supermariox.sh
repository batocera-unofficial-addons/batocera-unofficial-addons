#!/bin/bash

# Detect system architecture
ARCH=$(uname -m)

# Set download URL based on architecture
if [ "$ARCH" == "x86_64" ]; then
    URL="https://wohlsoft.ru/projects/TheXTech/_downloads/releases/super-mario-bros-x-thextech-v1.3.7.1-linux-generic-u24.04-amd64.tar.gz"
elif [ "$ARCH" == "aarch64" ]; then
    URL="https://wohlsoft.ru/projects/TheXTech/_downloads/releases/super-mario-bros-x-thextech-v1.3.7.1-linux-generic-u20.04-aarch64.tar.gz"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

DEST_DIR="/userdata/system/add-ons/mariox"
ARCHIVE_NAME=$(basename "$URL")

# Create destination directory if it doesn't exist
mkdir -p "$DEST_DIR"

# Download the file
wget "$URL" -O "$ARCHIVE_NAME"

# Extract the archive to the destination directory
tar --strip-components=1 -xvzf "$ARCHIVE_NAME" -C "$DEST_DIR"

# Remove the downloaded archive
rm "$ARCHIVE_NAME"

# Create a launch script
LAUNCH_SCRIPT="/userdata/roms/ports/SuperMarioX.sh"
mkdir -p "$(dirname "$LAUNCH_SCRIPT")"
cat << EOF > "$LAUNCH_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="$DEST_DIR"
app_image="\${app_dir}/smbx"
log_dir="/userdata/logs"
log_file="\${log_dir}/SuperMarioX.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\${log_file}")
echo "\$(date): Launching SuperMarioX"

# Launch AppImage
if [ -x "\${app_image}" ]; then
    cd "\${app_dir}"
    ./smbx "\$@" > "\${log_file}" 2>&1
    echo "SuperMarioX exited."
else
    echo "SuperMarioX not found or not executable."
    exit 1
fi
EOF

chmod +x "$LAUNCH_SCRIPT"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the logo
echo "Downloading SuperMarioX logo..."
LOGO_PATH="/userdata/roms/ports/images/supermariox-logo.png"
LOGO_URL="https://cdn2.steamgriddb.com/logo_thumb/754b8fde508be74748bb02907c2409d9.png"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
curl -L -o "$LOGO_PATH" "$LOGO_URL"
echo "Adding logo to SuperMarioX entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./SuperMarioX.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Super Mario Bros X" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/supermariox-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames

# Print completion message
echo "Extraction completed! Files are in $DEST_DIR"
echo "Launch script created at $LAUNCH_SCRIPT"
