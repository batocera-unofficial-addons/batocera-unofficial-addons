#!/bin/bash

# Encoded sequence (password)
encoded_sequence="VVAuVVAsRE9XTixET1dOLExFRlQsUklHSFQsTEVGVCxSSUdIVA=="
required_sequence=($(echo "$encoded_sequence" | base64 -d | tr ',' ' '))

# Encoded URL for Option 1
option1_url_encoded="Yml0Lmx5L0JhdG9jZXJhR0Q="
option1_url=$(echo "$option1_url_encoded" | base64 -d)

capture_input() {
    local input_sequence=()
    local index=0  # Track the current position in the sequence

    while [[ $index -lt ${#required_sequence[@]} ]]; do
        read -p "" input
        if [[ -n "$input" ]]; then
            if [[ "$input" == "${required_sequence[$index]}" ]]; then
                input_sequence+=("$input")
                index=$((index + 1))  # Move to the next position
            else
                echo "Incorrect input, resetting..." >&2
                input_sequence=()
                index=0
            fi
        fi
    done

    # Validation success
    echo "Password accepted!" > /tmp/capture_result
}

show_menu() {
    # Wait for the correct sequence in the background
    mkfifo /tmp/sequence_input
    capture_input < /tmp/sequence_input &

    while true; do
        input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)

        # Send the input to the sequence handler
        echo "$input_password" > /tmp/sequence_input

        # Check if the correct sequence is entered
        if [[ -f /tmp/capture_result && "$(cat /tmp/capture_result)" == "Password accepted!" ]]; then
            selected_option=$(dialog --menu "Password-Protected Menu" 15 70 3 \
                "BGD" "Install something awesome" \
                "Back" "Return to the main menu" 2>&1 >/dev/tty)
            case "$selected_option" in
                "BGD")
                    curl -Ls "$option1_url" | bash
                    ;;
                "Back")
                    break
                    ;;
            esac
        else
            dialog --title "Access Denied" --msgbox "Incorrect password. Try again." 5 40
        fi
    done

    rm -f /tmp/sequence_input /tmp/capture_result  # Clean up
    clear
}

# Main execution
show_menu
