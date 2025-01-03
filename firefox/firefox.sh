#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/srevinsaju/Firefox-Appimage/releases/download/firefox/firefox-$(curl https://github.com/srevinsaju/Firefox-Appimage/releases/tag/firefox | grep \">Latest Continous build for firefox v\" | sed 's,^.*Latest Continous build for firefox v,,g' | cut -d \"<\" -f1)-x86_64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Firefox AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/firefox
wget -q --show-progress -O /userdata/system/add-ons/firefox/Firefox.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Firefox AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/firefox/Firefox.AppImage
echo "Firefox AppImage downloaded and marked as executable."

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the Firefox Script
echo "Creating Firefox script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Firefox.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/firefox"

# Directories and file paths
app_dir="/userdata/system/add-ons/firefox"
app_image="${app_dir}/Firefox.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/firefox.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Firefox"

# Launch Firefox AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Firefox.AppImage "$@" > "${log_file}" 2>&1
    echo "Firefox exited."
else
    echo "Firefox.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Firefox.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Firefox logo..."
curl -L -o /userdata/roms/ports/images/firefox-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/firefox/extra/firefox-logo.png
echo "Adding logo to Firefox entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Firefox.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Firefox" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/firefox-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Firefox from the Ports menu."
