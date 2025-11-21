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

# Ensure Bottles is listed in flatpak gamelist.xml and set it as hidden
hide_bottles_in_flatpak() {
    echo "Ensuring Bottles entry in flatpak gamelist.xml and setting it as hidden..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "Flatpak gamelist.xml not found. Creating a new one."
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    if ! xmlstarlet sel -t -c "//game[path='./The Bottles Contributors.flatpak']" "${FLATPAK_GAMELIST}" &>/dev/null; then
        echo "Bottles entry not found. Creating a new entry."
        xmlstarlet ed --inplace \
            -s "/gameList" -t elem -n game \
            -s "/gameList/game[last()]" -t elem -n path -v "./The Bottles Contributors.flatpak" \
            -s "/gameList/game[last()]" -t elem -n name -v "The Bottles Contributors" \
            -s "/gameList/game[last()]" -t elem -n image -v "./images/Bottles.png" \
            -s "/gameList/game[last()]" -t elem -n rating -v "0" \
            -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
            -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
            -s "/gameList/game[last()]" -t elem -n lang -v "en" \
            "${FLATPAK_GAMELIST}"
        echo "Bottles entry created and set as hidden."
    else
        echo "Bottles entry found. Ensuring hidden tag and updating all details."

        # Add <hidden> if it doesn't exist
        if ! xmlstarlet sel -t -c "//game[path='./The Bottles Contributors.flatpak']/hidden" "${FLATPAK_GAMELIST}" &>/dev/null; then
            xmlstarlet ed --inplace \
                -s "//game[path='./The Bottles Contributors.flatpak']" -t elem -n hidden -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Added missing hidden tag to Bottles entry."
        else
            # Update <hidden> value
            xmlstarlet ed --inplace \
                -u "//game[path='./The Bottles Contributors.flatpak']/hidden" -v "true" \
                "${FLATPAK_GAMELIST}"
            echo "Updated hidden tag for Bottles entry."
        fi

        # Update other details
        xmlstarlet ed --inplace \
            -u "//game[path='./The Bottles Contributors.flatpak']/name" -v "Bottles" \
            -u "//game[path='./The Bottles Contributors.flatpak']/image" -v "./images/Bottles.png" \
            -u "//game[path='./The Bottles Contributors.flatpak']/rating" -v "0" \
            -u "//game[path='./The Bottles Contributors.flatpak']/releasedate" -v "19700101T010000" \
            -u "//game[path='./The Bottles Contributors.flatpak']/lang" -v "en" \
            "${FLATPAK_GAMELIST}"
        echo "Updated details for Bottles entry."
    fi
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
hide_bottles_in_flatpak
create_launcher

echo "✅ ${APPNAME} setup complete with desktop entry."
sleep 5
