#!/bin/bash

# Set the application name
APPNAME="Parsec"

# Define paths
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LOGO_URL="https://dotesports.com/wp-content/uploads/2021/09/09081441/Parsec-logo-1.png"
LAUNCHER="${PORTS_DIR}/${APPNAME,,}.sh"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/${APPNAME,,}.png"

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

# Add Flathub repository and install Parsec
install_parsec() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing Parsec..."
    local LOGFILE=/tmp/parsec_install.log

    # Run flatpak install in the background and monitor with progress bar
    flatpak install -y flathub com.parsecgaming.parsec &> "$LOGFILE" &
    show_progress_bar_from_log "$LOGFILE" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null

    echo "Parsec installation completed successfully."
}

# Ensure Parsec is listed in flatpak gamelist.xml and set it as hidden
hide_parsec_in_flatpak() {
    echo "Ensuring Parsec entry in flatpak gamelist.xml and setting it as hidden..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "Flatpak gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    if ! xmlstarlet sel -t -c "//game[path='./Parsec Cloud, Inc..flatpak']" "${FLATPAK_GAMELIST}" &>/dev/null; then
        echo "Parsec entry not found. Creating a new entry."
        xmlstarlet ed --inplace \
            -s "/gameList" -t elem -n game \
            -s "/gameList/game[last()]" -t elem -n path -v "./Parsec Cloud, Inc..flatpak" \
            -s "/gameList/game[last()]" -t elem -n name -v "Parsec Cloud, Inc." \
            -s "/gameList/game[last()]" -t elem -n image -v "./images/Parsec Cloud, Inc..png" \
            -s "/gameList/game[last()]" -t elem -n rating -v "" \
            -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
            -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
            "${FLATPAK_GAMELIST}"
        echo "Parsec entry created and set as hidden."
    else
        echo "Parsec entry found. Ensuring hidden tag and updating all details."

        # Add <hidden> if it doesn't exist
        if ! xmlstarlet sel -t -c "//game[path='./Parsec Cloud, Inc..flatpak']/hidden" "${FLATPAK_GAMELIST}" &>/dev/null; then
            xmlstarlet ed --inplace \
                -s "//game[path='./Parsec Cloud, Inc..flatpak']" -t elem -n hidden -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Added missing hidden tag to Parsec entry."
        else
            # Update <hidden> value
            xmlstarlet ed --inplace \
                -u "//game[path='./Parsec Cloud, Inc..flatpak']/hidden" -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Updated hidden tag for Parsec entry."
        fi

        # Update other details
        xmlstarlet ed --inplace \
            -u "//game[path='./Parsec Cloud, Inc..flatpak']/name" -v "Parsec Cloud, Inc." \
            -u "//game[path='./Parsec Cloud, Inc..flatpak']/image" -v "./images/Parsec Cloud, Inc..png" \
            -u "//game[path='./Parsec Cloud, Inc..flatpak']/rating" -v "" \
            -u "//game[path='./Parsec Cloud, Inc..flatpak']/releasedate" -v "" \
            "${FLATPAK_GAMELIST}"
        echo "Updated details for Parsec entry."
    fi
}

# Create launcher for Parsec
create_launcher() {
    echo "Creating launcher for Parsec..."
    mkdir -p "${PORTS_DIR}"
    cat << EOF > "${LAUNCHER}"
#!/bin/bash
flatpak run com.parsecgaming.parsec
EOF
    chmod +x "${LAUNCHER}"
    echo "Launcher created at ${LAUNCHER}."
}

# Add Parsec entry to Ports gamelist.xml
add_parsec_to_ports_gamelist() {
    echo "Adding Parsec entry to ports gamelist.xml..."
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
        -s "/gameList/game[last()]" -t elem -n desc -v "Parsec Cloud Gaming" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APPNAME,,}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
        "${PORTS_GAMELIST}"
    echo "Parsec entry added to ports gamelist.xml."
}

# Run all steps
install_parsec
hide_parsec_in_flatpak
create_launcher
add_parsec_to_ports_gamelist

echo "Parsec setup completed successfully."
