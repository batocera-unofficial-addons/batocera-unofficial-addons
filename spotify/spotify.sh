#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://api.github.com/repos/ivan-hc/Spotify-appimage/releases/latest | jq -r ".assets[] | select(.name | endswith(\"x86_64.AppImage\")) | .browser_download_url")
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Spotify AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/spotify
wget -q --show-progress -O /userdata/system/add-ons/spotify/Spotify.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download Spotify AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/spotify/Spotify.AppImage
echo "Spotify AppImage downloaded and marked as executable."

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the Spotify Script
echo "Creating Spotify script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Spotify.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/spotify"

# Directories and file paths
app_dir="/userdata/system/add-ons/spotify"
app_image="${app_dir}/Spotify.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/spotify.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Spotify"

# Launch Spotify AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Spotify.AppImage --no-sandbox --test-type "$@" > "${log_file}" 2>&1
    echo "Spotify exited."
else
    echo "Spotify.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/Spotify.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Spotify logo..."
curl -L -o /userdata/roms/ports/images/spotify-logo.jpg https://github.com/DTJW92/batocera-unofficial-addons/raw/main/spotify/extra/spotify-logo.jpg

# Download the key file
echo "Downloading Spotify key file..."
curl -L -o /userdata/roms/ports/Spotify.sh.keys https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/spotify/extra/Spotify.sh.keys

echo "Adding logo to Spotify entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Spotify.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Spotify" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/spotify-logo.jpg" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Spotify from the Ports menu."
