#!/bin/bash

# Load environment variables from a file or external source
# Example: source /path/to/env_file or export variables manually

# Set default values if the environment variables are not set
APPIMAGE_URL_X86_64=${APPIMAGE_URL_X86_64:-"https://example.com/newapp-x86_64.AppImage"}
APPIMAGE_URL_ARM64=${APPIMAGE_URL_ARM64:-"https://example.com/newapp-arm64.AppImage"}
APP_NAME=${APP_NAME:-"NewApp"}
APPIMAGE_NAME=${APPIMAGE_NAME:-"NewApp.AppImage"}
APP_DIR=${APP_DIR:-"/userdata/system/add-ons/$APP_NAME"}
LOG_DIR=${LOG_DIR:-"/userdata/system/logs"}
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
mkdir -p "$APP_DIR/newapp-config"
mkdir -p "$LOG_DIR"
mkdir -p "$APP_DIR/lib"

# Step 3: Create the App Launcher Script
echo "Creating App launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << EOF > /userdata/roms/ports/$APP_NAME.sh
#!/bin/bash

# Function to download libcups.so.2 if not present
download_libcups() {
    libcups_url="\${LIBCUPS_URL:-https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/newapp/lib/libcups.so.2}"
    libcups_dest="$APP_DIR/lib/libcups.so.2"

    # Check if the file already exists
    if [ ! -f "\$libcups_dest" ]; then
        echo "\$(date): libcups.so.2 not found, downloading..."
        wget -q --show-progress -O "\$libcups_dest" "\$libcups_url"

        if [ \$? -eq 0 ]; then
            echo "\$(date): libcups.so.2 downloaded successfully."
        else
            echo "\$(date): Failed to download libcups.so.2."
            exit 1
        fi
    else
        echo "\$(date): libcups.so.2 already exists, skipping download."
    fi
}

# Function to ensure the quickCss.css file exists
ensure_quick_css() {
    config_settings_dir="\${HOME}/.config/$APP_NAME/settings"
    quickCss="\${config_settings_dir}/quickCss.css"

    # Ensure the .config/$APP_NAME/settings directory exists
    mkdir -p "\$config_settings_dir"

    # Ensure quickCss.css exists (you can create an empty file or add some default content)
    if [ ! -f "\$quickCss" ]; then
        echo "/* Default CSS for $APP_NAME */" > "\$quickCss"
        echo "\$(date): Created default quickCss.css."
    fi
}

# Call functions
download_libcups
ensure_quick_css

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0

# Directories and file paths
app_dir="$APP_DIR"
quickCss_symlink="\$HOME/.config/$APP_NAME"
quickCss="\$HOME/.config/$APP_NAME/settings/quickCss.css"
app_image="\$app_dir/$APPIMAGE_NAME"
log_dir="$LOG_DIR"
log_file="\$log_dir/$APP_NAME.log"

# Ensure log directory exists
mkdir -p "\$log_dir"

# Append all output to the log file
exec &> >(tee -a "\$log_file")
echo "\$(date): Launching $APP_NAME"

# Move existing config if present
if [ -d "\$quickCss_symlink" ] && [ ! -L "\$quickCss_symlink" ]; then
    mv "\$quickCss_symlink" "\$app_dir/$APP_NAME-config"
fi

# Ensure quickCss file is symlinked as config
if [ ! -L "\$quickCss_symlink" ]; then
    ln -sf "\$quickCss" "\$quickCss_symlink"
    echo "\$(date): Symlink created for quickCss.css as config."
fi

# Launch the AppImage
if [ -x "\$app_image" ]; then
    echo "\$(date): AppImage is executable, launching..."
    cd "\$app_dir"
    ./$APPIMAGE_NAME --no-sandbox --trace-warnings > "\$log_file" 2>&1
    echo "\$(date): $APP_NAME exited."
else
    echo "\$(date): $APPIMAGE_NAME not found or not executable."
    exit 1
fi

EOF

chmod +x /userdata/roms/ports/$APP_NAME.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
