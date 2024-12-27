
#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://git.sr.ht/~thestr4ng3r/chiaki/refs/download/v2.2.0/Chiaki-v2.2.0-Linux-x86_64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Chiaki AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/chiaki
wget -q --show-progress -O /userdata/system/add-ons/chiaki/Chiaki.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Chiaki AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/chiaki/Chiaki.AppImage
echo "Chiaki AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/chiaki/chiaki-config
mkdir -p /userdata/system/logs

# Step 3: Create the Endless Sky Script
echo "Creating Chiaki script in Ports..."
mkdir -p /userdata/roms/ports
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
    ./Chiaki.AppImage > "${log_file}" 2>&1
    echo "Chiaki exited."
else
    echo "Chiakie not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Chiaki.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Chiaki logo..."
curl -L -o /userdata/roms/ports/images/chiakilogo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/chiaki/extra/chiakilogo.png

echo "Adding logo to Chiaki entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Chiaki.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Chiaki" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/chiakilogo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Chiaki from the Ports menu."

