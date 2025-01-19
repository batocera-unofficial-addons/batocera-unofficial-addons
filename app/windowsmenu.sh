#!/bin/bash

# Function to display loading animation
loading_animation() {
    local delay=0.1
    local spinstr='|/-\' 
    echo -n "Loading "
    while :; do
        for (( i=0; i<${#spinstr}; i++ )); do
            echo -ne "${spinstr:i:1}"
            echo -ne "\010"
            sleep $delay
        done
    done &  # Run spinner in the background
    spinner_pid=$!
    sleep 3  # Adjust spinner duration
    kill $spinner_pid
    echo "Done!"
}

# Define available games and their install commands
declare -A games=(
    ["Zelda2Remake"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zelda2.sh | bash"
    ["SuperTux"]="curl -Ls https://example.com/supertux.sh | bash"
    ["OpenRA"]="curl -Ls https://example.com/openra.sh | bash"
    ["Moonlight"]="curl -Ls https://example.com/moonlight.sh | bash"
)

# Define descriptions for the games
declare -A descriptions=(
    ["Zelda2Remake"]="A fan-made remake of Zelda II."
    ["SuperTux"]="2D platformer starring Tux the Linux mascot."
    ["OpenRA"]="Modernized RTS for Command & Conquer."
    ["Moonlight"]="Stream PC games on Batocera."
)

# Main game selection menu loop
while true; do
    # Prepare the list for the dialog checklist
    game_list=()
    game_list+=("Return" "Return to the main menu" OFF)
    
    for game in "${!games[@]}"; do
        game_list+=("$game" "${descriptions[$game]}" OFF)
    done

    # Show the game selection menu
    cmd=(dialog --separate-output --checklist "Select games to install:" 22 95 16)
    choices=$("${cmd[@]}" "${game_list[@]}" 2>&1 >/dev/tty)

    # Check if Cancel was pressed
    if [ $? -eq 1 ]; then
        echo "Returning to main menu..."
        break
    fi

    # If "Return" is selected, go back to the menu without exiting
    if [[ "$choices" == *"Return"* ]]; then
        echo "Returning to main menu..."
        continue
    fi

    # Install selected games
    for choice in $choices; do
        applink="${games[$choice]}"
        rm -f /tmp/.game_installer 2>/dev/null

        echo "Downloading and installing $choice..."
        eval "$applink" > /tmp/.game_installer 2>&1 &

        loading_animation

        # Check if installation was successful
        if grep -q "error" /tmp/.game_installer; then
            echo "Error: Failed to install $choice. See /tmp/.game_installer for details."
        else
            echo "$choice installed successfully."
        fi
    done
done
