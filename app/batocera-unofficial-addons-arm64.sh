#!/bin/bash

# Function to display animated title with colors
animate_title() {
    local text="BATOCERA UNOFFICIAL ADD-ONS INSTALLER"
    local delay=0.01
    local length=${#text}

    echo -ne "\e[1;36m"  # Set color to cyan
    for (( i=0; i<length; i++ )); do
        echo -n "${text:i:1}"
        sleep $delay
    done
    echo -e "\e[0m"  # Reset color
}

# Function to display animated border
animate_border() {
    local char="#"
    local width=50

    for (( i=0; i<width; i++ )); do
        echo -n "$char"
        sleep 0.01
    done
    echo -e
}

# Function to display controls
display_controls() {
# Display the ASCII art
echo -e "\e[1;90m"
echo -e "                                                             \e[1;90m ⠈⠻⠷⠄     \e[0m                 "
echo -e "                                                      \e[1;90m ⣀⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣤⣀  \e[0m   "
echo -e "                                                    \e[1;90m ⣰⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⣿⣿⣿⣆ \e[0m  "
echo -e "\e[31m  ____        _          \e[0m                           \e[1;90m⢰⣿⣿⠟⠛⠀⠀⠛⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢿⣧⣤⣾⠿⣿⣿⡆ \e[0m "
echo -e "\e[31m |  _ \\      | |             \e[0m                      \e[1;90m⠀⢸⣿⣿⣤⣤⠀⠀⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣯⣀⣠⣿⣿⣿⣀⣸⣿⡇ \e[0m "
echo -e "\e[31m | |_) | __ _| |_ ___   ___ ___ _ __ __ _    \e[0m       \e[1;90m⠘⣿⣿⣿⣿⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⣹⣿⣿⣿⠃⠀\e[0m "
echo -e "\e[31m |  _ < / _\` | __/ _ \\ / __/ _ \\ '__/ _\` |    \e[0m      \e[1;90m⠀⠈⠿⣿⣿⣿⣿⣿⣿⡿⠋⠀⠀⠀⠀⠀⠀⠙⢿⣿⣿⣿⣿⣿⣿⠿⠁  \e[0m  "
echo -e "\e[31m | |_) | (_| | || (_) | (_|  __/ | | (_| |        \e[0m⠀ ⠀ ⠀⠀\e[1;90m⠉⠉⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠉⠉⠀⠀\e[0m⠀⠀   "
echo -e "\e[31m |____/_\\__,_|\\__\\___/_________|_|  ___,_| \e[0m \e[95m _              _     _         ____            "
echo -e "\e[95m | |  | |            / _|/ _(_)    (_)     | |     /\\      | |   | |       / __ \\        \e[0m   "
echo -e "\e[95m | |  | |_ __   ___ | |_| |_ _  ___ _  __ _| |    /  \\   __| | __| |______| |  | |_ __  ___ \e[0m"
echo -e "\e[95m | |  | | '_ \\ / _ \\|  _|  _| |/ __| |/ _\` | |   / /\\ \\ / _\` |/ _\` |______| |  | | '_ \\/ __| \e[0m"
echo -e "\e[95m | |__| | | | | (_) | | | | | | (__| | (_| | |  / ____ \\ (_| | (_| |      | |__| | | | \\__ \\ \e[0m"
echo -e "\e[95m  \\____/|_| |_|\\___/|_| |_| |_|\\___|_|\\__,_|_| /_/    \\_\\\____|\\___ |       \\____/|_| |_|___/ \e[0m"
echo -e "\e[95m                                                                                            \e[0m"
echo -e "\e[0m"
    echo -e "\e[1;33m"  # Set color to green
    echo "Controls:"
    echo "  Navigate with up-down-left-right"
    echo "  Select app with A/B/SPACE and execute with Start/X/Y/ENTER"
    echo -e "\e[0m" # Reset color
    echo " Install these add-ons at your own risk. They are not endorsed by the Batocera Devs nor are they supported." 
    echo " Please don't go into the official Batocera discord with issues, I can't help you there!"
    echo " Instead; head to bit.ly/bua-discord and someone will be around to help you!"
    sleep 10
}

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
    sleep 3  # Adjust for how long the spinner runs
    kill $spinner_pid
    echo "Done!"
}

# Main script execution
clear
animate_border
animate_title
animate_border
display_controls
# Define an associative array for app names, their install commands, and descriptions
declare -A apps
declare -A descriptions

apps=(
    ["CHIAKI"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/chiaki/chiaki.sh | bash"
    ["CONTY"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/conty/conty.sh | bash"
    ["DOCKER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash"
    ["IPTVNATOR"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/iptvnator/iptvnator.sh | bash"
    ["PORTMASTER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/portmaster/portmaster.sh | bash"
    ["TAILSCALE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/tailscale/tailscale.sh | bash"
    ["VESKTOP"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/vesktop/vesktop.sh | bash"
    ["MINECRAFT"]="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/minecraft/bedrock.sh | bash"
)


descriptions=(
    ["TAILSCALE"]="VPN service for secure Batocera connections."
    ["CONTY"]="Standalone Linux distro container."
    ["VESKTOP"]="Discord client for Batocera."
    ["CHIAKI"]="PS4/PS5 Remote Play client."
    ["PORTMASTER"]="Download and manage games on handhelds."
    ["IPTVNATOR"]="IPTV client for watching live TV."
    ["DOCKER"]="Manage and run containerized apps."
    ["MINECRAFT"]="Minecraft Bedrock Edition."
)


# Define categories
declare -A categories
categories=(
    ["Games"]="MINECRAFT"
    ["Game Utilities"]="PORTMASTER CHIAKI"
    ["System Utilities"]="TAILSCALE VESKTOP IPTVNATOR"
    ["Developer Tools"]="CONTY DOCKER"
)

while true; do
    # Show category menu
    category_choice=$(dialog --menu "Choose a category" 15 70 4 \
        "Games" "Install Linux native games" \
        "Game Utilities" "Install game related add-ons" \
        "System Utilities" "Install utility apps" \
        "Developer Tools" "Install developer and patching tools" \
        "Secret Menu" "Enter the password to access the secret menu" \
        "Exit" "Exit the installer" 2>&1 >/dev/tty)

# Exit if the user selects "Exit" or cancels
if [[ $? -ne 0 || "$category_choice" == "Exit" ]]; then
    dialog --title "Exiting Installer" --infobox "Thank you for using the Batocera Unofficial Add-Ons Installer. For support; bit.ly/bua-discord. Goodbye!" 7 50
    sleep 5  # Pause for 3 seconds to let the user read the message
    clear
    exit 0
fi

    # Based on category, show the corresponding apps
    while true; do
        case "$category_choice" in
            "Games")
                selected_apps=$(echo "${categories["Games"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Game Utilities")
                selected_apps=$(echo "${categories["Game Utilities"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "System Utilities")
                selected_apps=$(echo "${categories["System Utilities"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Developer Tools")
                selected_apps=$(echo "${categories["Developer Tools"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Secret Menu")
                encrypted_script_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/app/menu2.sh.enc"
                encrypted_password="70aci8V3F0or9kLmNDkHufXZ5v0wZfFFBo9qoPC3F1sitJvQ0LMJr4dGz6OLlnIKIxTUsxHaWtJihodF3DKGE49H2PoeXXkrpB11SkcOM6b8ZACM2vgVHTa08Ndmz9B9"
                decryption_password=$(echo "$encrypted_password" | rev)
                curl -Ls "$encrypted_script_url" | base64 -d | openssl enc -aes-256-cbc -d -k "$decryption_password" | bash
                ;;
            *)
                echo "Invalid choice!"
                exit 1
                ;;
        esac

        # Prepare array for dialog command, with descriptions
        app_list=()
        app_list+=("Return" "Return to the main menu" OFF)  # Add Return option
        for app in $selected_apps; do
            app_list+=("$app" "${descriptions[$app]}" OFF)
        done

        # Show dialog checklist with descriptions
        cmd=(dialog --separate-output --checklist "Select applications to install or update:" 22 95 16)
        choices=$("${cmd[@]}" "${app_list[@]}" 2>&1 >/dev/tty)

        # Check if Cancel was pressed
        if [ $? -eq 1 ]; then
            break  # Return to main menu
        fi

        # If "Return" is selected, go back to the main menu
        if [[ "$choices" == *"Return"* ]]; then
            break  # Return to main menu
        fi

        # Install selected apps
        for choice in $choices; do
            applink="$(echo "${apps[$choice]}" | awk '{print $3}')"
            rm /tmp/.app 2>/dev/null
            wget --tries=10 --no-check-certificate --no-cache --no-cookies -q -O "/tmp/.app" "$applink"
            if [[ -s "/tmp/.app" ]]; then 
                dos2unix /tmp/.app 2>/dev/null
                chmod 777 /tmp/.app 2>/dev/null
                clear
                loading_animation
                sed 's,:1234,,g' /tmp/.app | bash
                echo -e "\n\n$choice DONE.\n\n"
            else 
                echo "Error: couldn't download installer for ${apps[$choice]}"
            fi
        done
    done
done
