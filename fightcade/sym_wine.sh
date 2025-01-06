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

# Run your main logic here
echo "Symlink created. Running main logic..."
sleep 10  # Replace this with your actual logic or commands

# Script will automatically remove the symlink when it exits
echo "Script exiting. Symlink will be removed."
