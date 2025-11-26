
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

detect_driver_version() {
    local version=""

    # Try to parse the driver version from the Nvidia log (covers "Production" and other variants)
    if [[ -f /userdata/system/logs/nvidia.log ]]; then
        version=$(
            sed -n 's/.*Using NVIDIA .*driver - \([0-9][0-9.]*\).*/\1/p' /userdata/system/logs/nvidia.log \
            | head -n1 \
            | tr -d '[:space:]'
        )
    fi

    # Fallback to nvidia-smi if the log did not yield a version
    if [[ -z "$version" ]] && command -v nvidia-smi >/dev/null 2>&1; then
        version=$(
            nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null \
            | head -n1 \
            | tr -d '[:space:]' || true
        )
    fi

    echo "$version"
}

# Detect Nvidia GPU and apply patches
if lspci | grep -i "nvidia" > /dev/null; then
    echo "Nvidia GPU detected. Applying patches..."
    
    driver_version=$(detect_driver_version)
    
    # Check if driver version was found
    if [[ -z "$driver_version" ]]; then
        echo "Error: Could not detect Nvidia driver version."
        exit 1
    fi

    echo "Detected Nvidia driver version: $driver_version"
    
    # Download the patch scripts to the temporary directory
    curl -LsS "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/nvidiapatch/patches.sh" -o "$TEMP_DIR/nvidia_patch.sh"

    # Run the patch scripts with the detected driver version
    bash "$TEMP_DIR/nvidia_patch.sh" "$driver_version"
    
elif lspci | grep -i "amd" > /dev/null; then
    echo "AMD GPU detected. Skipping Nvidia patches."
else
    echo "No supported GPU detected. Skipping patches."
fi

# Cleanup the temporary files (this will be done automatically by trap)
