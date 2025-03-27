#!/bin/bash

# Define URLs for install scripts
AMD64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_x86.sh"
ARM64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_arm64.sh"

# Check the filesystem type of /userdata
fstype=$(stat -f -c %T /userdata)

# List of known filesystems that are incompatible or problematic with symlinks
incompatible_types=("vfat" "msdos" "exfat" "cifs" "ntfs")

# Check if the filesystem is in the incompatible list
for type in "${incompatible_types[@]}"; do
    if [[ "$fstype" == "$type" ]]; then
        echo "Error: The file system type '$fstype' on /userdata does not reliably support symlinks. Incompatible."
        exit 1
    fi
done

# If compatible
echo "File system '$fstype' supports symlinks. Continuing..."

# Detect system architecture
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    echo "Detected AMD64 architecture. Executing the install script..."
    curl -Ls "$AMD64" | bash
elif [[ "$ARCH" == "aarch64" ]]; then
    echo "Detected ARM64 architecture. Executing the install script..."
    curl -Ls "$ARM64" | bash
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
