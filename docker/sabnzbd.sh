#!/bin/bash

# Set the application name
APPNAME="SABnzbd"

# Base directory for SABnzbd data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Ensure dialog is installed
if ! command -v dialog &> /dev/null; then
    echo "Dialog is not installed. Please install dialog first."
    exit 1
fi

# Check for Docker and install if needed
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    dialog --title "Docker Required" --infobox "Docker is not installed or not running. Installing Docker..." 10 50
    curl -fsSL https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash

    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        dialog --title "Docker Error" --msgbox "Docker installation failed. Please install Docker manually." 10 50
        clear
        exit 1
    fi
fi

# Check if a port is in use
is_port_in_use() {
    netstat -tuln | grep ":$1 " > /dev/null
}

# Find next free port starting from 8080
find_next_available_port() {
    local port=8080
    while is_port_in_use "$port"; do
        port=$((port + 1))
    done
    echo "$port"
}

# Assign a free port for SABnzbd
SABNZBD_PORT=$(find_next_available_port)

# Create SABnzbd config and download directories
mkdir -p "$data_dir/config"
mkdir -p "$data_dir/downloads"
mkdir -p "$data_dir/incomplete-downloads"

# Run the container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker on port ${SABNZBD_PORT}..." 10 50
docker run -d \
  --name=sabnzbd \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p ${SABNZBD_PORT}:8080 \
  -v "$data_dir/config:/config" \
  -v "$data_dir/downloads:/downloads" \
  -v "$data_dir/incomplete-downloads:/incomplete-downloads" \
  -v /userdata/system/add-ons:/add-ons \
  --restart unless-stopped \
  lscr.io/linuxserver/sabnzbd:latest

# Final status
if docker ps -q -f name=sabnzbd &> /dev/null; then
    MSG="${APPNAME} is now running.

Web UI: http://<your-ip>:${SABNZBD_PORT}

Config: $data_dir/config
Downloads: $data_dir/downloads
Incomplete: $data_dir/incomplete-downloads
Add-Ons Mounted: /userdata/system/add-ons → /add-ons"
else
    MSG="Failed to start ${APPNAME}. Check Docker logs for details."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 18 70
clear
