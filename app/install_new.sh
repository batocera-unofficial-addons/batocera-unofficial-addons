#!/bin/bash

# URLs
AMD64="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/app/install_x86_new.sh"
ARM64="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/app/install_arm64_new.sh"

# Filesystem check
fstype=$(stat -f -c %T /userdata)
incompatible_types=("vfat" "msdos" "exfat" "cifs" "ntfs")

for type in "${incompatible_types[@]}"; do
    if [[ "$fstype" == "$type" ]]; then
        echo -e "\e[31mError:\e[0m The file system type '$fstype' on /userdata does not reliably support symlinks. Incompatible."
        exit 1
    fi
done

echo -e "\e[32mFile system '$fstype' supports symlinks. Continuing...\e[0m"

# Architecture detection
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    echo "Detected AMD64 architecture. Executing the install script..."
    curl -Ls "$AMD64" | bash
elif [[ "$ARCH" == "aarch64" ]]; then
    echo "Detected ARM64 architecture. Executing the install script..."
    curl -Ls "$ARM64" | bash
else
    echo -e "\e[31mUnsupported architecture:\e[0m $ARCH"
    exit 1
fi
