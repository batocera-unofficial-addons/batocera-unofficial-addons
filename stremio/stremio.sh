#!/bin/bash

# Set the application name
APPNAME="Stremio"

# Define paths
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LOGO_URL="https://blog.stremio.com/wp-content/uploads/2023/08/Stremio-logo-dark-background-1024x570.png"
LAUNCHER="${PORTS_DIR}/${APPNAME,,}.sh"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/${APPNAME,,}.png"
KEYS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/netflix/extra/Netflix.sh.keys"
KEYS_PATH="/userdata/roms/ports/stremio.sh.keys"

# Ensure xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null; then
    echo "xmlstarlet is not installed. Please install xmlstarlet before running this script."
    exit 1
fi

# Progress bar function using percentage from log
show_progress_bar_from_log() {
    local LOGFILE=$1  # Log file to monitor
    local PROGRESS=0  # Initial progress

    while kill -0 "$2" 2>/dev/null; do
        if [ -f "$LOGFILE" ]; then
            # Extract the latest percentage from the log file
            PROGRESS=$(grep -oE '[0-9]+%' "$LOGFILE" | tail -n 1 | tr -d '%')
            if [ -z "$PROGRESS" ]; then
                PROGRESS=0
            fi
            printf "\r[%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((PROGRESS / 2))))" "$PROGRESS"
        fi
        sleep 0.5
    done

    printf "\r[%-50s] 100%%\n" "$(printf '#%.0s' $(seq 1 50))"
}

# Add Flathub repository and install Stremio
install_stremio() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing Stremio..."
    local LOGFILE=/tmp/stremio_install.log

    # Run flatpak install in the background and monitor with progress bar
    flatpak install --system -y flathub com.stremio.Stremio &> "$LOGFILE" &
    show_progress_bar_from_log "$LOGFILE" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null

    echo "Stremio installation completed successfully."
}

# Ensure Stremio is listed in flatpak gamelist.xml and set it as hidden
hide_stremio_in_flatpak() {
    echo "Ensuring Stremio entry in flatpak gamelist.xml and setting it as hidden..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "Flatpak gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    if ! xmlstarlet sel -t -c "//game[path='./Stremio.flatpak']" "${FLATPAK_GAMELIST}" &>/dev/null; then
        echo "Stremio entry not found. Creating a new entry."
        xmlstarlet ed --inplace \
            -s "/gameList" -t elem -n game \
            -s "/gameList/game[last()]" -t elem -n path -v "./Stremio.flatpak" \
            -s "/gameList/game[last()]" -t elem -n name -v "Stremio" \
            -s "/gameList/game[last()]" -t elem -n image -v "./images/Stremio.png" \
            -s "/gameList/game[last()]" -t elem -n rating -v "0" \
            -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
            -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
            -s "/gameList/game[last()]" -t elem -n lang -v "en" \
            "${FLATPAK_GAMELIST}"
        echo "Stremio entry created and set as hidden."
    else
        echo "Stremio entry found. Ensuring hidden tag and updating all details."

        # Add <hidden> if it doesn't exist
        if ! xmlstarlet sel -t -c "//game[path='./Stremio.flatpak']/hidden" "${FLATPAK_GAMELIST}" &>/dev/null; then
            xmlstarlet ed --inplace \
                -s "//game[path='./Stremio.flatpak']" -t elem -n hidden -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Added missing hidden tag to Stremio entry."
        else
            # Update <hidden> value
            xmlstarlet ed --inplace \
                -u "//game[path='./Stremio.flatpak']/hidden" -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Updated hidden tag for Stremio entry."
        fi

        # Update other details
        xmlstarlet ed --inplace \
            -u "//game[path='./Stremio.flatpak']/name" -v "Stremio" \
            -u "//game[path='./Stremio.flatpak']/image" -v "./images/Stremio.png" \
            -u "//game[path='./Stremio.flatpak']/rating" -v "0" \
            -u "//game[path='./Stremio.flatpak']/releasedate" -v "19700101T010000" \
            -u "//game[path='./Stremio.flatpak']/lang" -v "en" \
            "${FLATPAK_GAMELIST}"
        echo "Updated details for Stremio entry."
    fi
}

# Create launcher for Stremio
create_launcher() {
    echo "Creating launcher for Stremio..."
    mkdir -p "${PORTS_DIR}"
    cat << EOF > "${LAUNCHER}"
#!/bin/bash
export QTWEBENGINE_DISABLE_SANDBOX=1
flatpak run com.stremio.Stremio --no-sandbox
EOF
    chmod +x "${LAUNCHER}"
    echo "Launcher created at ${LAUNCHER}."
}

# Add Stremio entry to Ports gamelist.xml
add_stremio_to_ports_gamelist() {
    echo "Adding Stremio entry to ports gamelist.xml..."
    mkdir -p "$(dirname "${PORTS_IMAGE_PATH}")"
    curl -fsSL "${LOGO_URL}" -o "${PORTS_IMAGE_PATH}"

    if [ ! -f "${PORTS_GAMELIST}" ]; then
        echo "Ports gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${PORTS_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./${APPNAME,,}.sh" \
        -s "/gameList/game[last()]" -t elem -n name -v "${APPNAME}" \
        -s "/gameList/game[last()]" -t elem -n desc -v "Stremio" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APPNAME,,}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
        "${PORTS_GAMELIST}"
    echo "Stremio entry added to ports gamelist.xml."
}

# Run all steps
install_stremio
hide_stremio_in_flatpak
create_launcher
add_stremio_to_ports_gamelist

# Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "$KEYS_PATH" "$KEYS_URL"

echo "Stremio setup completed successfully."
echo
dialog --msgbox "Installation complete!\n\nPlease head to Stremio settings and enable the Close Stremio when window is closed option" 10 60
