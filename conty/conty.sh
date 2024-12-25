#!/bin/bash

# Variables
CONTY_DIR="/userdata/system/add-ons/conty/bin"
CONTY_URL="https://github.com/Kron4ek/Conty/releases/latest/download/conty.sh"
CONTY_BIN="/usr/bin/conty"

# Create directory if it doesn't exist
mkdir -p "$CONTY_DIR"

# Download the latest version of conty.sh
echo "Downloading the latest version of conty..."
curl -L -o "$CONTY_DIR/conty.sh" "$CONTY_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "Failed to download conty.sh. Exiting."
    exit 1
fi

# Make conty.sh executable
chmod +x "$CONTY_DIR/conty.sh"

# Create symlink only if it doesn't already exist
if [ ! -L "$CONTY_BIN" ]; then
    echo "Creating symlink in /usr/bin..."
    ln -s "$CONTY_DIR/conty.sh" "$CONTY_BIN"
    echo "Symlink created: $CONTY_BIN -> $CONTY_DIR/conty.sh"
else
    echo "Symlink already exists at $CONTY_BIN. Skipping."
fi

echo "Conty setup completed!"

