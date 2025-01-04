#!/bin/bash

# Define source and target directories
SRC_DIR="/userdata/system/add-ons/heroic/share/zenity"
TARGET_DIR="/usr/share/zenity"

# Check if source directory exists
if [ ! -d "$SRC_DIR" ]; then
  echo "Source directory $SRC_DIR does not exist. Exiting."
  exit 1
fi

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
  echo "Target directory $TARGET_DIR does not exist. Creating it."
  mkdir -p "$TARGET_DIR"
fi

# Loop through all files in the source directory
for file in "$SRC_DIR"/*; do
  # Get the base name of the file
  base_name=$(basename "$file")
  # Create the symlink in the target directory
  ln -sf "$file" "$TARGET_DIR/$base_name"
  echo "Symlinked $file to $TARGET_DIR/$base_name"
done

echo "All files symlinked successfully."
