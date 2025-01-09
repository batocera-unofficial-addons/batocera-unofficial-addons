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

