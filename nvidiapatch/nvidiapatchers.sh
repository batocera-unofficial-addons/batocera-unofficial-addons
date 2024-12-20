
#!/bin/bash

# Halt on error
set -euo pipefail

# Create a temporary directory for downloading the scripts
TEMP_DIR=$(mktemp -d)

# Function to clean up the temporary files
cleanup() {
    echo "Cleaning up..."
    rm -rf "$TEMP_DIR"
}

# Trap to clean up in case of exit or error
trap cleanup EXIT

# Detect Nvidia GPU and apply patches
if lspci | grep -i "nvidia" > /dev/null; then
    echo "Nvidia GPU detected. Applying patches..."
    
    # Extract the Nvidia driver version from the log
    driver_version=$(grep "Using NVIDIA Production driver" /userdata/system/logs/nvidia.log | awk -F " - " '{print $2}' | tr -d '[:space:]')
    
    # Check if driver version was found
    if [[ -z "$driver_version" ]]; then
        echo "Error: Could not detect Nvidia driver version."
        exit 1
    fi

    echo "Detected Nvidia driver version: $driver_version"
    
    # Download the patch scripts to the temporary directory
    curl -L "https://github.com/DTJW92/Remote-desktop/raw/main/batocera-sunshine-nvidia-patcher.sh" -o "$TEMP_DIR/nvidia_patch.sh"

    # Run the patch scripts with the detected driver version
    bash "$TEMP_DIR/nvidia_patch.sh" "$driver_version"
    
elif lspci | grep -i "amd" > /dev/null; then
    echo "AMD GPU detected. Skipping Nvidia patches."
else
    echo "No supported GPU detected. Skipping patches."
fi

# Cleanup the temporary files (this will be done automatically by trap)
