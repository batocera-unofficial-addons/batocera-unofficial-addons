#!/bin/bash

# Function to run a game install script
run_game_script() {
    game_name="$1"
    script_url="$2"
    
    echo "Running $game_name install script..."
    curl -L "$script_url" | bash
}

while true; do
    choice=$(dialog --clear --backtitle "Windows Freeware Game Installer" \
                    --title "Game Selection" \
                    --menu "Choose a game to install:" 15 50 7 \
                    1 "Maldita Castilla" \
                    2 "Celeste" \
                    3 "Donkey Kong Advanced" \
                    4 "Spelunky" \
                    5 "Zelda 2 PC Remake" \
                    6 "Zelda - Dungeons of Infinity" \
                    7 "Space Quest 3D" \
                    8 "Super Smash Flash 2" \
                    9 "TMNT Rescue Palooza" \
                    10 "Exit" \
                    3>&1 1>&2 2>&3)
    
    case $choice in
        1)
            run_game_script "Maldita Castilla" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/castilla.sh"
            ;;
        2)
            run_game_script "Celeste" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/celeste.sh"
            ;;
        3)
            run_game_script "Donkey Kong Advanced" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/dka.sh"
            ;;
        4)
            run_game_script "Spelunky" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/spelunky.sh"
            ;;
        5)
            run_game_script "Zelda 2 PC Remake" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zelda2.sh"
            ;;
        6)
            run_game_script "Zelda - Dungeons of Infinity" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zeldadoi.sh"
            ;;
        7)
            run_game_script "Space Quest 3D" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/sq3d.sh"
            ;;
        8)
            run_game_script "Super Smash Flash 2" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/ssf2.sh"
            ;;
        9)
            run_game_script "TMNT Rescue Palooza" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/tmntrp.sh"
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
