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
check_xmlstarlet() {
    if ! command -v xmlstarlet &> /dev/null; then
        echo "xmlstarlet is not installed. Please install xmlstarlet before running this script."
        exit 1
    fi
}

# Install Plex via Flatpak
install_plex() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing Plex..."
    flatpak install -y flathub tv.plex.PlexHTPC

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update
}

# Ensure Plex is listed in flatpak gamelist.xml and set it as hidden
hide_plex_in_flatpak() {
    echo "Ensuring Plex entry in flatpak gamelist.xml and setting it as hidden..."
    
    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "Flatpak gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    if ! xmlstarlet sel -t -c "//game[name='Plex']" "${FLATPAK_GAMELIST}" &>/dev/null; then
        echo "Plex entry not found. Creating a new entry."
        xmlstarlet ed --inplace \
            -s "/gameList" -t elem -n game \
            -s "/gameList/game[last()]" -t elem -n path -v "./Plex.flatpak" \
            -s "/gameList/game[last()]" -t elem -n name -v "Plex" \
            -s "/gameList/game[last()]" -t elem -n image -v "./images/Plex.png" \
            -s "/gameList/game[last()]" -t elem -n rating -v "0" \
            -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
            -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
            "${FLATPAK_GAMELIST}"
        echo "Plex entry created and set as hidden."
    else
        echo "Plex entry found. Updating hidden status."
        xmlstarlet ed --inplace \
            -s "//game[name='Plex']" -t elem -n hidden -v true \
            "${FLATPAK_GAMELIST}"
        echo "Hidden status updated for Plex."
    fi
}

# Create launcher for Plex
create_launcher() {
    echo "Creating launcher for Plex..."
    mkdir -p "${PORTS_DIR}"
    cat << EOF > "${LAUNCHER}"
#!/bin/bash
flatpak run tv.plex.PlexHTPC --no-sandbox
EOF
    chmod +x "${LAUNCHER}"
    echo "Launcher created at ${LAUNCHER}."
}

# Add Plex entry to ports gamelist.xml
add_plex_to_ports_gamelist() {
    echo "Adding Plex entry to ports gamelist.xml..."
    
    # Download the logo for Plex
    mkdir -p "$(dirname "${PORTS_IMAGE_PATH}")"
    if ! curl -fsSL "${LOGO_URL}" -o "${PORTS_IMAGE_PATH}"; then
        echo "Failed to download logo from ${LOGO_URL}. Using default placeholder."
        echo "<gameList />" > "${PORTS_IMAGE_PATH}"
    fi

    if [ ! -f "${PORTS_GAMELIST}" ]; then
        echo "Ports gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${PORTS_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./${APPNAME,,}.sh" \
        -s "/gameList/game[last()]" -t elem -n name -v "${APPNAME}" \
        -s "/gameList/game[last()]" -t elem -n desc -v "Plex Media Player" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APPNAME,,}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
        "${PORTS_GAMELIST}"
    echo "Plex entry added to ports gamelist.xml."
}

        check_xmlstarlet
        install_plex
        hide_plex_in_flatpak
        create_launcher
        add_plex_to_ports_gamelist
        echo "Plex setup completed successfully."
