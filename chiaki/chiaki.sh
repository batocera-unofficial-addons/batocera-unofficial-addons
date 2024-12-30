#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/streetpea/chiaki-ng/releases/download/v1.9.3/chiaki-ng.AppImage_x86_64"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: ARM64 detected."
    appimage_url="https://github.com/streetpea/chiaki-ng/releases/download/v1.9.3/chiaki-ng.AppImage_arm64"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi


# Step 2: Prepare directories
echo "Setting up directories..."
mkdir -p /userdata/system/add-ons/chiaki
mkdir -p /userdata/system/add-ons/chiaki/chiaki-config
mkdir -p /userdata/system/logs
mkdir -p /userdata/roms/ports/images

# Step 3: Download the AppImage
echo "Downloading Chiaki AppImage..."
wget -q --show-progress -O /userdata/system/add-ons/chiaki/Chiaki.AppImage "$appimage_url"
if [ $? -ne 0 ]; then
    echo "Failed to download Chiaki AppImage. Exiting."
    exit 1
fi

chmod a+x /userdata/system/add-ons/chiaki/Chiaki.AppImage
echo "Chiaki AppImage downloaded and marked as executable."

# Step 4: Create the Chiaki launch script
echo "Creating Chiaki launch script in Ports..."
cat << 'EOF' > /userdata/roms/ports/Chiaki.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/chiaki"
config_dir="${app_dir}/chiaki-config"
config_symlink="${HOME}/.config/chiaki"
app_image="${app_dir}/Chiaki.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/chiaki.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Chiaki"

# Create persistent directory for Chiaki config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Chiaki AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Chiaki.AppImage > "${log_file}" 2>&1
    echo
fi
EOF

chmod +x /userdata/roms/ports/Chiaki.sh

# Step 5: Add Chiaki to Ports menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

echo "Adding Chiaki to Ports menu..."
curl -L -o /userdata/roms/ports/images/chiakilogo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/chiaki/extra/chiakilogo.png
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Chiaki.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Chiaki" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/chiakilogo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

# Step 6: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Chiaki from the Ports menu."
