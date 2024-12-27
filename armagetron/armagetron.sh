#!/bin/bash

# Step 1: Define the static download URL for Armagetron Advanced
echo "Downloading Armagetron Advanced AppImage..."
appimage_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/armagetron/ArmagetronAdvanced.AppImage"
keys_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/armagetron/Armagetron.sh.keys"

# Step 2: Download the AppImage
mkdir -p /userdata/system/add-ons/armagetron
wget -q -O /userdata/system/add-ons/armagetron/ArmagetronAdvanced.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Armagetron Advanced AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/armagetron/ArmagetronAdvanced.AppImage
echo "Armagetron Advanced AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/armagetron/armagetron-config
mkdir -p /userdata/system/logs

# Step 3: Create the Armagetron Advanced Launcher Script
echo "Creating Armagetron Advanced launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Armagetron.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/armagetron"
config_dir="${app_dir}/armagetron-config"
config_symlink="${HOME}/.config/armagetron"
app_image="${app_dir}/ArmagetronAdvanced.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/armagetron.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Armagetron Advanced"

# Create persistent directory for Armagetron config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Armagetron Advanced AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./ArmagetronAdvanced.AppImage > "${log_file}" 2>&1
    echo "Armagetron Advanced exited."
else
    echo "ArmagetronAdvanced.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Armagetron.sh
wget -q -O /userdata/roms/ports/Armagetron.sh.keys "$keys_url"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Armagetron logo..."
curl -L -o /userdata/roms/ports/images/armagetron-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/armagetron/extra/armagetronlogo.png

echo "Adding logo to Batocera Unofficial Add-ons entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Armagetron.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Armagetron Advanced" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/armagetron-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Armagetron Advanced from the Ports menu."

