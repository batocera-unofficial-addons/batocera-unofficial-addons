#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/ivan-hc/Chrome-appimage/releases/download/continuous/Google-Chrome-stable-131.0.6778.204-1-x86_64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Google Chrome AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/google-chrome
wget -q --show-progress -O /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Google Chrome AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/google-chrome/GoogleChrome.AppImage
echo "Google Chrome AppImage downloaded and marked as executable."

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the Google Chrome Script
echo "Creating Google Chrome script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/GoogleChrome.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/google-chrome"

# Directories and file paths
app_dir="/userdata/system/add-ons/google-chrome"
app_image="${app_dir}/GoogleChrome.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/google-chrome.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Google Chrome"


# Launch Google Chrome AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./GoogleChrome.AppImage > "${log_file}" 2>&1
    echo "Google Chrome exited."
else
    echo "GoogleChrome.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/GoogleChrome.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Google Chrome from the Ports menu."
