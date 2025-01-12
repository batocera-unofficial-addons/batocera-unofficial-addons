#!/bin/bash

# Encrypted password (Base64-encoded after encryption using OpenSSL)
encrypted_password="U2FsdGVkX1+Oq1N32MwHEQEMbOq7ZcU2X12NCE3Amlg="
password_key_base64="ZjVNUmVVbGtuLU9vMmQ4SXl0cVo3ZGpBUWVTLTZHc3F3WmVEaUdxZWNBUQ=="

# Decoded URL for Option 1
option1_url_encoded="Yml0Lmx5L0JhdG9jZXJhR0Q="
option1_url=$(echo "$option1_url_encoded" | base64 -d)

# Function to decode the password key
decode_password_key() {
    echo "$password_key_base64" | base64 -d
}

# Function to decrypt the password
decrypt_password() {
    local key=$(decode_password_key)
    echo "$encrypted_password" | base64 -d | openssl enc -aes-256-cbc -d -a -pass pass:"$key" 2>/dev/null
}

show_menu() {
    local correct_password=$(decrypt_password)

    if [[ -z "$correct_password" ]]; then
        echo "Error: Unable to decrypt the password. Ensure the correct key is set." >&2
        exit 1
    fi

    while true; do
        input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)

        if [[ "$input_password" == "$correct_password" ]]; then
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

    clear
}

# Main execution
show_menu
