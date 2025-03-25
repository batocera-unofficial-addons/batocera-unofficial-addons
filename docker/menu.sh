#!/bin/bash

# Function to run a container install script
run_container_script() {
    app_name="$1"
    script_url="$2"
    
    echo "Running $app_name install script..."
    curl -fsSL "$script_url" | bash
}

while true; do
    choice=$(dialog --clear --backtitle "Batocera Unofficial Add-ons" \
                    --title "Docker App Installer" \
                    --menu "Choose a Docker app to install:" 18 65 6 \
                    1 "CasaOS" \
                    2 "UmbrelOS" \
                    3 "Arch KDE (Webtop)" \
                    4 "Ubuntu MATE (Webtop)" \
                    5 "Alpine XFCE (Webtop)" \
                    6 "Exit" \
                    3>&1 1>&2 2>&3)

    case $choice in
        1)
            run_container_script "CasaOS" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/casaos.sh"
            ;;
        2)
            run_container_script "UmbrelOS" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/umbrelos.sh"
            ;;
        3)
            run_container_script "Arch KDE" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/archkde.sh"
            ;;
        4)
            run_container_script "Ubuntu MATE" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/ubuntumate.sh"
            ;;
        5)
            run_container_script "Alpine XFCE" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/alpinexfce.sh"
            ;;
        6)
            clear
            echo "Exiting..."
            exit 0
            ;;
        *)
            dialog --msgbox "Invalid choice. Please select a valid option." 10 40
            ;;
    esac

done
