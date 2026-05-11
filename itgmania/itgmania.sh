#!/bin/bash

# Variables
install_dir="/userdata/system/add-ons/itgmania"
ports_dir="/userdata/roms/ports"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/itgmania"

# Get latest ITGMania release URL
echo "Fetching latest ITGMania release..."
itgmania_url=$(curl -s https://api.github.com/repos/ITGmania/ITGmania/releases/latest \
    | grep browser_download_url \
    | grep "Linux\.tar\.gz" \
    | grep -v "no-songs" \
    | cut -d '"' -f 4)

if [ -z "$itgmania_url" ]; then
    echo "Failed to fetch ITGMania release URL. Please check your internet connection."
    exit 1
fi

# Prepare install directory
echo "Setting up installation directory at $install_dir..."
rm -rf "$install_dir"
mkdir -p "$install_dir"

# Download and extract
echo "Downloading ITGMania..."
wget -q --show-progress -O "$install_dir/itgmania.tar.gz" "$itgmania_url"

if [ $? -ne 0 ]; then
    echo "Failed to download ITGMania."
    exit 1
fi

echo "Extracting..."
tar -xzf "$install_dir/itgmania.tar.gz" -C "$install_dir" --strip-components=2
rm -f "$install_dir/itgmania.tar.gz"
chmod +x "$install_dir/itgmania"

# Create ports launcher
echo "Creating ports launcher..."
mkdir -p "$ports_dir/images"
cat << 'PORTSCRIPT' > "$ports_dir/ITGMania.sh"
#!/bin/bash
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/itgmania"
cd /userdata/system/add-ons/itgmania
./itgmania
PORTSCRIPT
chmod +x "$ports_dir/ITGMania.sh"

# Download logo and update gamelist
echo "Downloading logo..."
curl -L -o "$ports_dir/images/itgmania-logo.png" "$base_url/extra/itgmania-logo.png"

echo "Updating gamelist..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./ITGMania.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "ITGMania" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/itgmania-logo.png" \
  "$ports_dir/gamelist.xml" > "$ports_dir/gamelist.xml.tmp" && mv "$ports_dir/gamelist.xml.tmp" "$ports_dir/gamelist.xml"
curl -s http://127.0.0.1:1234/reloadgames

echo "ITGMania installation complete."
killall -9 emulationstation
