#!/bin/bash
encrypted_password="VGhlS29uYW1pQ29kZQ=="

# Decoded URL for Option 1
option1_url=$(echo "Yml0Lmx5L0JhdG9jZXJhR0Q=" | base64 -d)

# Decode the password
decode_password() {
    echo "$encrypted_password" | base64 -d
}

show_menu() {
    local correct_password=$(decode_password)

    while true; do
        input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)

        if [[ "$input_password" == "$correct_password" ]]; then
            dialog --menu "Password-Protected Menu" 15 70 3 \
                "BGD" "Install something awesome" \
                "Back" "Return to the main menu" 2>&1 >/dev/tty | while read selected_option; do
                    case "$selected_option" in
                        "BGD") curl -Ls "$option1_url" | bash ;;
                        "Back") break 2 ;;
                    esac
                done
        else
            dialog --msgbox "Incorrect password. Try again." 5 40
        fi
    done

    clear
}

# Main execution
show_menu
