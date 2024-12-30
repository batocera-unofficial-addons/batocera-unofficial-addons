#!/bin/bash

# Function to display animated title with colors
animate_title() {
    local text="BATOCERA UNOFFICIAL ADD-ONS INSTALLER"
    local delay=0.03
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
        sleep 0.02
    done
    echo
}

# Function to display controls
display_controls() {
    echo -e "\e[1;33m"  # Set color to green
    echo "Controls:"
    echo "  Navigate with up-down-left-right"
    echo "  Select app with A/B/SPACE and execute with Start/X/Y/ENTER"
    echo -e "\e[0m" # Reset color
    echo " Install these add-ons at your own risk. They are not endorsed by the Batocera Devs nor are they supported." 
    echo " Please don't go into the official Batocera discord with issues, I can't help you there!"
    echo " Instead; head to https://bit.ly/buacord!"
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
    ["SUNSHINE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/main/sunshine/sunshine.sh | bash"
    ["MOONLIGHT"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/moonlight/moonlight.sh | bash"
    ["NVIDIAPATCHER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/nvidiapatch/nvidiapatch.sh | bash"
    ["SWITCH"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/switch/switch.sh | bash"
    ["TAILSCALE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/tailscale/tailscale.sh | bash"
    ["WINEMANAGER"]="curl -Ls links.gregoryc.dev/wine-manager | bash"
    ["SHADPS4"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/shadps4/shadps4.sh | bash"
    ["CONTY"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/conty/conty.sh | bash"
    ["MINECRAFT"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/minecraft/minecraft.sh | bash"
    ["ARMAGETRON"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/armagetron/armagetron.sh | bash"
    ["CLONEHERO"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/clonehero/clonehero.sh | bash"
    ["VESKTOP"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/vesktop/vesktop.sh | bash"
    ["ENDLESS-SKY"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/endlesssky/endlesssky.sh | bash"
    ["CHIAKI"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/chiaki/chiaki.sh | bash"
)

descriptions=(
    ["SUNSHINE"]="A game streaming app to use with Batocera for remote play."
    ["MOONLIGHT"]="Game streaming software for PC gaming on your Batocera machine."
    ["NVIDIAPATCHER"]="Patch for enabling NVIDIA GPU support in Batocera."
    ["SWITCH"]="Install Nintendo Switch emulation on Batocera."
    ["TAILSCALE"]="A VPN service to secure your Batocera network connections."
    ["WINEMANAGER"]="A wine manager for running Windows games on Batocera."
    ["SHADPS4"]="Experimental PlayStation 4 streaming support, not guaranteed to work."
    ["CONTY"]="A standalone Linux distro container."
    ["MINECRAFT"]="Minecraft: Bedrock Edition on Batocera."
    ["ARMAGETRON"]="A Tron-style game for Batocera."
    ["CLONEHERO"]="A Guitar Hero clone for Batocera, works with guitar controllers."
    ["VESKTOP"]="A Discord application for Batocera."
    ["ENDLESS-SKY"]="A space exploration game for Batocera."
    ["CHIAKI"]="An open-source PlayStation Remote Play client for streaming PS4 and PS5 games."
)

# Define categories
declare -A categories
categories=(
    ["Games"]="MINECRAFT ARMAGETRON CLONEHERO ENDLESS-SKY"
    ["Utilities"]="TAILSCALE WINEMANAGER CONTY VESKTOP SUNSHINE MOONLIGHT SWITCH SHADPS4 CHIAKI"
    ["Patches"]="NVIDIAPATCHER"
)

while true; do
    # Show category menu
    category_choice=$(dialog --menu "Choose a category" 15 70 4 \
        "Games" "Install games and game-related add-ons" \
        "Utilities" "Install utility apps" \
        "Patches" "Install patches and fixes" \
        "Exit" "Exit the installer" 2>&1 >/dev/tty)

    # Exit if the user selects "Exit" or cancels
    if [[ $? -ne 0 || "$category_choice" == "Exit" ]]; then
        echo "Exiting the installer."
        exit 0
    fi

    # Based on category, show the corresponding apps
    while true; do
        case "$category_choice" in
            "Games")
                selected_apps="${categories["Games"]}"
                ;;
            "Utilities")
                selected_apps="${categories["Utilities"]}"
                ;;
            "Patches")
                selected_apps="${categories["Patches"]}"
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
