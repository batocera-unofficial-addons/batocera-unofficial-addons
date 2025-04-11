#!/bin/bash

# Set the application name
APPNAME="Umbrel"

# Base directory for Umbrel data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Check if port 80 is in use
if is_port_in_use 80; then
    dialog --title "Port Conflict" --msgbox "Port 80 is already in use. Please ensure it is available before installing ${APPNAME}." 10 50
    clear
    exit 1
fi

# Check for Docker and install if needed
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    dialog --title "Docker Required" --infobox "Docker is not installed or the service is not running. Installing Docker..." 10 50
    curl -fsSL https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash

    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        dialog --title "Docker Error" --msgbox "Docker installation failed or the service did not start. Please install Docker manually." 10 50
        clear
        exit 1
    fi
fi

# Create Umbrel data directory
mkdir -p "$data_dir"

# Start Umbrel Docker container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=umbrel \
  -p 80:80 \
  -v "$data_dir:/data" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --pid=host \
  --stop-timeout 60 \
  dockurr/umbrel

# Final message
if docker ps -q -f name=umbrel &> /dev/null; then
    MSG="${APPNAME} Docker container has been set up successfully.\n\nAccess it at: http://<your-ip>\n\nData directory: $data_dir"
else
    MSG="Failed to start ${APPNAME} Docker container. Please check Docker logs for more information."
fi

dialog --title "${APPNAME} Setup" --msgbox "$MSG" 20 70
clear

