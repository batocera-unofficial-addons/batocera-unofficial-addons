#!/bin/bash

# Path to the source binary and target symlink
SOURCE_PATH="/userdata/system/add-ons/hydra/usr/bin/aria2c"
TARGET_PATH="/usr/bin/aria2c"

# Function to clean up the symlink and stop aria2c on exit
cleanup() {
    echo "Stopping aria2c and removing symlink..."
    pkill -f "aria2c --enable-rpc" 2>/dev/null
    if [ -L "$TARGET_PATH" ]; then
        rm -f "$TARGET_PATH"
        echo "Symlink removed."
    else
        echo "No symlink to remove."
    fi
}

# Trap EXIT to ensure cleanup runs when the script exits
trap cleanup EXIT

# Create the symlink
if [ -e "$SOURCE_PATH" ]; then
    if [ ! -L "$TARGET_PATH" ]; then
        ln -s "$SOURCE_PATH" "$TARGET_PATH"
        echo "Symlink created: $TARGET_PATH -> $SOURCE_PATH"
    else
        echo "Symlink already exists."
    fi
else
    echo "Source binary not found at $SOURCE_PATH"
    exit 1
fi

# Start aria2c with the required configuration
echo "Starting aria2c with RPC enabled..."
aria2c --enable-rpc --rpc-listen-all=true --rpc-allow-origin-all --rpc-listen-port=6800 &
ARIA2C_PID=$!

# Wait for aria2c to start
sleep 2

# Check if aria2c started successfully
if ps -p $ARIA2C_PID > /dev/null; then
    echo "aria2c is running with PID $ARIA2C_PID."
else
    echo "Failed to start aria2c. Cleaning up..."
    exit 1
fi

# Keep the script running to allow aria2c to run
echo "aria2c is running. Press Ctrl+C to exit."
while true; do
    sleep 1
done
