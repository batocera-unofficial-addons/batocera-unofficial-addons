# Step 1: Fetch the latest release of ShadPS4
echo "Fetching the latest ShadPS4 release..."
latest_release_url=$(curl -s https://api.github.com/repos/shadps4-emu/shadPS4/releases/latest | grep "browser_download_url" | grep "shadps4-linux-qt-.*\.zip" | cut -d '"' -f 4)

if [ -z "$latest_release_url" ]; then
    echo "Failed to retrieve the latest ShadPS4 release URL."
    exit 1
fi

# Step 2: Prepare the installation directory
install_dir="/userdata/system/add-ons/shadps4"
echo "Preparing installation directory at $install_dir..."

if [ -d "$install_dir" ]; then
    echo "ShadPS4 exists. Updating it..."
    rm -rf "$install_dir"
fi

mkdir -p "$install_dir"

# Step 3: Download the zip file
echo "Downloading ShadPS4 zip from $latest_release_url..."
wget -q --showprogress -O "$install_dir/shadps4.zip" "$latest_release_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the ShadPS4 zip file."
    exit 1
fi

# Step 4: Unzip the downloaded file
echo "Unzipping ShadPS4..."
unzip -q "$install_dir/shadps4.zip" -d "$install_dir"

if [ $? -ne 0 ]; then
    echo "Failed to unzip the ShadPS4 file."
    exit 1
fi

# Step 5: Delete the zip file
echo "Cleaning up... Deleting the zip file."
rm -f "$install_dir/shadps4.zip"

# Step 6: Set executable permissions for the AppImage
chmod a+x "$install_dir/Shadps4-qt.AppImage"
echo "ShadPS4 AppImage marked as executable."

# Step 7: Create persistent configuration and log directories
config_dir="$install_dir/shadps4-config"
log_dir="/userdata/system/logs"

if [ -d "$config_dir" ]; then
    echo "Configuration directory $config_dir exists. Deleting and recreating it..."
    rm -rf "$config_dir"
fi

mkdir -p "$config_dir"

if [ ! -d "$log_dir" ]; then
    echo "Log directory $log_dir does not exist. Creating it..."
    mkdir -p "$log_dir"
fi

# Step 8: Create the ShadPS4 Launcher Script
echo "Creating ShadPS4 launcher in Ports..."
ports_dir="/userdata/roms/ports"
launcher="$ports_dir/ShadPS4.sh"

if [ -f "$launcher" ]; then
    echo "Launcher script $launcher exists. Replacing it..."
    rm -f "$launcher"
fi

mkdir -p "$ports_dir"
cat << 'EOF' > "$launcher"
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/shadps4"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=XFCE

# Configure system settings
sysctl -w vm.max_map_count=2097152
ulimit -H -n 819200
ulimit -S -n 819200
ulimit -H -l 61634
ulimit -S -l 61634
ulimit -H -s 61634
ulimit -S -s 61634

# Directories and file paths
app_dir="/userdata/system/add-ons/shadps4"
app_image="${app_dir}/Shadps4-qt.AppImage"

# Launch ShadPS4 AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Shadps4-qt.AppImage
    echo "ShadPS4 exited."
else
    echo "Shadps4-qt.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x "$launcher"

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 9: Download the image
echo "Downloading ShadPS4 logo..."
images_dir="$ports_dir/images"

if [ ! -d "$images_dir" ]; then
    mkdir -p "$images_dir"
fi

curl -L -o "$images_dir/shadps4logo.png" https://github.com/DTJW92/batocera-unofficial-addons/raw/main/shadps4/extra/shadps4logo.png

# Step 10: Add ShadPS4 to gamelist.xml
gamelist="$ports_dir/gamelist.xml"

if [ ! -f "$gamelist" ]; then
    echo "Creating gamelist.xml..."
    echo "<gameList></gameList>" > "$gamelist"
fi

echo "Adding ShadPS4 entry to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./ShadPS4.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "ShadPS4" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/shadps4logo.png" \
  "$gamelist" > "${gamelist}.tmp" && mv "${gamelist}.tmp" "$gamelist"

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch ShadPS4 from the Ports menu."
