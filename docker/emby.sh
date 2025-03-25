#!/bin/bash

# Set the application name
APPNAME="Emby"

# Base directory for Emby data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Function to find the next available TCP or UDP port
find_available_port() {
    local port=$1
    local proto=$2
    while :; do
        if ! lsof -i${proto}:$port &> /dev/null; then
            echo "$port"
            return
        fi
        port=$((port + 1))
    done
}

# Dynamically get available ports for Emby
PORT_HTTP=$(find_available_port 8096 "TCP")
PORT_HTTPS=$(find_available_port 8920 "TCP")

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

# Create Emby directory structure
mkdir -p "$data_dir/config"
mkdir -p "$data_dir/data/tvshows"
mkdir -p "$data_dir/data/movies"

# Add hardware acceleration if available
gpu_flag=""
if [ -e /dev/dri ]; then
    gpu_flag="--device=/dev/dri"
fi

# Run Emby container with dynamic ports
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=emby \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p ${PORT_HTTP}:8096 \
  -p ${PORT_HTTPS}:8920 \
  -v "$data_dir/config:/config" \
  -v "$data_dir/data/tvshows:/data/tvshows" \
  -v "$data_dir/data/movies:/data/movies" \
  $gpu_flag \
  --restart unless-stopped \
  lscr.io/linuxserver/emby:latest

# Final message
if docker ps -q -f name=emby &> /dev/null; then
    MSG="${APPNAME} container has been started successfully!

\n\nAccess Emby at: http://<your-ip>:${PORT_HTTP}
\nHTTPS access (if enabled): https://<your-ip>:${PORT_HTTPS}

\n\nConfig Directory: $data_dir/config
\nTV Shows: $data_dir/data/tvshows
\nMovies: $data_dir/data/movies"
    
    [ -n "$gpu_flag" ] && MSG+="\n\nHardware acceleration: ENABLED"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for details."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
