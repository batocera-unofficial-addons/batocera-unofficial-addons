#!/bin/bash

# Define game options (populate with actual download links later)
GAMES=(
    "Zelda 2 Remake" "A fan made remake of Zelda II" "https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/windows/zelda2.sh"
    "2" "Description" "https://example.com/example.sh"
    "3" "Description" "https://example.com/example.sh"
    "4" "Description" "https://example.com/example.sh"
)

# Build options for dialog
OPTIONS=()
for ((i=0; i<${#GAMES[@]}; i+=3)); do
    OPTIONS+=("${GAMES[i]}" "${GAMES[i+1]}" OFF)
done

# Display checklist dialog
CHOICES=$(dialog --clear --stdout --checklist "Select games to download:" 20 70 10 "${OPTIONS[@]}")

# Check if user canceled
if [ -z "$CHOICES" ]; then
    echo "No games selected. Exiting."
    exit 1
fi

# Process selected choices
for GAME_NAME in $CHOICES; do
    for ((i=0; i<${#GAMES[@]}; i+=3)); do
        if [[ "${GAMES[i]}" == "$GAME_NAME" ]]; then
            GAME_URL="${GAMES[i+2]}"
            echo "Downloading and executing $GAME_NAME..."
            curl -Ls "$GAME_URL" | bash
            if [ $? -eq 0 ]; then
                echo "$GAME_NAME installed successfully."
            else
                echo "Failed to install $GAME_NAME."
            fi
        fi
    done
done

echo "All selected games have been processed."
exit 0
