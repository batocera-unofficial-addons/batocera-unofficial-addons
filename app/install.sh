#!/bin/bash

# Define URLs for install scripts
AMD64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_x86.sh"
ARM64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_arm64.sh"

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
