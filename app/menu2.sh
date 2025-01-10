#!/bin/bash


encoded_sequence="VVAuVVAsRE9XTixET1dOLExFRlQsUklHSFQsTEVGVCxSSUdIVA=="


required_sequence=($(echo "$encoded_sequence" | base64 -d | tr ',' ' '))


capture_input() {
    local input_sequence=()
    while [[ ${#input_sequence[@]} -lt ${#required_sequence[@]} ]]; do
        # Replace this read with actual controller input capturing logic
        read -p "" input
        echo "You pressed: $input"
        input_sequence+=("$input")

        
        if [[ "${input_sequence[@]}" != "${required_sequence[@]:0:${#input_sequence[@]}}" ]]; then
            echo "Incorrect! Starting over..."
            input_sequence=()
        fi
    done

  
    if [[ "${input_sequence[@]}" == "${required_sequence[@]}" ]]; then
        echo "Password accepted!"
        return 0
    else
        echo "Access denied!"
        return 1
    fi
}

# Encoded URL for Option 1
option1_url_encoded="aHR0cHM6Ly9naXRodWIuY29tL0RUSlc5Mi9nYW1lLWRvd25sb2FkZXIvcmF3L3JlZnMvaGVhZHMvbWFpbi9WMy9pbnN0YWxsLnNo"

# Decode the URL when needed
option1_url=$(echo "$option1_url_encoded" | base64 -d)

  input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)
                if [[ "$input_password" == "$password" ]]; then
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
                    dialog --title "Access Denied" --msgbox "Incorrect password." 5 40
                    sleep 3
                fi
