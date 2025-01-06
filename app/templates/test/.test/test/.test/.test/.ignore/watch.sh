#!/bin/bash

# Konami Code sequence
konami_code=("UP" "UP" "DOWN" "DOWN" "LEFT" "RIGHT" "LEFT" "RIGHT" "B" "A")
user_input=()

# Function to capture and check for the Konami Code
capture_konami_code() {
    echo "Listening for the Konami Code..."
    while true; do
        read -rsn1 input
        case "$input" in
            $'\x1b')  # Detect arrow keys (Esc sequence)
                read -rsn2 -t 0.1 input
                case "$input" in
                    "[A") user_input+=("UP") ;;
                    "[B") user_input+=("DOWN") ;;
                    "[D") user_input+=("LEFT") ;;
                    "[C") user_input+=("RIGHT") ;;
                esac
                ;;
            b|B) user_input+=("B") ;;
            a|A) user_input+=("A") ;;
        esac

        # Limit input array size to the length of the Konami Code
        if [[ ${#user_input[@]} -gt ${#konami_code[@]} ]]; then
            user_input=("${user_input[@]:1}")
        fi

        # Check if the user input matches the Konami Code
        if [[ "${user_input[@]}" == "${konami_code[@]}" ]]; then
            show_secret_menu
            user_input=()  # Reset the input sequence
        fi
    done
}

# Function to display the secret menu
show_secret_menu() {
    local choice

    while true; do
        choice=$(dialog --menu "Secret Menu" 15 50 3 \
            "1" "Game Downloader" \
            "2" "Return to Listening" \
            2>&1 >/dev/tty)

        case $choice in
            1)
                # Run the Game Downloader script
                dialog --infobox "Downloading and running Game Downloader..." 5 40
                sleep 2
                curl -Ls https://github.com/DTJW92/game-downloader/raw/refs/heads/main/V3/install.sh | bash
                dialog --msgbox "Game Downloader has been executed!" 7 40
                ;;
            2)
                # Return to listening for the Konami Code
                break
                ;;
            *)
                # Handle invalid input
                dialog --msgbox "Invalid choice. Try again." 7 40
                ;;
        esac
    done
}

# Start listening for the Konami Code
capture_konami_code
