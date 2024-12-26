
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

# Directories and file paths
app_dir="/userdata/system/add-ons/shadps4"
config_dir="${app_dir}/shadps4-config"
config_symlink="${HOME}/.config/shadps4"
app_image="${app_dir}/Shadps4-qt.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/shadps4.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): Launching ShadPS4"

# Create persistent directory for ShadPS4 config
mkdir -p "${config_dir}"
mkdir -p /userdata/roms/ps4

# Move existing config if present
if [ -d "${config_symlink}" ] && [ ! -L "${config_symlink}" ]; then
    mv "${config_symlink}" "${config_dir}"
fi

# Ensure config directory is symlinked
if [ ! -L "${config_symlink}" ]; then
    ln -sf "${config_dir}" "${config_symlink}"
fi

# Symlink .local/share/shadPS4 to the config directory
local_share_dir="${HOME}/.local/share/shadPS4"
if [ ! -L "${local_share_dir}" ]; then
    echo "Creating symlink for .local/share/shadPS4 to shadps4-config"
    ln -sf "${config_dir}" "${local_share_dir}"
fi

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

# Step 9: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch ShadPS4 from the Ports menu."
