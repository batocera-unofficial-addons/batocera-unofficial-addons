#!/bin/bash

APPNAME="Downloaders"
data_dir="/userdata/system/add-ons/arrinone"
downloads_dir="${data_dir}/downloads"

# Create downloads directory if needed
mkdir -p "$downloads_dir"

# Function to check if a port is in use
is_port_in_use() {
    lsof -i:$1 &> /dev/null
}

# Function to install a container
install_downloader() {
    local name="$1"
    local image="$2"
    local port="$3"
    local container="$4"
    local extra_flags="${5:-}"

    if is_port_in_use "$port"; then
        dialog --title "Port Conflict" --msgbox "Port $port is already in use. Please free it before installing $name." 10 50
        return
    fi

    dialog --title "Installing $name" --infobox "Setting up $name..." 8 50

    docker run -d \
      --name="$container" \
      -e PUID=$(id -u) \
      -e PGID=$(id -g) \
      -e TZ=$(cat /etc/timezone) \
      -p "$port:$port" \
      -v "$data_dir/config:/data/config" \
      -v "$data_dir/tv:/data/tv" \
      -v "$data_dir/movies:/data/movies" \
      -v "$data_dir/music:/data/music" \
      -v "$data_dir/downloads:/data/downloads" \
      -v /userdata/system/add-ons:/add-ons \
      $extra_flags \
      --restart unless-stopped \
      "$image"

    if docker ps -q -f name="$container" &> /dev/null; then
        dialog --title "$name Setup Complete" --msgbox "$name has been installed successfully.\n\nAccess Web UI:\nhttp://<your-ip>:$port\n\nDownloads: $downloads_dir" 20 70
    else
        dialog --title "$name Error" --msgbox "Failed to start $name. Please check Docker logs." 10 50
    fi
}

while true; do
    choice=$(dialog --stdout --clear --backtitle "Batocera Downloaders" \
        --title "Choose a Downloader to Install" \
        --menu "Select a client to install or manage:" 25 75 20 \
        1  "qBittorrent    (8080) - Full-featured modern torrent UI" \
        2  "Deluge         (8112) - Lightweight and stable torrent client" \
        3  "Transmission   (9091) - Minimalist and efficient torrenting" \
        4  "Aria2          (6800) - CLI/JSON-RPC advanced torrent/HTTP" \
        5  "Flood          (3000) - Beautiful UI for rTorrent (requires rTorrent)" \
        6  "Hadouken       (7070) - Web UI styled like uTorrent" \
        7  "NZBGet         (6789) - Fast, efficient Usenet downloader" \
        8  "SABnzbd        (8081) - User-friendly Usenet interface" \
        9  "RdtClient      (6500) - Real-Debrid cloud downloader UI" \
        10 "FlareSolverr   (8191) - Anti-bot proxy for Prowlarr" \
        11 "rTorrent       (5000) - Backend for Flood or CLI power users" \
        12 "Usenet Blackhole - Folder-based Usenet fallback (no container)" \
        13 "Exit")

    case "$choice" in
        1)
            install_downloader "qBittorrent" "lscr.io/linuxserver/qbittorrent" 8080 "qbittorrent"
            ;;
        2)
            install_downloader "Deluge" "lscr.io/linuxserver/deluge" 8112 "deluge"
            ;;
        3)
            install_downloader "Transmission" "lscr.io/linuxserver/transmission" 9091 "transmission"
            ;;
        4)
            install_downloader "Aria2" "p3terx/aria2-pro" 6800 "aria2"
            ;;
        5)
            install_downloader "Flood" "jesec/flood" 3000 "flood" "-e HOME=/config -v $downloads_dir/flood-config:/config"
            ;;
        6)
            install_downloader "Hadouken" "hadouken/hadouken" 7070 "hadouken"
            ;;
        7)
            install_downloader "NZBGet" "lscr.io/linuxserver/nzbget" 6789 "nzbget"
            ;;
        8)
            install_downloader "SABnzbd" "lscr.io/linuxserver/sabnzbd" 8081 "sabnzbd"
            ;;
        9)
            install_downloader "RdtClient" "ghcr.io/rogerfar/rdtclient" 6500 "rdtclient"
            ;;
        10)
            install_downloader "FlareSolverr" "ghcr.io/flaresolverr/flaresolverr" 8191 "flaresolverr"
            ;;
        11)
            install_downloader "rTorrent" "crazymax/rtorrent-rutorrent" 5000 "rtorrent" "-v $downloads_dir/rtorrent:/data"
            ;;
        12)
            dialog --title "Usenet Blackhole" --msgbox "No container needed.\n\nJust configure your app to drop NZB files into:\n\n$downloads_dir/usenet-blackhole" 12 60
            mkdir -p "$downloads_dir/usenet-blackhole"
            ;;
        13)
            clear
            echo "Exiting..."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid selection. Please choose again." 8 40
            ;;
    esac
done
