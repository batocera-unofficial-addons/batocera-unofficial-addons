#!/bin/bash

# Set the application name
APPNAME="Bottles"

# Define paths
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
ICON_URL="https://cdn2.steamgriddb.com/logo/b6971181414fe808396c6883eb262e8d.png"
ICON_PATH="/userdata/system/add-ons/${APPNAME,,}/extra/${APPNAME,,}-icon.png"
DESKTOP_ENTRY="/userdata/system/configs/${APPNAME,,}/${APPNAME,,}.desktop"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"

mkdir -p "/userdata/system/add-ons/${APPNAME,,}/extra"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

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

# Add Flathub repository and install Bottles
install_bottles() {
    echo "Adding Flathub repository..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    echo "Installing Bottles..."
    local LOGFILE=/tmp/bottles_install.log

    # Run flatpak install in the background and monitor with progress bar
    flatpak install --system -y flathub com.usebottles.bottles &> "$LOGFILE" &
    show_progress_bar_from_log "$LOGFILE" $!

    echo "Updating Batocera Flatpaks..."
    batocera-flatpak-update &> /dev/null
    
    # Add /userdata to be accessible
    flatpak override com.usebottles.bottles --filesystem=/userdata:rw

    echo "Bottles installation completed successfully."
}

# Overwrite the flatpak gamelist.xml with Bottles entry
update_flatpak_gamelist() {
    echo "Updating flatpak gamelist.xml with Bottles entry..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./The Bottles Contributors.flatpak']" \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./The Bottles Contributors.flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "The Bottles Contributors" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/Bottles.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"

    echo "Flatpak gamelist.xml updated with Bottles entry."
}

# Create launcher for Bottles
create_launcher() {
# Download icon
curl -L -o "$ICON_PATH" "$ICON_URL"

# Create desktop entry
cat <<EOF > "${DESKTOP_ENTRY}"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=flatpak run com.usebottles.bottles
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;batocera.linux;
EOF

cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
chmod +x "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"

# Restore script for .desktop
cat <<EOF > "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "${DESKTOP_DIR}/${APPNAME,,}.desktop" ]; then
    cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
    chmod +x "${DESKTOP_DIR}/${APPNAME,,}.desktop"
fi
EOF
chmod +x "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

# Add restore script to custom.sh if not already added
if ! grep -q "restore_desktop_entry.sh" "${CUSTOM_SCRIPT}" 2>/dev/null; then
    echo "\"/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh\" &" >> "${CUSTOM_SCRIPT}"
fi
}

# Run all steps
install_bottles
update_flatpak_gamelist
create_launcher

echo "✅ ${APPNAME} setup complete with desktop entry."
sleep 5
