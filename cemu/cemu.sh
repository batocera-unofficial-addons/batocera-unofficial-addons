# Step 1: Fetch the latest release of Cemu AppImage
echo "Fetching the latest Cemu AppImage release..."
latest_release_url=$(curl -s https://api.github.com/repos/cemu-project/Cemu/releases/latest | grep "browser_download_url" | grep "AppImage" | cut -d '"' -f 4)

if [ -z "$latest_release_url" ]; then
    echo "Failed to retrieve the latest Cemu release URL."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Cemu AppImage from $latest_release_url..."
mkdir -p /userdata/system/add-ons/cemu
wget -q -O /userdata/system/add-ons/cemu/cemu.AppImage "$latest_release_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Cemu AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/cemu/cemu.AppImage
echo "Cemu AppImage downloaded and marked as executable."

# Step 3: Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/cemu/cemu-config
mkdir -p /userdata/system/logs

# Step 4: Create the Cemu Launcher Script
echo "Creating Cemu launcher in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Cemu.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/cemu"
config_dir="${app_dir}/cemu-config"
config_symlink="${HOME}/.config/cemu"
app_image="${app_dir}/cemu.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/cemu.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Cemu"

# Create persistent directory for Cemu config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Cemu AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./cemu.AppImage > "${log_file}" 2>&1
    echo "Cemu exited."
else
    echo "cemu.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Cemu.sh

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Cemu from the Ports menu."
