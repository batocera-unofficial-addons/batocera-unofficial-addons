#!/bin/bash

APPNAME="ArrInOne"
data_dir="/userdata/system/add-ons/${APPNAME,,}"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Ensure dialog and lsof are available
if ! command -v dialog &> /dev/null || ! command -v lsof &> /dev/null; then
    echo "This script requires 'dialog' and 'lsof'. Please install them first."
    exit 1
fi

# Check for Docker and install if needed
if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
    dialog --title "Docker" --infobox "Installing Docker..." 10 50
    curl -fsSL https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash
    if ! command -v docker &> /dev/null || ! docker info &> /dev/null; then
        dialog --title "Docker Error" --msgbox "Docker installation failed. Install manually." 10 50
        clear
        exit 1
    fi
fi

# Check for port conflicts
for port in 8989 7878 8686 8787 9696 6969; do
    if is_port_in_use $port; then
        dialog --title "Port Conflict" --msgbox "Port $port is already in use. Please stop any conflicting containers." 10 50
        clear
        exit 1
    fi
done

# Ask which services to enable
enabled_apps=$(dialog --stdout --checklist "Select which apps to enable:" 20 60 6 \
    "SONARR"   "" off \
    "RADARR"   "" off \
    "LIDARR"   "" off \
    "READARR"  "" off \
    "PROWLARR" "" off \
    "WHISPARR" "" off)

# Convert selection to env vars
env_flags=""
for app in $enabled_apps; do
    app_cleaned=$(echo "$app" | tr -d '"')
    env_flags+="-e $app_cleaned=true "
done

# Create config and media directories
mkdir -p "$data_dir/config"
mkdir -p "$data_dir/tv"
mkdir -p "$data_dir/movies"
mkdir -p "$data_dir/music"
mkdir -p "$data_dir/downloads"

# Run container
dialog --title "Starting ${APPNAME}" --infobox "Launching ${APPNAME} using Docker..." 10 50
docker run -d \
  --name=arr-in-one \
  -e PUID=$(id -u) \
  -e PGID=$(id -g) \
  -e TZ=$(cat /etc/timezone) \
  $env_flags \
  -p 8989:8989 \
  -p 7878:7878 \
  -p 8686:8686 \
  -p 8787:8787 \
  -p 9696:9696 \
  -p 6969:6969 \
  -v "$data_dir/config:/config" \
  -v "$data_dir/tv:/tv" \
  -v "$data_dir/movies:/movies" \
  -v "$data_dir/music:/music" \
  -v "$data_dir/downloads:/downloads" \
  -v /userdata/system/add-ons:/add-ons \
  --restart unless-stopped \
  ghcr.io/thespad/arr-in-one

# Final dialog message
if docker ps -q -f name=arr-in-one &> /dev/null; then
    MSG="${APPNAME} container started successfully.

\n\nEnabled services: ${enabled_apps//\"/ }

\n\nWeb UI Ports:
  \nSonarr:    http://<your-ip>:8989
  \nRadarr:    http://<your-ip>:7878
  \nLidarr:    http://<your-ip>:8686
  \nReadarr:   http://<your-ip>:8787
  \nProwlarr:  http://<your-ip>:9696
  \nWhisparr:  http://<your-ip>:6969

\n\nConfig: $data_dir/config
\nTV: $data_dir/tv
\nMovies: $data_dir/movies
\nMusic: $data_dir/music
\nDownloads: $data_dir/downloads
\nAdd-Ons Shared: /userdata/system/add-ons → /add-ons"
else
    MSG="Failed to start ${APPNAME}. Please check Docker logs."
fi

dialog --title "${APPNAME} Setup Complete" --msgbox "$MSG" 20 70
clear
