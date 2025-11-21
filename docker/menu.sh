#!/bin/bash

# Function to run a container install script
run_container_script() {
    app_name="$1"
    script_url="$2"
    
    echo "Running $app_name install script..."
    curl -fsSL "$script_url" | bash
}

while true; do
    choice=$(dialog --stdout --clear --backtitle "Batocera Unofficial Add-ons" \
                    --title "Docker App Installer" \
                    --menu "Choose a Docker app to install:" 18 65 6 \
                    1 "CasaOS" \
                    2 "UmbrelOS" \
                    3 "Arch KDE (Webtop)" \
                    4 "Ubuntu MATE (Webtop)" \
                    5 "Alpine XFCE (Webtop)" \
                    6 "Jellyfin" \
                    7 "Emby" \
                    8 "Arr-In-One" \
                    9 "Arr-In-One Downloaders" \
                    10 "Exit")

    case $choice in
        1)
            run_container_script "CasaOS" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/casaos.sh"
            ;;
        2)
            run_container_script "UmbrelOS" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/umbrelos.sh"
            ;;
        3)
            run_container_script "Arch KDE" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/archkde.sh"
            ;;
        4)
            run_container_script "Ubuntu MATE" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/ubuntumate.sh"
            ;;
        5)
            run_container_script "Alpine XFCE" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/alpinexfce.sh"
            ;;
        6)
            run_container_script "Jellyfin" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/jellyfin.sh"
            ;;
        7)
            run_container_script "Emby" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/emby.sh"
            ;;
        8)
            run_container_script "Arr-In-One" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/arrinone.sh"
            ;;
        9)
            run_container_script "Arr-In-One Downloaders" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/arrdownloaders.sh"
            ;;
        10)
            clear
            echo "Exiting..."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid choice. Please select a valid option." 10 40
            ;;
    esac

done
