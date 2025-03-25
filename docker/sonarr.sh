#!/bin/bash

# Set the application name
APPNAME="Sonarr"

# Base directory for Sonarr data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Ensure required dependencies
if ! command -v dialog &> /dev/null; then
    echo "Dialog is not installed. Please install dialog first."
    exit 1
fi

if ! command -v lsof &> /dev/null; then
    echo "lsof is not installed. Please install lsof first."
    exit 1
fi

# Check if port 8989 is in use
if is_port_in_use 8989; then
    dialog --title "Port Conflict" --msgbox "Port 8989 is already in use. Please stop the conflicting service before installing ${APPNAME}." 10 50
    clear
    exit 1
fi

# Check for Docker and install if missing
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    dialog --title "Docker Required" --infobox "Docker is not installed or not running. Installing Docker..." 10 50
    curl -fsSL https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash

    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        dialog --title "Docker Error" --msgbox "Docker installation failed or service didn't start. Install manually." 10 50
        clear
        exit 1
    fi
fi

# Create Sonarr config and optional TV folders
mkdir -p "$data_dir/config"
mkdir -p "$data_dir/tv"

# Hardware acceleration if available (not required for Sonarr, but in case of add-ons/plugins)
gpu_flag=""
if [ -e /dev/dri ]; then
    gpu_flag="--device=/dev/dri"
fi

# Run Sonarr container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=sonarr \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p 8989:8989 \
  -v "$data_dir/config:/config" \
  -v "$data_dir/tv:/tv" \
  $gpu_flag \
  --restart unless-stopped \
  lscr.io/linuxserver/sonarr:latest

# Final dialog message
if docker ps -q -f name=sonarr &> /dev/null; then
    MSG="${APPNAME} has been installed and started successfully.

Access Web UI: http://<your-ip>:8989

Config: $data_dir/config
TV Folder: $data_dir/tv"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for troubleshooting."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
