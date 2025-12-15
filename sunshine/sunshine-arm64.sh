#!/bin/bash

# Step 1: Install Sunshine for ARM64
echo "Installing Sunshine for ARM64..."

# Create target directory
mkdir -p /userdata/system/add-ons/sunshine

# Fetch latest ARM64 AppImage URL and download it
echo "Fetching the latest Sunshine ARM64 AppImage release..."
APPIMAGE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/sunshine/extra/Sunshine-aarch64.AppImage"
if [ -n "$APPIMAGE_URL" ]; then
    echo "Downloading Sunshine ARM64 AppImage from $APPIMAGE_URL..."
    curl -L "$APPIMAGE_URL" -o /userdata/system/add-ons/sunshine/sunshine.AppImage
    chmod +x /userdata/system/add-ons/sunshine/sunshine.AppImage
    echo "Sunshine ARM64 AppImage installed successfully."
else
    echo "Failed to fetch the latest Sunshine ARM64 AppImage URL."
    exit 1
fi

# Create persistent configuration directory and config file
echo "Creating Sunshine configuration..."
mkdir -p /userdata/system/.config/sunshine

# Create sunshine.conf with software encoder settings
cat << 'EOF' > /userdata/system/.config/sunshine/sunshine.conf
encoder = software
sw_preset = ultrafast
EOF

echo "Configuration file created at /userdata/system/.config/sunshine/sunshine.conf"

# Create a persistent log directory
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
#
# sunshine service script for Batocera (ARM64)
# Functional start/stop/restart/status (update)/uninstall

set -e

# Basic environment for Sunshine
export DISPLAY=:0.0
modprobe fuse 2>/dev/null || true

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

    if [ -x "${app_image}" ]; then
      cd "${app_dir}"

      # Run in foreground (service-style); remove '&' if you want it blocking
      ./sunshine.AppImage > "${log_file}" 2>&1 &
      echo "Sunshine exited with code $?"
    else
      echo "Sunshine.AppImage not found or not executable."
      exit 1
    fi
    ;;

  stop)
    echo "Stopping Sunshine service..."
    pkill -f "sunshine.AppImage" && echo "Sunshine stopped." || echo "Sunshine is not running."
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
      curl -L https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/sunshine/sunshine-arm64.sh | bash
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

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine

echo
dialog --msgbox "Installation complete!\n\nSunshine is configured with software encoder for ARM64.\nConfig: /userdata/system/.config/sunshine/sunshine.conf\n\nPlease head to https://YOUR-MACHINE-IP:47990 to pair Sunshine with Moonlight if this is your first time running Sunshine :)" 12 70
