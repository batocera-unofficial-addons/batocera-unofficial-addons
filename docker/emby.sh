#!/bin/bash

# Set the application name
APPNAME="Emby"

# Base directory for Emby data
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Function to find an available port starting from 8096
find_available_port() {
    local port=8096
    local used_ports=$(docker ps -a --format '{{.Ports}}' | grep -oP '\d+(?=->)' | sort -u)

    while :; do
        if ! echo "$used_ports" | grep -q "^$port$" && ! lsof -i:"$port" &> /dev/null; then
            echo "$port"
            return
        fi
        port=$((port + 1))
    done
}

# Dynamically get the next available port for Emby (web UI)
HOST_PORT=$(find_available_port)

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

# Run Emby container with dynamic port
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=emby \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p ${HOST_PORT}:8096 \
  -p 8920:8920 \
  -v "$data_dir/config:/config" \
  -v "$data_dir/data/tvshows:/data/tvshows" \
  -v "$data_dir/data/movies:/data/movies" \
  $gpu_flag \
  --restart unless-stopped \
  lscr.io/linuxserver/emby:latest

# Final message
if docker ps -q -f name=emby &> /dev/null; then
    MSG="${APPNAME} container has been started successfully!

\n\nAccess it at: http://<your-ip>:${HOST_PORT}

\n\nConfig: $data_dir/config
\nTV Shows: $data_dir/data/tvshows
\nMovies: $data_dir/data/movies"
    
    [ -n "$gpu_flag" ] && MSG+="\n\nHardware acceleration: ENABLED"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for details."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
