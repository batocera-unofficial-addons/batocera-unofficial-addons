#!/bin/bash

# Set the application name
APPNAME="{{APP_NAME}}"

# Define paths
ADDONS_DIR="/userdata/system/add-ons/{{APP_NAME_LOWER}}"
PORTS_DIR="/userdata/roms/ports"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
LOGO_URL="{{LOGO_URL}}"
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

# Add Flathub repository and install application
install_app() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing ${APPNAME}..."
    local LOGFILE=/tmp/${APPNAME,,}_install.log

    # Run flatpak install in the background and monitor with progress bar
    flatpak install --system -y flathub {{FLATPAK_ID}} &> "$LOGFILE" &
    show_progress_bar_from_log "$LOGFILE" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null

    echo "${APPNAME} installation completed successfully."
}

# Overwrite the flatpak gamelist.xml with application entry
update_flatpak_gamelist() {
    echo "Updating flatpak gamelist.xml with ${APPNAME} entry..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./{{FLATPAK_DISPLAY_NAME}}.flatpak']" \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./{{FLATPAK_DISPLAY_NAME}}.flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "{{FLATPAK_DISPLAY_NAME}}" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/{{FLATPAK_DISPLAY_NAME}}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"

    echo "Flatpak gamelist.xml updated with ${APPNAME} entry."
}

# Create launcher for application
create_launcher() {
    echo "Creating launcher for ${APPNAME}..."
    mkdir -p "${ADDONS_DIR}"
    cat << EOF > "${LAUNCHER}"
#!/bin/bash
export XDG_RUNTIME_DIR=/run/user/$(id -u)
echo "Environment Variables:" > /userdata/system/logs/${APPNAME,,}_env.txt
env >> /userdata/system/logs/${APPNAME,,}_env.txt
echo "Launching ${APPNAME}..." >> /userdata/system/logs/${APPNAME,,}_debug.txt
/usr/bin/flatpak run {{FLATPAK_ID}}
EOF
    chmod +x "${LAUNCHER}"
    echo "Launcher created at ${LAUNCHER}."
}

create_shortcut() {
    echo "Creating shortcut for ${APPNAME}..."
    mkdir -p "${PORTS_DIR}"
    cat << EOF > "${PORTS_SHORTCUT}"
#!/bin/bash
cd /userdata/system/add-ons/{{APP_NAME_LOWER}}
./launcher
EOF
    chmod +x "${PORTS_SHORTCUT}"
    echo "Shortcut created at ${PORTS_SHORTCUT}."
}

# Add application entry to Ports gamelist.xml
add_app_to_ports_gamelist() {
    echo "Adding ${APPNAME} entry to ports gamelist.xml..."
    mkdir -p "$(dirname "${PORTS_IMAGE_PATH}")"
    curl -fsSL "${LOGO_URL}" -o "${PORTS_IMAGE_PATH}"

    if [ ! -f "${PORTS_GAMELIST}" ]; then
        echo "<gameList />" > "${PORTS_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./${APPNAME}.sh" \
        -s "/gameList/game[last()]" -t elem -n name -v "${APPNAME}" \
        -s "/gameList/game[last()]" -t elem -n desc -v "{{APP_DESCRIPTION}}" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APPNAME,,}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
        "${PORTS_GAMELIST}"
    echo "${APPNAME} entry added to ports gamelist.xml."
}

# Run all steps
install_app
update_flatpak_gamelist
create_launcher
create_shortcut
add_app_to_ports_gamelist

echo "${APPNAME} setup completed successfully."
