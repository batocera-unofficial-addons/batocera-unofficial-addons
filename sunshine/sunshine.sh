#!/bin/bash

# Step 1: Install Sunshine
echo "Installing Sunshine..."

# Create target directory
mkdir -p /userdata/system/add-ons/sunshine

# Fetch latest AppImage URL and download it
APPIMAGE_URL=$(curl -s https://api.github.com/repos/LizardByte/Sunshine/releases/latest | grep browser_download_url | grep AppImage | cut -d '"' -f 4)

if [ -n "$APPIMAGE_URL" ]; then
    curl -L "$APPIMAGE_URL" -o /userdata/system/add-ons/sunshine/sunshine.AppImage
    chmod +x /userdata/system/add-ons/sunshine/sunshine.AppImage
    echo "Sunshine installed successfully."
else
    echo "Failed to fetch the latest Sunshine AppImage URL."
fi

# Create a persistent configuration directory
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
#
# sunshine service script for Batocera
# Functional start/stop/restart/status (update)/uninstall

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/sunshine

# Directories and file paths
app_dir="/userdata/system/add-ons/sunshine"
app_image="${app_dir}/sunshine.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/sunshine.log"

# Ensure log directory exists
mkdir -p "${log_dir}"


# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): ${1} service sunshine"

case "$1" in
    start)
        echo "Starting Sunshine service..."

        # Start Sunshine AppImage
        if [ -x "${app_image}" ]; then
            cd "${app_dir}"
            ./sunshine.AppImage > "${log_file}" 2>&1 &
            echo "Sunshine started successfully."
        else
            echo "Sunshine.AppImage not found or not executable."
            exit 1
        fi
        ;;
    stop)
        echo "Stopping Sunshine service..."
        # Stop the specific processes for sunshine.AppImage
        pkill -f "./sunshine.AppImage" && echo "Sunshine stopped." || echo "Sunshine is not running."
        pkill -f "/tmp/.mount_sunshi" && echo "Sunshine child process stopped." || echo "Sunshine child process is not running."
        ;;
restart)
    "$0" stop
    "$0" start
    ;;
    status)
        if pgrep -f "sunshine.AppImage" > /dev/null; then
            echo "Sunshine is running."
            exit 0
        else
            echo "Sunshine is stopped. Going to update now"
            curl -L https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/sunshine/sunshine.sh | bash
            exit 1
        fi
        ;;
    uninstall)
        echo "Uninstalling Sunshine service..."
        "$0" stop
        rm -f "${app_image}"
        echo "Sunshine uninstalled successfully."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status(update)|uninstall}"
        exit 1
        ;;
esac

exit $?

EOF

chmod +x /userdata/system/services/sunshine

echo "Applying Nvidia patches for a smoother experience..."
# Apply Nvidia patches if necessary
curl -L https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/nvidiapatch/nvidiapatch.sh | bash

batocera-save-overlay

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine


echo
dialog --msgbox "Installation complete!\n\nPlease head to https://YOUR-MACHINE-IP:47990 to pair Sunshine with Moonlight if this is your first time running Sunshine :)" 10 60
