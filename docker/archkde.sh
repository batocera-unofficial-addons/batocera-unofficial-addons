#!/bin/bash

# Set the application name
APPNAME="Arch KDE"

# Base directory for Arch KDE data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Check if port 3000 is in use
if is_port_in_use 3000; then
    dialog --title "Port Conflict" --msgbox "Port 3000 is already in use. Please ensure it is available before installing ${APPNAME}." 10 50
    clear
    exit 1
fi

# Check for Docker and install if missing
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    dialog --title "Docker Required" --infobox "Docker is not installed or the service is not running. Installing Docker..." 10 50
    curl -fsSL https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash

    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        dialog --title "Docker Error" --msgbox "Docker installation failed or the service did not start. Please install Docker manually." 10 50
        clear
        exit 1
    fi
fi

# Create Arch KDE data directory
mkdir -p "$data_dir"

# Start Arch KDE Docker container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} (Webtop) using Docker..." 10 50
docker run -d \
  --name=arch-kde \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e SUBFOLDER=/ \
  -p 3000:3000 \
  -v "$data_dir:/config" \
  --shm-size="2gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:arch-kde

# Final message
if docker ps -q -f name=arch-kde &> /dev/null; then
    MSG="${APPNAME} container has been started successfully.\n\nAccess it via: http://<your-ip>:3000\n\nData stored in: $data_dir"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for troubleshooting."
fi

dialog --title "${APPNAME} Setup" --msgbox "$MSG" 20 70
clear
