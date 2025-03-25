#!/bin/bash
# Get the machine hardware name
architecture=$(uname -m)

# Check if the architecture is x86_64 (AMD/Intel)
if [ "$architecture" != "x86_64" ]; then
    echo "This script only runs on AMD or Intel (x86_64) CPUs, not on $architecture."
    exit 1
fi

# Define variables
DESTINATION_DIR="$HOME"
FILENAME="cli.tar.xz"
DOWNLOAD_URL="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/cli.tar.xz"

# Create the destination directory if it doesn't exist
mkdir -p "$DESTINATION_DIR"

# Download the file using curl
curl -L "${DOWNLOAD_URL}" -o "${FILENAME}"

# Extract the contents to the destination directory
tar -xJf "${FILENAME}" -C "${DESTINATION_DIR}"

# Add the command to ~/custom.sh before starting Docker and Portainer
echo "bash /userdata/system/cli/run &" >> ~/custom.sh

cd userdata/system/cli
chmod +x run

clear
echo "Starting Cli tools..."
./run

echo "Done." 
sleep 10
exit
