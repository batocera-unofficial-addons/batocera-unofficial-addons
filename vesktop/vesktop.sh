#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/Vencord/Vesktop/releases/download/v1.5.4/Vesktop-1.5.4.AppImage"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    appimage_url="https://github.com/Vencord/Vesktop/releases/download/v1.5.4/Vesktop-1.5.4-arm64.AppImage"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download the AppImage
echo "Downloading Vesktop AppImage from $appimage_url..."
mkdir -p /userdata/system/add-ons/vesktop
wget -q --show-progress -O /userdata/system/add-ons/vesktop/Vesktop.AppImage "$appimage_url"

if [ $? -ne 0 ]; then
    echo "Failed to download the Vesktop AppImage."
    exit 1
fi

chmod a+x /userdata/system/add-ons/vesktop/Vesktop.AppImage
echo "Vesktop AppImage downloaded and marked as executable."

# Create persistent configuration and log directories
mkdir -p /userdata/system/add-ons/vesktop/vesktop-config
mkdir -p /userdata/system/logs
mkdir -p /userdata/system/add-ons/vesktop/lib

# Step 3: Create the Vesktop Launcher Script
echo "Creating Vesktop launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Vesktop.sh
#!/bin/bash

# Function to download libcups.so.2 if not present
download_libcups() {
    libcups_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/vesktop/lib/libcups.so.2"
    libcups_dest="/userdata/system/add-ons/vesktop/lib/libcups.so.2"

    # Check if the file already exists
    if [ ! -f "$libcups_dest" ]; then
        echo "$(date): libcups.so.2 not found, downloading..."
        wget -q --show-progress -O "$libcups_dest" "$libcups_url"

        if [ $? -eq 0 ]; then
            echo "$(date): libcups.so.2 downloaded successfully."
        else
            echo "$(date): Failed to download libcups.so.2."
            exit 1
        fi
    else
        echo "$(date): libcups.so.2 already exists, skipping download."
    fi
}

# Call the function to download libcups
download_libcups

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0

# Directories and file paths
app_dir="/userdata/system/add-ons/vesktop"
config_dir="${app_dir}/vesktop-config"
config_symlink="${HOME}/.config/vesktop"
app_image="${app_dir}/Vesktop.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/vesktop.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching Vesktop"

# Create persistent directory for Vesktop config
mkdir -p "${config_dir}"

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Launch Vesktop AppImage
if [ -x "${app_image}" ]; then
    echo "$(date): AppImage is executable, launching..."
    cd "${app_dir}"
    ./Vesktop.AppImage --no-sandbox > "${log_file}" 2>&1
    echo "$(date): Vesktop exited."
else
    echo "$(date): Vesktop.AppImage not found or not executable."
    exit 1
fi

EOF

chmod +x /userdata/roms/ports/Vesktop.sh

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Vesktop from the Ports menu."

