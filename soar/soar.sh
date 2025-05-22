#!/bin/bash

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        SOAR_BINARY="soar-x86_64-linux"
        CONFIG_FILE_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/soar/extra/config.toml"
        ;;
    aarch64)
        SOAR_BINARY="soar-aarch64-linux"
        CONFIG_FILE_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/soar/extra/arm64_config.toml"
        ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Directories
SOAR_BIN_DIR="/userdata/system/add-ons/soar/bin"
SOAR_CONFIG_DIR="/userdata/system/.config/soar"
SOAR_BINARY_PATH="$SOAR_BIN_DIR/soar"

# Ensure directories exist
mkdir -p "$SOAR_BIN_DIR"
mkdir -p "$SOAR_CONFIG_DIR"

# Get latest release tag from GitHub API
LATEST_TAG=$(curl -s https://api.github.com/repos/pkgforge/soar/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
if [ -z "$LATEST_TAG" ]; then
    echo "Failed to fetch the latest Soar release tag."
    exit 1
fi

# Build download URL
SOAR_URL="https://github.com/pkgforge/soar/releases/download/${LATEST_TAG}/${SOAR_BINARY}"

# Download the Soar binary
curl -Lso "$SOAR_BINARY_PATH" "$SOAR_URL"
chmod +x "$SOAR_BINARY_PATH"

# Download the appropriate config file
curl -Lso "$SOAR_CONFIG_DIR/config.toml" "$CONFIG_FILE_URL"

echo "Soar setup completed for $ARCH!"
