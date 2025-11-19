#!/bin/bash
# UPDATED 2025-11-14

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/batocera-containers"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: aarch64 detected."
    url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/batocera-containers-aarch64"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

echo "Preparing & Downloading Docker & Podman..."

# Define the directory and the URL for the file
directory="$HOME/batocera-containers"
filename="batocera-containers" # Explicitly set the filename

# Create the directory if it doesn't exist
mkdir -p "$directory"

# Change to the directory
cd "$directory"

# Download the file with the specified filename
wget -q --show-progress "$url" -O "$filename"

# Make the file executable
chmod +x "$filename"

echo "File '$filename' downloaded and made executable in '$directory/$filename'"

# Add the command to ~/custom.sh before starting Docker and Portainer
custom_startup="/userdata/system/custom.sh"
restore_script="/userdata/system/batocera-containers/batocera-containers"

if ! grep -q "$restore_script" "$custom_startup" 2>/dev/null; then
    echo "Adding batocera-containers to startup..."
    echo "bash $restore_script &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

cd ~/batocera-containers

clear
echo "Starting Docker..."
echo ""
~/batocera-containers/batocera-containers

# Install Portainer
echo "Installing portainer.."
echo ""
docker volume create portainer_data
docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d --name portainer --restart=always -v /var/run/docker.sock:/var/run/docker.sock -v /media:/media -v portainer_data:/data portainer/portainer-ce:latest

curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/docker -o /userdata/system/services/docker && chmod +x /userdata/system/services/docker
batocera-services enable docker
batocera-services start docker

dialog --title "Installation Complete" --msgbox "Done!\n\nYou can now access the Portainer GUI at:\n\nhttps://<batoceraipaddress>:9443" 10 50
clear
exit

