#!/bin/bash

# Ensure the dialog utility is installed
if ! command -v dialog &> /dev/null; then
    echo "Error: 'dialog' is not installed. Install it and re-run the script."
    exit 1
fi

# Step 1: Display a dialog menu for the user to select Minecraft Edition
edition_choice=$(dialog --stdout --clear --backtitle "Minecraft Launcher Setup" \
    --title "Select Minecraft Edition" \
    --menu "Choose your Minecraft Edition:" 15 50 4 \
    1 "Java Edition (Lunar Client)" \
    2 "Eaglercraft (Online and FREE)" \
    3 "Official Java Edition (Controller Support)" \
    4 "Bedrock Edition")

clear

# Check if the user pressed Cancel
if [ -z "$edition_choice" ]; then
    echo "No choice made. Exiting."
    exit 1
fi

# Step 2: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

# Initialize variables
appimage_url=""

# Step 3: Set the download URL based on the user's choice and architecture
if [ "$edition_choice" == "1" ]; then
    if [ "$arch" == "x86_64" ]; then
        echo "Java Edition selected for x86_64."
        appimage_url="https://launcherupdates.lunarclientcdn.com/Lunar%20Client-3.3.2-ow.AppImage"
        app_dir="/userdata/system/add-ons/minecraft/minecraftjava"
    else
        echo "Java Edition is not supported on this architecture: $arch. Exiting."
        exit 1
    fi
elif [ "$edition_choice" == "2" ]; then
    echo "Eaglercraft selected."
    appimage_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/minecraft/minecraft_3.sh"
    app_dir="/userdata/system/add-ons/minecraft/minecraft-eaglercraft"
elif [ "$edition_choice" == "3" ]; then
    appimage_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/minecraft/minecraft_2.sh"
    app_dir="/userdata/system/add-ons/minecraft/"
elif [ "$edition_choice" == "4" ]; then
    if [ "$arch" == "x86_64" ]; then
        echo "Bedrock Edition selected for x86_64."
        appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-bookworm-x86_64-v1.0.0.590.AppImage"
        app_dir="/userdata/system/add-ons/minecraft/minecraftbedrock"
    elif [ "$arch" == "aarch64" ]; then
        echo "Bedrock Edition selected for arm64."
        appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-arm64-v1.0.0.590.AppImage"
        app_dir="/userdata/system/add-ons/minecraft/minecraftbedrock"
    else
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
    fi
fi

# Step 4: Download or Run the AppImage
if [ "$edition_choice" == "2" ] || [ "$edition_choice" == "3" ]; then
    echo "Running the script directly from $appimage_url..."
    curl -L $appimage_url | bash
    if [ $? -ne 0 ]; then
        echo "Failed to execute the script from $appimage_url. Exiting."
        exit 1
    fi
else
    echo "Downloading AppImage from $appimage_url..."
    mkdir -p "$app_dir"
    wget -q --show-progress -O "$app_dir/Minecraft_Launcher.AppImage" "$appimage_url"

    if [ $? -ne 0 ]; then
        echo "Failed to download the AppImage. Exiting."
        exit 1
    fi

    chmod a+x "$app_dir/Minecraft_Launcher.AppImage"
    echo "AppImage downloaded and marked as executable."
fi

# Create persistent configuration and log directories
mkdir -p "$app_dir/minecraft-config"
mkdir -p /userdata/system/logs

# Step 5: Create the Launcher Scripts
mkdir -p /userdata/roms/ports

if [ "$edition_choice" == "1" ]; then
    echo "Creating Java Edition Launcher script in Ports..."
    cat << EOF > "/userdata/roms/ports/MinecraftJava.sh"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="$app_dir"

# Directories and file paths
app_dir="$app_dir"
app_image="\${app_dir}/Minecraft_Launcher.AppImage"
log_dir="/userdata/system/logs"
log_file="\${log_dir}/minecraft-java.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\${log_file}")
echo "\$(date): Launching Minecraft Java Edition"

# Launch Minecraft Launcher AppImage
if [ -x "\${app_image}" ]; then
    cd "\${app_dir}"
    ./Minecraft_Launcher.AppImage --no-sandbox > "\${log_file}" 2>&1
    echo "Minecraft Launcher exited."
else
    echo "AppImage not found or not executable."
    exit 1
fi
EOF
    chmod +x "/userdata/roms/ports/MinecraftJava.sh"

elif [ "$edition_choice" == "3" ]; then
    echo "Creating Minecraft Launcher script in Ports..."
    cat << EOF > "/userdata/roms/ports/Minecraft.sh"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="$app_dir"

# Directories and file paths
app_dir="$app_dir"
app_image="\${app_dir}/Minecraft"
log_dir="/userdata/system/logs"
log_file="\${log_dir}/minecraft-custom.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\${log_file}")
echo "\$(date): Launching Minecraft"

# Launch Minecraft Launcher AppImage
if [ -x "\${app_image}" ]; then
    cd "\${app_dir}"
    ./Minecraft > "\${log_file}" 2>&1
    echo "Minecraft Launcher exited."
else
    echo "AppImage not found or not executable."
    exit 1
fi
EOF
    chmod +x "/userdata/roms/ports/Minecraft.sh"

elif [ "$edition_choice" == "4" ]; then
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
fi

# Step 6: Add Entry to Ports Menu
if ! command -v xmlstarlet &> /dev/null; then
    echo "Error: xmlstarlet is not installed. Install it and re-run the script."
    exit 1
fi

curl http://127.0.0.1:1234/reloadgames

if [ "$edition_choice" == "1" ]; then
    echo "Adding Minecraft Java Edition to Ports menu..."
    logo_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-java-logo.png"
    entry_name="Minecraft Java Edition"
    script_name="MinecraftJava.sh"
elif [ "$edition_choice" == "3" ]; then
    echo "Adding Minecraft to Ports menu..."
    logo_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-logo.png"
    entry_name="Minecraft"
    script_name="Minecraft.sh"
elif [ "$edition_choice" == "4" ]; then
    echo "Adding Minecraft Bedrock Edition to Ports menu..."
    logo_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/minecraft/extra/minecraft-bedrock-logo.png"
    entry_name="Minecraft Bedrock Edition"
    script_name="MinecraftBedrock.sh"
fi

curl -L -o "/userdata/roms/ports/images/$entry_name-logo.png" "$logo_url"
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./$script_name" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$entry_name" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/$entry_name-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Minecraft from the Ports menu."
