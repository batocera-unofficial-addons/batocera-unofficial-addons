#!/bin/bash

# Set the application name
APPNAME="Plex"

# Define paths
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LOGO_URL="https://static1.howtogeekimages.com/wordpress/wp-content/uploads/2023/03/Plex-logo.jpg"
LAUNCHER="${PORTS_DIR}/${APPNAME,,}.sh"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/${APPNAME,,}.png"

# Ensure xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null; then
    echo "xmlstarlet is not installed. Please install xmlstarlet before running this script."
    exit 1
fi

# Progress bar function
show_progress_bar() {
    local DURATION=$1  # Estimated duration in seconds
    local PROGRESS=0   # Starting progress
    local STEP=$((DURATION / 100)) # Time per percentage step

    while kill -0 "$2" 2>/dev/null; do
        printf "\r[%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((PROGRESS / 2))))" "$PROGRESS"
        sleep "$STEP"
        PROGRESS=$((PROGRESS + 1))
        if [ "$PROGRESS" -gt 100 ]; then
            PROGRESS=100
            break
        fi
    done
    printf "\r[%-50s] 100%%\n" "$(printf '#%.0s' $(seq 1 50))"
}

# Add Flathub repository and install Plex
install_plex() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing Plex..."
    local ESTIMATED_DURATION=120 # Adjust based on your system's performance

    # Run flatpak install in the background and monitor with progress bar
    flatpak install -y flathub tv.plex.PlexHTPC &> /tmp/plex_install.log &
    show_progress_bar "$ESTIMATED_DURATION" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null

    echo "Plex installation completed successfully."
}

# Other functions remain unchanged...
# For brevity, include hide_plex_in_flatpak, create_launcher, and add_plex_to_ports_gamelist here...

# Run all steps
install_plex
hide_plex_in_flatpak
create_launcher
add_plex_to_ports_gamelist

echo "Plex setup completed successfully."
