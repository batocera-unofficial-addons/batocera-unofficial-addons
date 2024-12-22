#!/bin/bash

# Step 1: Fetch the latest release of Berry OS AppImage
echo "Fetching the latest Berry OS AppImage release..."
latest_release_url=$(curl -s https://api.github.com/repos/yui0/berry-os/releases/latest | grep "browser_download_url" | grep "AppImage" | cut -d '"' -f 4)

if [ -z "$latest_release_url" ]; then
    echo "Failed to retrieve the latest Berry OS release URL."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Berry OS AppImage from $latest_release_url..."
mkdir -p /userdata/system/add-ons/berry-os
wget -q -O /userdata/system/add-ons/berry-os/berry-os.AppImage "$latest_release_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Berry OS AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/berry-os/berry-os.AppImage
echo "Berry OS AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/berry-os/berry-os-config
mkdir -p /userdata/system/logs

# Step 3: Create the Berry OS Launcher Script
echo "Creating Berry OS launcher in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/BerryOS.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/berry-os"
app_image="${app_dir}/berry-os.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/berry-os.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Berry OS"

# Launch Berry OS AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./berry-os.AppImage > "${log_file}" 2>&1
    echo "Berry OS exited."
else
    echo "Berry OS AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/BerryOS.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Berry OS from the Ports menu."
