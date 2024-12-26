#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" != "x86_64" ]; then
    echo "Unsupported architecture: $arch. Steam is only available for x86_64. Exiting."
    exit 1
fi

echo "Architecture: x86_64 detected."

# Step 2: Fetch the latest Steam AppImage release
echo "Fetching the latest Steam AppImage release..."
release_url="https://api.github.com/repos/ivan-hc/Steam-appimage/releases/tags/continuous"
appimage_url=$(curl -s "$release_url" | grep "browser_download_url" | grep -E "\.AppImage$" | cut -d '"' -f 4)

if [ -z "$appimage_url" ]; then
    echo "Failed to retrieve the latest Steam AppImage URL."
    exit 1
fi

echo "Latest Steam AppImage URL: $appimage_url"

# Step 3: Download the Steam AppImage
echo "Downloading Steam AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/steam
wget -q --show-progress -O /userdata/system/add-ons/steam/Steam.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Steam AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/steam/Steam.AppImage
echo "Steam AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/steam/steam-config
mkdir -p /userdata/system/logs

# Step 4: Create the Steam Launcher Script
echo "Creating Steam launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Steam.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/steam"
config_dir="${app_dir}/steam-config"
config_symlink="${HOME}/.config/steam"
app_image="${app_dir}/Steam.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/steam.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Steam"

# Create persistent directory for Steam config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Steam AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Steam.AppImage > "${log_file}" 2>&1
    echo "Steam exited."
else
    echo "Steam.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Steam.sh

# Step 5: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Steam from the Ports menu."
