
# Step 1: Install Sunshine
echo "Installing Sunshine..."
mkdir -p /userdata/system/add-ons/sunshine
wget -q -O /userdata/system/add-ons/sunshine/sunshine.AppImage  https://github.com/DTJW92/batocera-unofficial-addons/raw/main/sunshine/sunshine.AppImage

chmod a+x /userdata/system/add-ons/sunshine/sunshine.AppImage

# Create a persistent configuration directory
mkdir -p /userdata/system/add-ons/sunshine
mkdir -p /userdata/system/logs

# Configure Sunshine as a service
echo "Configuring Sunshine service..."
mkdir -p /userdata/system/services
cat << 'EOF' > /userdata/system/services/sunshine
#!/bin/bash
#
# sunshine service script for Batocera
# Functional start/stop/restart/status (update)/uninstall

# Environment setup
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/sunshine

# Directories and file paths
app_dir="/userdata/system/add-ons/sunshine"
app_image="${app_dir}/sunshine.AppImage"
log_dir="/userdata/system/logs"
log_file="${log_dir}/sunshine.log"

# Ensure log directory exists
mkdir -p "${log_dir}"

create_symlinks() {
    # Define the source directory for patched files
    local nvdir="/userdata/system/add-ons/sunshine/nvidia/$version"

    # Check if the directory exists
    if [[ ! -d "$nvdir" ]]; then
        echo "##   "
        echo "##   Patched drivers directory ($nvdir) does not exist."
        echo "##   If you're using an AMD GPU, you can safely ignore this."
        echo "##   "
        return 1
    fi

    echo "##   Creating symlinks for patched NVIDIA files in /usr ..."

    # List of libraries and binaries to link
    local files=(
        "libnvidia-encode.so"
        "libnvidia-encode.so.*"
        "libnvidia-fbc.so"
        "libnvidia-fbc.so.*"
        "nvidia-smi"
        "nvidia-settings"
        "libnvidia-gtk*.so"
    )

    # Create symlinks
    for file in "${files[@]}"; do
        for source_file in "$nvdir"/$file; do
            if [[ -f "$source_file" || -L "$source_file" ]]; then
                # Determine destination
                local dest
                if [[ "$source_file" == *nvidia-smi || "$source_file" == *nvidia-settings ]]; then
                    dest="/usr/bin/$(basename "$source_file")"
                else
                    dest="/usr/lib/$(basename "$source_file")"
                fi

                # Remove existing file or symlink at destination
                if [[ -e "$dest" || -L "$dest" ]]; then
                    rm -f "$dest"
                fi

                # Create symlink
                ln -s "$source_file" "$dest"
                echo "##   Linked $source_file -> $dest"
            fi
        done
    done

    echo "##   Symlinks created successfully."
    return 0
}


# Append all output to the log file
exec &> >(tee -a "$log_file")
echo "$(date): ${1} service sunshine"

case "$1" in
    start)
        echo "Starting Sunshine service..."

create_symlinks

        # Start Sunshine AppImage
        if [ -x "${app_image}" ]; then
            cd "${app_dir}"
            ./sunshine.AppImage > "${log_file}" 2>&1 &
            echo "Sunshine started successfully."
        else
            echo "Sunshine.AppImage not found or not executable."
            exit 1
        fi
        ;;
    stop)
        echo "Stopping Sunshine service..."
        # Stop the specific processes for sunshine.AppImage
        pkill -f "./sunshine.AppImage" && echo "Sunshine stopped." || echo "Sunshine is not running."
        pkill -f "/tmp/.mount_sunshi" && echo "Sunshine child process stopped." || echo "Sunshine child process is not running."
        ;;
restart)
    "$0" stop
    "$0" start
    ;;
    status)
        if pgrep -f "sunshine.AppImage" > /dev/null; then
            echo "Sunshine is running."
            exit 0
        else
            echo "Sunshine is stopped. Going to update now"
            curl -L https://bit.ly/BatoceraSunshine | bash
            exit 1
        fi
        ;;
    uninstall)
        echo "Uninstalling Sunshine service..."
        "$0" stop
        rm -f "${app_image}"
        echo "Sunshine uninstalled successfully."
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status(update)|uninstall}"
        exit 1
        ;;
esac

exit $?

EOF

chmod +x /userdata/system/services/sunshine

echo "Applying Nvidia patches for a smoother experience..."
# Apply Nvidia patches if necessary
curl -L https://github.com/DTJW92/batocera-unofficial-addons/raw/main/nvidiapatch/nvidiapatch.sh | bash

# Enable and start the Sunshine service
batocera-services enable sunshine
batocera-services start sunshine


echo 
echo
echo "Installation complete! Please head to https://YOUR-MACHINE-IP:47990 to pair
Sunshine with Moonlight if this is your first time running Sunshine :)"
echo
echo
