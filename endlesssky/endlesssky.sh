#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/endless-sky/endless-sky/releases/download/v0.10.10/Endless_Sky-v0.10.10-x86_64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Endless Sky AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/endless-sky
wget -q --show-progress -O /userdata/system/add-ons/endless-sky/EndlessSky.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Endless Sky AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/endless-sky/EndlessSky.AppImage
echo "Endless Sky AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/endless-sky/endless-sky-config
mkdir -p /userdata/system/logs

# Step 3: Create the Endless Sky Script
echo "Creating Endless Sky script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/EndlessSky.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/endless-sky"
config_dir="${app_dir}/endless-sky-config"
config_symlink="${HOME}/.config/endless-sky"
app_image="${app_dir}/EndlessSky.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/endless-sky.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Endless Sky"

# Create persistent directory for Endless Sky config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Endless Sky AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./EndlessSky.AppImage > "${log_file}" 2>&1
    echo "Endless Sky exited."
else
    echo "EndlessSky.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/EndlessSky.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Endless Sky from the Ports menu."

