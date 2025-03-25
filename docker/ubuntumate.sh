#!/bin/bash

# Set the application name
APPNAME="Ubuntu XFCE"

# Base directory for Ubuntu XFCE data
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

# Create Ubuntu XFCE data and home directories
mkdir -p "$data_dir"
mkdir -p "$data_dir/home"

# Start Ubuntu XFCE Docker container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} (Webtop - XFCE) using Docker..." 10 50
docker run -d \
  --name=ubuntu-mate \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/London \
  -e SUBFOLDER=/ \
  -p 3001:3000 \
  -v "$data_dir:/config" \
  -v "$data_dir/home:/home/ubuntu" \
  --shm-size="2gb" \
  --restart unless-stopped \
  lscr.io/linuxserver/webtop:ubuntu-mate

# Final message
if docker ps -q -f name=ubuntu-xfce &> /dev/null; then
    MSG="${APPNAME} container has been started successfully.\n\nAccess it via: http://<your-ip>:3001\n\nPersistent data is stored in:\n$data_dir\nand\n$data_dir/home"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for troubleshooting."
fi

dialog --title "${APPNAME} Setup" --msgbox "$MSG" 20 70
clear
