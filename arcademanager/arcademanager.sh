#!/bin/bash

# Set default values if the environment variables are not set
APPIMAGE_URL_X86_64="https://github.com/cosmo0/arcade-manager/releases/download/v7.1/ArcadeManager-7.1-linux-x64.AppImage"
APPIMAGE_URL_ARM64="https://github.com/cosmo0/arcade-manager/releases/download/v7.1/ArcadeManager-7.1-linux-arm64.AppImage"
APP_NAME="arcademanager"
APPIMAGE_NAME="arcademanager.AppImage"
APP_DIR="/userdata/system/add-ons/$APP_NAME"
LOG_DIR="/userdata/system/logs"
LOG_FILE=${LOG_FILE:-"$LOG_DIR/$APP_NAME.log"}

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="$APPIMAGE_URL_X86_64"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    appimage_url="$APPIMAGE_URL_ARM64"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading AppImage from $appimage_url..."
mkdir -p "$APP_DIR"
wget -q --show-progress -O "$APP_DIR/$APPIMAGE_NAME" "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the AppImage."
    exit 1
fi

chmod a+x "$APP_DIR/$APPIMAGE_NAME"
echo "AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p "$LOG_DIR"

# Step 3: Create the App Launcher Script
echo "Creating App launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/ArcadeManager.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0

# Directories and file paths
app_dir="/userdata/system/add-ons/arcademanager"
app_image="arcademanager.AppImage"
log_dir="/userdata/system/logs"
log_file="$log_dir/arcademanager.log"

# Ensure log directory exists
mkdir -p "\$log_dir"

# Append all output to the log file
exec &> >(tee -a "\$log_file")
echo "\$(date): Launching Arcade Manager"

# Launch the AppImage
if [ -x "\$app_image" ]; then
    echo "\$(date): AppImage is executable, launching..."
    cd "$app_dir"
    ./$app_image > "\$log_file" 2>&1
    echo "\$(date): Arcade Manager exited."
else
    echo "\$(date): $app_image not found or not executable."
    exit 1
fi

EOF

chmod +x /userdata/roms/ports/ArcadeManager.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
