#!/bin/bash

# Ensure the dialog utility is installed
if ! command -v dialog &> /dev/null; then
    echo "Error: 'dialog' is not installed. Install it and re-run the script."
    exit 1
fi

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

# Initialize variables
appimage_url=""
app_dir="/userdata/system/add-ons/minecraft/minecraftbedrock"

# Step 2: Set the download URL based on system architecture
if [ "$arch" == "x86_64" ]; then
    echo "Bedrock Edition selected for x86_64."
    appimage_url="https://github.com/minecraft-linux/appimage-builder/releases/download/v1.1.1-802/Minecraft_Bedrock_Launcher-x86_64-v1.1.1.802.AppImage"
elif [ "$arch" == "aarch64" ]; then
    echo "Bedrock Edition selected for arm64."
    appimage_url="https://github.com/minecraft-linux/appimage-builder/releases/download/v1.1.1-802/Minecraft_Bedrock_Launcher-arm64-v1.1.1.802.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 3: Download the AppImage
echo "Downloading Bedrock Edition AppImage from $appimage_url..."
mkdir -p "$app_dir"
wget -q --show-progress -O "$app_dir/Minecraft_Launcher.AppImage" "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the AppImage. Exiting."
    exit 1
fi

chmod a+x "$app_dir/Minecraft_Launcher.AppImage"
echo "AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p "$app_dir/minecraft-config"
mkdir -p /userdata/system/logs

# Step 4: Create the Bedrock Edition Launcher Script
mkdir -p /userdata/roms/ports

echo "Creating Bedrock Edition Launcher script in Ports..."
cat << EOF > "/userdata/roms/ports/MinecraftBedrock.sh"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="$app_dir"

# Directories and file paths
app_dir="$app_dir"
app_image="\${app_dir}/Minecraft_Launcher.AppImage"
log_dir="/userdata/system/logs"
log_file="\${log_dir}/minecraft-bedrock.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\${log_file}")
echo "\$(date): Launching Minecraft Bedrock Edition"

# Launch Minecraft Launcher AppImage
if [ -x "\${app_image}" ]; then
    cd "\${app_dir}"
    ./Minecraft_Launcher.AppImage > "\${log_file}" 2>&1
    echo "Minecraft Launcher exited."
else
    echo "AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x "/userdata/roms/ports/MinecraftBedrock.sh"

# Step 5: Add Entry to Ports Menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

echo "Adding Minecraft Bedrock Edition to Ports menu..."
logo_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-bedrock-logo.png"
entry_name="Minecraft Bedrock Edition"
script_name="MinecraftBedrock.sh"

curl -L -o "/userdata/roms/ports/images/$entry_name-logo.png" "$logo_url"

xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./$script_name" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$entry_name" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/$entry_name-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Minecraft Bedrock Edition from the Ports menu."
