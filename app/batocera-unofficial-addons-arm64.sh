#!/bin/bash

LAUNCH_PATH="/userdata/roms/ports/bua.sh"

install_bua() {
    curl -L install.batoaddons.app | bash
}

if grep -q 'DIALOGRC' "$LAUNCH_PATH"; then
    rm -f /userdata/roms/ports/bua.sh.keys
    install_bua
    dialog --title "UPDATED" --msgbox \
		"BUA has been updated! A whole new look! Please report any issues to the discord!\n\nJust reopen the app to take a look..." 10 60
    exit 0
fi

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
    echo " Instead; head to https://discord.batoaddons.app and someone will be around to help you!"
    echo " For guides, head to the Wiki at https://wiki.batoaddons.app"
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
    ["CHIAKI"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/chiaki/chiaki.sh | bash"
    ["CONTY"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/conty/conty.sh | bash"
    ["DOCKER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/docker/docker.sh | bash"
    ["IPTVNATOR"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/iptvnator/iptvnator.sh | bash"
    ["PORTMASTER"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/portmaster/portmaster.sh | bash"
    ["TAILSCALE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/tailscale/tailscale.sh | bash"
    ["TELEGRAF"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/telegraf/telegraf.sh | bash"
    ["VESKTOP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/vesktop/vesktop.sh | bash"
    ["MINECRAFT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/minecraft/bedrock.sh | bash"
    ["FREETUBE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/freetube/freetube.sh | bash"
    ["SUPERMARIOX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/supermariox/supermariox.sh | bash"
    ["SUPERTUXKART"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/supertuxkart/supertuxkart.sh | bash"
    ["CELESTE64"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/celeste64/celeste64.sh | bash"
    ["F1"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/f1/f1.sh | bash"
    ["FIREFOX"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/firefox/firefox-arm64.sh | bash"
    ["DESKTOP"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/desktop/desktop.sh | bash"
    ["GREENLIGHT"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/greenlight/greenlight_arm64.sh | bash"
    ["AMAZON-LUNA"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/amazonluna/amazonluna-arm64.sh | bash"
    ["SOAR"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/soar/soar.sh | bash"
    ["WAYVNC"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc/wayvnc.sh | bash"
    ["WAYVNC-HEADLESS"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/wayvnc_headless/wayvnc_headless.sh | bash"
    ["DARK-MODE"]="curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/dark/dark.sh | bash"
)


descriptions=(
    ["TAILSCALE"]="VPN service for secure Batocera connections."
    ["TELEGRAF"]="Server agent for collecting and reporting metrics."
    ["CONTY"]="Standalone Linux distro container."
    ["VESKTOP"]="Discord client for Batocera."
    ["CHIAKI"]="PS4/PS5 Remote Play client."
    ["PORTMASTER"]="Download and manage games on handhelds."
    ["IPTVNATOR"]="IPTV client for watching live TV."
    ["DOCKER"]="Manage and run containerized apps."
    ["MINECRAFT"]="Minecraft Bedrock Edition."
    ["FREETUBE"]="An Open Source Desktop YouTube Player For Privacy-minded People"
    ["SUPERMARIOX"]="The greatest fan-made tribute to Super Mario of all time!"
    ["SUPERTUXKART"]="Free and open-source kart racer."
    ["CELESTE64"]="Requires OpenGL 3.2. Free 3D platformer, based around Celeste Mountain"
    ["F1"]="Adds a shortcut in Ports to open the file manager."
    ["FIREFOX"]="Mozilla Firefox browser."
    ["DESKTOP"]="Adds desktop mode to Batocera access it via Ports."
    ["GREENLIGHT"]="Client for xCloud and Xbox streaming."
    ["AMAZON-LUNA"]="Amazon Luna game streaming client."
    ["SOAR"]="Soar package manager integrated with BUA"
    ["WAYVNC"]="WayVNC for remote access"
    ["WAYVNC-HEADLESS"]="WayVNC for headless systems"
    ["DARK-MODE"]="Custom service to enable/disable F1 dark mode"
)


# Define categories
declare -A categories
categories=(
    ["Games"]="MINECRAFT SUPERMARIOX SUPERTUXKART CELESTE64"
    ["Game Utilities"]="PORTMASTER CHIAKI GREENLIGHT AMAZON-LUNA"
    ["System Utilities"]="TAILSCALE TELEGRAF VESKTOP IPTVNATOR FREETUBE F1 FIREFOX DESKTOP"
    ["Developer Tools"]="CONTY DOCKER SOAR WAYVNC WAYVNC-HEADLESS DARK-MODE"
)

while true; do
    # Show category menu
    category_choice=$(dialog --stdout --menu "Choose a category" 15 70 4 \
        "Games" "Install Linux native games" \
        "Game Utilities" "Install game related add-ons" \
        "System Utilities" "Install utility apps" \
        "Developer Tools" "Install developer and patching tools" \
        "Updater" "Install the latest updates to your add-ons" \
        "Exit" "Exit the installer")

# Exit if the user selects "Exit" or cancels
if [[ $? -ne 0 || "$category_choice" == "Exit" ]]; then
    dialog --title "Exiting Installer" --infobox "Thank you for using the Batocera Unofficial Add-Ons Installer. For support; https://discord.batoaddons.app or https://wiki.batoaddons.app. Goodbye!" 7 50
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
            "Docker Menu")
               ( curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/docker/menu.sh | bash )
                break
                ;;
            "Updater")
                ( curl -Ls https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/app/updater.sh | bash )
                break
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
        cmd=(dialog --stdout --separate-output --checklist "Select applications to install or update:" 22 95 16)
        choices=$("${cmd[@]}" "${app_list[@]}")

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
