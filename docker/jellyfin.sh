#!/bin/bash

# Set the application name
APPNAME="Jellyfin"

# Base directory for Jellyfin data
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

# Find available ports for each Jellyfin service
PORT_UI=$(find_available_port 8096 "TCP")       # Web UI
PORT_HTTPS=$(find_available_port 8920 "TCP")    # HTTPS
PORT_DISCOVERY=$(find_available_port 7359 "UDP") # Discovery
PORT_DLNA=$(find_available_port 1900 "UDP")     # DLNA

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

# Run Jellyfin container with dynamic port mappings
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=jellyfin \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  -p ${PORT_UI}:8096 \
  -p ${PORT_HTTPS}:8920 \
  -p ${PORT_DISCOVERY}:7359/udp \
  -p ${PORT_DLNA}:1900/udp \
  -v "$data_dir/config:/config" \
  -v "$data_dir/data/tvshows:/data/tvshows" \
  -v "$data_dir/data/movies:/data/movies" \
  $gpu_flag \
  --restart unless-stopped \
  lscr.io/linuxserver/jellyfin

# Final message
if docker ps -q -f name=jellyfin &> /dev/null; then
    MSG="${APPNAME} container has been started successfully!

\n\nAccess Jellyfin at: http://<your-ip>:${PORT_UI}
\nHTTPS access (if enabled): https://<your-ip>:${PORT_HTTPS}
\nDiscovery Port: UDP ${PORT_DISCOVERY}
\nDLNA Port: UDP ${PORT_DLNA}

\n\nConfig Directory: $data_dir/config
\nTV Shows: $data_dir/data/tvshows
\nMovies: $data_dir/data/movies"
    
    [ -n "$gpu_flag" ] && MSG+="\n\nHardware acceleration: ENABLED"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs for details."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
