#!/bin/bash

# Set the application name
APPNAME="Parsec"

# Define paths
ADDONS_DIR="/userdata/system/add-ons/parsec"
PORTS_DIR="/userdata/roms/ports"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LOGO_URL="https://dotesports.com/wp-content/uploads/2021/09/09081441/Parsec-logo-1.png"
LAUNCHER="${ADDONS_DIR}/launcher"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/${APPNAME,,}.png"
PORTS_SHORTCUT="${PORTS_DIR}/${APPNAME}.sh"

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
    flatpak install --system -y flathub com.parsecgaming.parsec &> "$LOGFILE" &
    show_progress_bar_from_log "$LOGFILE" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null

    echo "Parsec installation completed successfully."
}

# Overwrite the flatpak gamelist.xml with Parsec entry
update_flatpak_gamelist() {
    echo "Updating flatpak gamelist.xml with Parsec entry..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./Parsec Cloud, Inc..flatpak']" \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./Parsec Cloud, Inc..flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "Parsec Cloud, Inc." \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/Parsec Cloud, Inc..png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"

    echo "Flatpak gamelist.xml updated with Parsec entry."
}

# Create launcher for Parsec
create_launcher() {
    echo "Creating launcher for Parsec..."
    mkdir -p "${ADDONS_DIR}"
    cat << EOF > "${LAUNCHER}"
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
echo "Environment Variables:" > /userdata/system/logs/parsec_env.txt
env >> /userdata/system/logs/parsec_env.txt
echo "Launching Parsec..." >> /userdata/system/logs/parsec_debug.txt
/usr/bin/flatpak run com.parsecgaming.parsec
EOF
    chmod +x "${LAUNCHER}"
    echo "Launcher created at ${LAUNCHER}."
}

create_shortcut() {
    echo "Creating shortcut for Parsec..."
    mkdir -p "${PORTS_DIR}"
    cat << EOF > "${PORTS_SHORTCUT}"
#!/bin/bash
cd /userdata/system/add-ons/parsec
./launcher
EOF
    chmod +x "${PORTS_SHORTCUT}"
    echo "Shortcut created at ${PORTS_SHORTCUT}."
}
# Add Parsec entry to Ports gamelist.xml
add_parsec_to_ports_gamelist() {
    echo "Adding Parsec entry to ports gamelist.xml..."
    mkdir -p "$(dirname "${PORTS_IMAGE_PATH}")"
    curl -fsSL "${LOGO_URL}" -o "${PORTS_IMAGE_PATH}"

    if [ ! -f "${PORTS_GAMELIST}" ]; then
        echo "<gameList />" > "${PORTS_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./${APPNAME}.sh" \
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
update_flatpak_gamelist
create_launcher
create_shortcut
add_parsec_to_ports_gamelist

echo "Parsec setup completed successfully."
