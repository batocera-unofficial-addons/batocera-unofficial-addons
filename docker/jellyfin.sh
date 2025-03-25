#!/bin/bash

# Set the application name
APPNAME="Jellyfin"

# Base directory for Jellyfin data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Check if required ports are free
for port in 8096 8920 7359 1900; do
    if is_port_in_use $port; then
        dialog --title "Port Conflict" --msgbox "Port $port is already in use. Please close the conflicting service before installing ${APPNAME}." 10 50
        clear
        exit 1
    fi
done

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

# Create Jellyfin directory structure
mkdir -p "$data_dir/config"
mkdir -p "$data_dir/data/tvshows"
mkdir -p "$data_dir/data/movies"

# Add hardware acceleration if available
gpu_flag=""
if [ -e /dev/dri ]; then
    gpu_flag="--device=/dev/dri"
fi

# Run Jellyfin container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=jellyfin \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p 8096:8096 \
  -p 8920:8920 \
  -p 7359:7359/udp \
  -p 1900:1900/udp \
  -v "$data_dir/config:/config" \
  -v "$data_dir/data/tvshows:/data/tvshows" \
  -v "$data_dir/data/movies:/data/movies" \
  $gpu_flag \
  --restart unless-stopped \
  lscr.io/linuxserver/jellyfin

# Final message
if docker ps -q -f name=jellyfin &> /dev/null; then
    MSG="${APPNAME} container has been started successfully!

Access it at: http://<your-ip>:8096

Config: $data_dir/config
TV Shows: $data_dir/data/tvshows
Movies: $data_dir/data/movies"
    
    [ -n "$gpu_flag" ] && MSG+="\n\nHardware acceleration: ENABLED"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for details."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
