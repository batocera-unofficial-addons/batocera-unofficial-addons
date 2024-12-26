#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-bookworm-x86_64-v1.0.0.590.AppImage"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    appimage_url="https://github.com/minecraft-linux/mcpelauncher-manifest/releases/download/nightly/Minecraft_Bedrock_Launcher-arm64-v1.0.0.590.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Minecraft Bedrock Launcher nightly AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/minecraft-bedrock
wget -q --show-progress -O /userdata/system/add-ons/minecraft-bedrock/Minecraft_Bedrock_Launcher.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Minecraft Bedrock Launcher nightly AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/minecraft-bedrock/Minecraft_Bedrock_Launcher.AppImage
echo "Minecraft Bedrock Launcher nightly AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/minecraft-bedrock/minecraft-bedrock-config
mkdir -p /userdata/system/logs

# Step 3: Create the Minecraft Bedrock Launcher Script
echo "Creating Minecraft Bedrock Launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/MinecraftBedrock.sh
#!/bin/bash

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0

# Directories and file paths
app_dir="/userdata/system/add-ons/minecraft-bedrock"
config_dir="${app_dir}/minecraft-bedrock-config"
config_symlink="${HOME}/.config/minecraft-bedrock"
app_image="${app_dir}/Minecraft_Bedrock_Launcher.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/minecraft-bedrock.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Minecraft Bedrock Launcher"

# Create persistent directory for Minecraft config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Minecraft Bedrock Launcher AppImage
if [ -x "${app_image}" ]; then
    cd "${app_dir}"
    ./Minecraft_Bedrock_Launcher.AppImage > "${log_file}" 2>&1
    echo "Minecraft Bedrock Launcher exited."
else
    echo "Minecraft_Bedrock_Launcher.AppImage not found or not executable."
    exit 1
fi
EOF

chmod +x /userdata/roms/ports/MinecraftBedrock.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Minecraft Bedrock Launcher from the Ports menu."
