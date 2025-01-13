#!/bin/bash

# Define paths
SOURCE="/userdata/system/add-ons/fightcade/usr/bin/wine"
SYMLINK="/usr/bin/wine"

# Create the symlink
echo "Creating symlink: $SYMLINK -> $SOURCE"
ln -sf "$SOURCE" "$SYMLINK"

# Trap EXIT signal to clean up
cleanup() {
    echo "Removing symlink: $SYMLINK"
    rm -f "$SYMLINK"
}
trap cleanup EXIT

# Function to check if fc2-electron is running
is_fc2_electron_running() {
    pgrep -x "fc2-electron" > /dev/null 2>&1
}

# Main loop
sleep 5
echo "Symlink created. Monitoring fc2-electron process..."
while true; do
    if is_fc2_electron_running; then
        # Process is running
        echo "fc2-electron is running."
    else
        # Process is not running, exit the loop
        echo "fc2-electron is not running. Exiting script."
        break
    fi
    # Wait for a few seconds before checking again
    sleep 5
done

# Cleanup will be triggered automatically
echo "Script exiting. Symlink will be removed."
