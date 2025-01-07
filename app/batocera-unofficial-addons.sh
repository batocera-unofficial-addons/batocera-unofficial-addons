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
    echo " Instead; head to bit.ly/bua-discord and someone will be around to help you!"
    sleep 10
}

# Function to display loading animation
loading_animation() {
    local delay=0.1
    local spinstr='|/-\\' 
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

# Encoded password (Base64)
password_encoded="VEhFTk9UT1JJT1VTRk9Y"

# Decode the password at runtime
password=$(echo "$password_encoded" | base64 -d)

# Encoded URL for Option 1
option1_url_encoded="aHR0cHM6Ly9naXRodWIuY29tL0RUSlc5Mi9nYW1lLWRvd25sb2FkZXIvcmF3L3JlZnMvaGVhZHMvbWFpbi9WMy9pbnN0YWxsLnNo"

# Decode the URL when needed
option1_url=$(echo "$option1_url_encoded" | base64 -d)

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
    ["CHROME"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/chrome/chrome.sh | bash"
    ["AMAZON-LUNA"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/amazonluna/amazonluna.sh | bash"
    ["PORTMASTER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/portmaster/portmaster.sh | bash"
    ["GREENLIGHT"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/greenlight/greenlight.sh | bash"
    ["HEROIC"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/heroic/heroic.sh | bash"
    ["YOUTUBE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/youtubetv/youtubetv.sh | bash"
    ["NETFLIX"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/netflix/netflix.sh | bash"
    ["IPTVNATOR"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/iptvnator/iptvnator.sh | bash"
    ["FIREFOX"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/firefox/firefox.sh | bash"
    ["SPOTIFY"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/spotify/spotify.sh | bash"
    ["DOCKER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash"
    ["ARCADEMANAGER"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/arcademanager/arcademanager.sh | bash"
    ["CSPORTABLE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/csportable/csportable.sh | bash"
    ["BRAVE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/brave/brave.sh | bash"
    ["OPENRGB"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/openrgb/openrgb.sh | bash"
    ["WARZONE2100"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/warzone2100/warzone2100.sh | bash"
    ["XONOTIC"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/xonotic/xonotic.sh | bash"
    ["FIGHTCADE"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/fightcade/fightcade.sh | bash"
    ["SUPERTUXKART"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/supertuxkart/supertuxkart.sh | bash"
    ["OPENRA"]="curl -Ls https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/openra/openra.sh | bash"
)

descriptions=(
    ["SUNSHINE"]="Game streaming app for remote play on Batocera."
    ["MOONLIGHT"]="Stream PC games on Batocera."
    ["NVIDIAPATCHER"]="Enable NVIDIA GPU support on Batocera."
    ["SWITCH"]="Nintendo Switch emulator for Batocera."
    ["TAILSCALE"]="VPN service for secure Batocera connections."
    ["WINEMANAGER"]="Manage Windows games with Wine on Batocera."
    ["SHADPS4"]="Experimental PS4 streaming client."
    ["CONTY"]="Standalone Linux distro container."
    ["MINECRAFT"]="Minecraft: Java or Bedrock Edition."
    ["ARMAGETRON"]="Tron-style light cycle game."
    ["CLONEHERO"]="Guitar Hero clone for Batocera."
    ["VESKTOP"]="Discord client for Batocera."
    ["ENDLESS-SKY"]="Space exploration game."
    ["CHIAKI"]="PS4/PS5 Remote Play client."
    ["CHROME"]="Google Chrome web browser."
    ["AMAZON-LUNA"]="Amazon Luna game streaming client."
    ["PORTMASTER"]="Download and manage games on handhelds."
    ["GREENLIGHT"]="Client for xCloud and Xbox streaming."
    ["HEROIC"]="Epic, GOG, and Amazon Games launcher."
    ["YOUTUBE"]="YouTube client for Batocera."
    ["NETFLIX"]="Netflix streaming app for Batocera."
    ["IPTVNATOR"]="IPTV client for watching live TV."
    ["FIREFOX"]="Mozilla Firefox browser."
    ["SPOTIFY"]="Spotify music streaming client."
    ["DOCKER"]="Manage and run containerized apps."
    ["ARCADEMANAGER"]="Manage arcade ROMs and games."
    ["CSPORTABLE"]="Fan-made portable Counter-Strike."
    ["BRAVE"]="Privacy-focused Brave browser."
    ["OPENRGB"]="Manage RGB lighting on devices."
    ["WARZONE2100"]="Real-time strategy and tactics game."
    ["XONOTIC"]="Fast-paced open-source arena shooter."
    ["FIGHTCADE"]="Play classic arcade games online."
    ["SUPERTUXKART"]="Free and open-source kart racer."
    ["OPENRA"]="Modernized RTS for Command & Conquer."
)

# Define categories
declare -A categories
categories=(
    ["Games"]="MINECRAFT ARMAGETRON CLONEHERO ENDLESS-SKY AMAZON-LUNA PORTMASTER GREENLIGHT SHADPS4 CHIAKI SWITCH HEROIC CSPORTABLE WARZONE2100 XONOTIC FIGHTCADE SUPERTUXKART OPENRA"
    ["Utilities"]="TAILSCALE WINEMANAGER CONTY VESKTOP SUNSHINE MOONLIGHT CHROME YOUTUBE NETFLIX IPTVNATOR FIREFOX SPOTIFY ARCADEMANAGER BRAVE OPENRGB"
    ["Developer Tools"]="NVIDIAPATCHER CONTY DOCKER"
)

while true; do
    # Show category menu
    category_choice=$(dialog --menu "Choose a category" 15 70 4 \
        "Games" "Install games and game-related add-ons" \
        "Utilities" "Install utility apps" \
        "Developer Tools" "Install developer and patching tools" \
        "Password" "Enter or change the installer password" \
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
            "Utilities")
                selected_apps=$(echo "${categories["Utilities"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Developer Tools")
                selected_apps=$(echo "${categories["Developer Tools"]}" | tr ' ' '\n' | sort | tr '\n' ' ')
                ;;
            "Password")
                # Prompt for a password
                input_password=$(dialog --passwordbox "Enter the password to access the menu:" 8 40 2>&1 >/dev/tty)
                if [[ "$input_password" == "$password" ]]; then
                    selected_option=$(dialog --menu "Password-Protected Menu" 15 70 3 \
                        "Option1" "Install something awesome" \
                        "Option2" "Another hidden option" \
                        "Back" "Return to the main menu" 2>&1 >/dev/tty)
                    case "$selected_option" in
                        "Option1")
                            curl -Ls "$option1_url" | bash
                            ;;
                        "Option2")
                            dialog --msgbox "Option 2 is selected." 7 40
                            ;;
                        "Back")
                            break
                            ;;
                    esac
                else
                    dialog --title "Access Denied" --msgbox "Incorrect password." 5 40
                    sleep 3
                fi
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
