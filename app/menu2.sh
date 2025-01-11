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

    echo "Expected: ${required_sequence[*]}" > /tmp/debug_log  # Debug: Log required sequence

    while [[ $index -lt ${#required_sequence[@]} ]]; do
        # Read input from a virtual file descriptor (FIFO)
        if read -r input < /tmp/sequence_input; then
            echo "Input received: $input" >> /tmp/debug_log  # Debug: Log input
            echo "Expected: ${required_sequence[$index]}" >> /tmp/debug_log  # Debug: Log expected value

            # Check if the input matches the current expected value
            if [[ "$input" == "${required_sequence[$index]}" ]]; then
                input_sequence+=("$input")
                index=$((index + 1))  # Move to the next expected input
                echo "Progress: ${input_sequence[*]}" >> /tmp/debug_log  # Debug: Log progress
            else
                echo "Incorrect input, ignoring..." >> /tmp/debug_log  # Debug: Wrong input is ignored
            fi
        fi
    done

    # Final validation
    if [[ "${input_sequence[*]}" == "${required_sequence[*]}" ]]; then
        echo "Password accepted!" > /tmp/capture_result
    else
        echo "Access denied!" > /tmp/capture_result
    fi
}

show_menu() {
    mkfifo /tmp/sequence_input  # Create a named pipe for sequence input

    # Start capture_input in the background
    capture_input &

    while true; do
        input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)

        # Send the password box input to the sequence handler
        echo "$input_password" > /tmp/sequence_input

        # Check for the result from capture_input
        if [[ -f /tmp/capture_result && "$(cat /tmp/capture_result)" == "Password accepted!" ]]; then
            break
        else
            dialog --title "Incorrect" --msgbox "Waiting for the correct password..." 5 40
        fi
    done

    # Show the menu
    selected_option=$(dialog --menu "Password-Protected Menu" 15 70 3 \
        "BGD" "Install something awesome" \
        "Back" "Return to the main menu" 2>&1 >/dev/tty)

    case "$selected_option" in
        "BGD")
            echo "Downloading and running the script from: $option1_url"
            curl -Ls "$option1_url" | bash
            ;;
        "Back")
            echo "Returning to the main menu..."
            ;;
    esac

    rm -f /tmp/sequence_input /tmp/capture_result  # Clean up temporary files
}

# Main execution flow
show_menu
