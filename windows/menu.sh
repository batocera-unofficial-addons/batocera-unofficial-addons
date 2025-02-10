#!/bin/bash

# Check for required dependencies
check_dependencies() {
    for cmd in curl dialog; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: '$cmd' is required but not installed."
            exit 1
        fi
    done
}

# Function to run the game install script
run_game_script() {
    game_name="$1"
    script_url="$2"

    echo "Installing $game_name..."
    if curl -L "$script_url" | bash; then
        dialog --msgbox "$game_name has been installed successfully!" 10 40
    else
        dialog --msgbox "Failed to install $game_name. Check your connection or script URL." 10 50
    fi
}

# Define games, their installation scripts, and descriptions
declare -A games=(
    ["Celeste"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/celeste.sh"
    ["Donkey Kong Advanced"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/dka.sh"
    ["Maldita Castilla"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/castilla.sh"
    ["Space Quest 3D"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/sq3d.sh"
    ["Spelunky"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/spelunky.sh"
    ["Super Smash Flash 2"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/ssf2.sh"
    ["Zelda 2 PC Remake"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zelda2.sh"
    ["Zelda - Dungeons of Infinity"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zeldadoi.sh"
)

declare -A descriptions=(
    ["Celeste"]="A challenging platformer about climbing a mountain."
    ["Donkey Kong Advanced"]="A fan remake of the Donkey Kong arcade game."
    ["Maldita Castilla"]="A retro action-platformer inspired by Ghosts 'n Goblins."
    ["Space Quest 3D"]="A 3D remake of the classic adventure game."
    ["Spelunky"]="A roguelike platformer with cave exploration."
    ["Super Smash Flash 2"]="A fan-made fighting game inspired by Smash Bros."
    ["Zelda 2 PC Remake"]="A modernized PC remake of Zelda II."
    ["Zelda - Dungeons of Infinity"]="A fan-made Zelda game with random dungeons."
)

# Sort game names alphabetically
sorted_games=($(printf "%s\n" "${!games[@]}" | sort))

# Convert sorted game list into menu options (Game Name + Description)
game_options=()
index=1
for game in "${sorted_games[@]}"; do
    game_options+=("$index" "$game - ${descriptions[$game]}")
    ((index++))
done

# Add exit option
game_options+=("$index" "Exit")

# Display the menu with descriptions
choice=$(dialog --clear --backtitle "Windows Freeware Game Installer" \
                --title "Game Selection" \
                --menu "Choose a game to install:" 20 80 "${#game_options[@]}" \
                "${game_options[@]}" \
                3>&1 1>&2 2>&3)

# Handle selection
if [[ -z "$choice" ]] || [[ "$choice" -eq "$index" ]]; then
    clear
    echo "Exiting..."
    exit 0
else
    # Extract the actual game name from the menu selection
    game_name="${sorted_games[$((choice - 1))]}"
    script_url="${games[$game_name]}"
    run_game_script "$game_name" "$script_url"
fi
