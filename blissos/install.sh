#!/bin/bash

# Ensure the script runs only on x86_64 architecture
architecture=$(uname -m)
if [ "$architecture" != "x86_64" ]; then
    echo "This script only runs on AMD or Intel (x86_64) CPUs, not on $architecture."
    exit 1
fi

echo "Preparing & Downloading Docker & Podman..."
echo ""

# Set variables
directory="$HOME/batocera-containers"
url="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/.dep/batocera-containers.zip"
filename="batocera-containers.zip"
output_file="batocera-containers"  # Update if the extracted file name differs

# Create directory
mkdir -p "$directory"
cd "$directory" || { echo "Failed to access $directory"; exit 1; }

# Download the ZIP file
if ! wget "$url" -O "$filename"; then
    echo "Failed to download $url"
    exit 1
fi

# Extract the ZIP file
if ! unzip -j "$filename" -d "$directory"; then
    echo "Failed to extract $filename"
    exit 1
fi

# Ensure the extracted file exists
if [ ! -f "$directory/$output_file" ]; then
    echo "File $output_file not found after extraction."
    exit 1
fi

# Make the file executable
chmod +x "$directory/$output_file"

# Update custom.sh
csh="/userdata/system/custom.sh"
startup="$directory/$output_file &"

if [[ -f $csh ]]; then
    # Remove existing startup entry if present
    sed -i "/$startup/d" "$csh"
else
    echo -e '#!/bin/bash' > "$csh"
fi

# Append the startup command
echo -e "\n$startup\n" >> "$csh"
chmod +x "$csh"

# Start Docker
echo "Starting Docker..."
"$directory/$output_file" || { echo "Failed to start Docker"; exit 1; }

# Install Portainer
echo "Installing Portainer..."
docker volume create portainer_data
docker run --device /dev/dri:/dev/dri --privileged --net host --ipc host -d --name portainer --restart=always \
    -v /var/run/docker.sock:/var/run/docker.sock -v /media:/media -v portainer_data:/data portainer/portainer-ce:latest

echo "Done. Access Portainer GUI via https://<batoceraipaddress>:9443"
sleep 10
exit
