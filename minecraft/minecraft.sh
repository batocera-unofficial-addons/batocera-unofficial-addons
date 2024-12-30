#!/bin/bash

# Ensure the dialog utility is installed
if ! command -v dialog &> /dev/null; then
    echo "Error: 'dialog' is not installed. Install it and re-run the script."
    exit 1
fi

# Step 1: Display a dialog menu for the user to select Minecraft Edition
dialog --clear --backtitle "Minecraft Launcher Setup" \
    --title "Select Minecraft Edition" \
    --menu "Choose your Minecraft Edition:" 15 50 2 \
    1 "Java Edition" \
    2 "Bedrock Edition" 2> /tmp/edition_choice.txt

# Read the user's choice from the temporary file
edition_choice=$(< /tmp/edition_choice.txt)
rm -f /tmp/edition_choice.txt

# Check if the user pressed Cancel
if [ -z "$edition_choice" ]; then
    echo "No choice made. Exiting."
    exit 1
fi

# Step 2: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

# Initialize appimage_url variable
appimage_url=""

# Step 3: Set the download URL based on the user's choice and architecture
if [ "$edition_choice" == "1" ]; then
    if [ "$arch" == "x86_64" ]; then
        echo "Java Edition selected for x86_64."
        appimage_url="https://launcherupdates.lunarclientcdn.com/Lunar%20Client-3.3.2-ow.AppImage"
    else
        echo "Java Edition is not supported on this architecture: $arch. Exiting."
        exit 1
    fi
elif [ "$edition_choice" == "2" ]; then
    if [ "$arch" == "x86_64" ]; then
        echo "Bedrock Edition selected for x86_64."
        appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-bookworm-x86_64-v1.0.0.590.AppImage"
    elif [ "$arch" == "aarch64" ]; then
        echo "Bedrock Edition selected for arm64."
        appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-arm64-v1.0.0.590.AppImage"
    else
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
    fi
else
    echo "Invalid choice. Exiting."
    exit 1
fi

# Step 4: Download the AppImage
echo "Downloading AppImage from $appimage_url..."
output_dir="/userdata/system/add-ons/minecraft-${edition_choice,,}"
mkdir -p "$output_dir"
wget -q --show-progress -O "$output_dir/Minecraft_Launcher.AppImage" "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the AppImage. Exiting."
    exit 1
fi

chmod a+x "$output_dir/Minecraft_Launcher.AppImage"
echo "AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p "$output_dir/minecraft-config"
mkdir -p /userdata/system/logs

# Step 5: Create the Launcher Script
echo "Creating Launcher script in Ports..."
mkdir -p /userdata/roms/ports
script_name="Minecraft${edition_choice,,}.sh"

cat << EOF > "/userdata/roms/ports/$script_name"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\\0' '\\n')
export DISPLAY=:0.0
export HOME=$outputdir

# Directories and file paths
app_dir="$output_dir"
app_image="\${app_dir}/Minecraft_Launcher.AppImage"
log_dir="/userdata/system/logs"
log_file="\${log_dir}/minecraft-${edition_choice,,}.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "\$(date): Launching Minecraft ${edition_choice}"\\n

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

chmod +x "/userdata/roms/ports/$script_name"

# Step 6: Add Entry to Ports Menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

echo "Adding Minecraft ${edition_choice} to Ports menu..."
logo_url=""
if [ "$edition_choice" == "1" ]; then
    logo_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-java.png"
else
    logo_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-bedrock-logo.png"
fi

curl http://127.0.0.1:1234/reloadgames

curl -L -o "/userdata/roms/ports/images/minecraft-${edition_choice,,}-logo.png" "$logo_url"
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./$script_name" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Minecraft ${edition_choice}" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/minecraft-${edition_choice,,}-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Minecraft ${edition_choice} from the Ports menu."
