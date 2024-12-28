
# Step 1: Fetch the latest release of ShadPS4
echo "Fetching the latest ShadPS4 release..."
latest_release_url=$(curl -s https://api.github.com/repos/shadps4-emu/shadPS4/releases/latest | grep "browser_download_url" | grep "shadps4-linux-qt-.*\.zip" | cut -d '"' -f 4)

if [ -z "$latest_release_url" ]; then
    echo "Failed to retrieve the latest ShadPS4 release URL."
    exit 1
fi

# Step 2: Download the zip file
echo "Downloading ShadPS4 zip from $latest_release_url..."
mkdir -p /userdata/system/add-ons/shadps4
wget -q -O /userdata/system/add-ons/shadps4/shadps4.zip "$latest_release_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the ShadPS4 zip file."
    exit 1
fi

# Step 3: Unzip the downloaded file
echo "Unzipping ShadPS4..."
unzip -q /userdata/system/add-ons/shadps4/shadps4.zip -d /userdata/system/add-ons/shadps4

if [ $? -ne 0 ]; then
    echo "Failed to unzip the ShadPS4 file."
    exit 1
fi

# Step 5: Delete the zip file and extracted folder
echo "Cleaning up... Deleting the zip file and extracted folder."
rm -rf /userdata/system/add-ons/shadps4/shadps4.zip

# Step 6: Set executable permissions for the AppImage
chmod a+x /userdata/system/add-ons/shadps4/Shadps4-qt.AppImage
echo "ShadPS4 AppImage moved and marked as executable."

# Step 7: Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/shadps4/shadps4-config
mkdir -p /userdata/system/logs

# Step 8: Create the ShadPS4 Launcher Script
echo "Creating ShadPS4 launcher in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/ShadPS4.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/shadps4

# Directories and file paths
app_dir="/userdata/system/add-ons/shadps4"
app_image="${app_dir}/Shadps4-qt.AppImage"

# Launch ShadPS4 AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Shadps4-qt.AppImage > "${log_file}" 2>&1
    echo "ShadPS4 exited."
else
    echo "Shadps4-qt.AppImage not found or not executable."
    exit 1
fi


EOF

chmod +x /userdata/roms/ports/ShadPS4.sh

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading ShadPS4 logo..."
curl -L -o /userdata/roms/ports/images/shadps4logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/shadps4/extra/shadps4logo.png

echo "Adding logo to ShadPS4 entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./ShadPS4.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "ShadPS4" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/shadps4logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml


curl http://127.0.0.1:1234/reloadgames


echo
echo "Installation complete! You can now launch ShadPS4 from the Ports menu."
