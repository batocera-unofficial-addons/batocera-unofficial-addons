#!/bin/bash

# --- Variables ---
APP_NAME="Everest"
APP_ID="io.github.everestapi.Olympus"
APP_EXEC="Everest"
DESKTOP_DIR="/userdata/system/.local/share/applications"
PATH_DESKTOP="/userdata/system/Desktop/${APP_EXEC}.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_EXEC}.desktop"
PORTS_DIR="/userdata/roms/ports"
IMAGES_DIR="${PORTS_DIR}/images"
GAMELIST_PATH="${PORTS_DIR}/gamelist.xml"
BACKUP_PATH="${PORTS_DIR}/gamelist.xml.DRL"
BIN_DIR="${PORTS_DIR}"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"

# URLs
MARQUEE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/blob/main/everest/extra/everest-marquee.jpg?raw=true"
THUMB_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/blob/main/everest/extra/everest-thumb.png?raw=true"

MARQUEE_IMG="${IMAGES_DIR}/${APP_EXEC}-marquee.png"
THUMB_IMG="${IMAGES_DIR}/${APP_EXEC}-thumb.png"
PORT_SCRIPT_PATH="${PORTS_DIR}/${APP_EXEC}.sh"
PORT_SCRIPT_NAME="${APP_EXEC}.sh"

# --- File Contents ---

DESKTOP_CONTENT="[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Exec=${PORTS_DIR}/${APP_EXEC}.sh
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=${MARQUEE_IMG}
"

PORT_SCRIPT_CONTENT="#!/bin/bash
flatpak --filesystem="/userdata/" --filesystem=host:/:rw --filesystem=host --filesystem="/media" run $APP_ID
"


# --- Functions ---


# Function to display error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Function to download files
download_file() {
    local url="$1"
    local output_path="$2"
    echo "Downloading '$url' to '$output_path'..."
    wget -q -O "$output_path" "$url"
    if [ $? -ne 0 ]; then
        error_exit "Failed to download $url. Check the link and your connection."
    fi
    echo "Download complete."
}

# Add Everest entry to Ports gamelist.xml
add_everest_to_ports_gamelist() {
    echo "Adding ${APP_NAME} entry to ports gamelist.xml..."
    mkdir -p "$(dirname "${THUMB_IMG}")"

    if [ ! -f "${GAMELIST_PATH}" ]; then
        echo "<gameList />" > "${GAMELIST_PATH}"
    fi

    # Ensure xmlstarlet is installed
    if ! command -v xmlstarlet &> /dev/null; then
        echo "xmlstarlet is not installed. Please install xmlstarlet before running this script."
        exit 1
    fi

    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./${PORT_SCRIPT_NAME}" \
        -s "/gameList/game[last()]" -t elem -n name -v "${APP_NAME}" \
        -s "/gameList/game[last()]" -t elem -n desc -v "=========================================
Discord: discord.gg/KnV6hNzrqT
YouTube: youtube.com/@kevsbatocerabuilds
Developer: KevoBatoYT
=========================================" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n marquee -v "./images/${APP_EXEC}-marquee.png" \
        -s "/gameList/game[last()]" -t elem -n thumbnail -v "./images/${APP_EXEC}-marquee.png" \
        -s "/gameList/game[last()]" -t elem -n fanart -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n titleshot -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n cartridge -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n boxart -v "./images/${APP_EXEC}-marquee.png" \
        -s "/gameList/game[last()]" -t elem -n boxback -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n wheel -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n mix -v "./images/${APP_EXEC}-thumb.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "1" \
        -s "/gameList/game[last()]" -t elem -n developer -v "KevoBatoYT" \
        -s "/gameList/game[last()]" -t elem -n publisher -v "KevoBatoYT" \
        -s "/gameList/game[last()]" -t elem -n players -v "1" \
        -s "/gameList/game[last()]" -t elem -n favorite -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        -s "/gameList/game[last()]" -t elem -n sortname -v "1 =- ${APP_NAME}" \
        -s "/gameList/game[last()]" -t elem -n genreid -v "0" \
        -s "/gameList/game[last()]" -t elem -n screenshot -v "./images/${APP_EXEC}-thumb.png" \
        "${GAMELIST_PATH}"
    echo "${APP_NAME} entry added to ports gamelist.xml."
}

# Overwrite the flatpak gamelist.xml with Everest entry
update_flatpak_gamelist() {
    echo "Updating flatpak gamelist.xml with Everest entry..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    # Ensure xmlstarlet is installed
    if ! command -v xmlstarlet &> /dev/null; then
        echo "xmlstarlet is not installed. Skipping flatpak gamelist update."
        return
    fi

    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./Everest Team.flatpak']" \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./Everest Team.flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "Everest Team" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/Everest Team.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"

    echo "Flatpak gamelist.xml updated with Everest entry."
}


# --- Main Execution ---

# 1. Initial Presentation
echo "Starting the installation..."
echo "Everest for Batocera"
sleep 2 # Pause for viewing
clear

# ----------------------------------

echo "Ensuring Flathub user remote is added..."
if ! flatpak remote-list --user | grep -q "^flathub"; then
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "Flathub remote added for user."
else
    echo "Flathub remote already present for user."
fi

echo "Installing Everest Flatpak (user install)..."
flatpak install --user -y flathub "$APP_ID"

echo "Setting permissions to allow full filesystem access..."
flatpak override --filesystem="/userdata/" --filesystem=host:/:rw --filesystem=host --filesystem="/media"  "$APP_ID"

echo "Updating Batocera Flatpaks..."
batocera-flatpak-update &> /dev/null

# Update flatpak gamelist to hide the default entry
update_flatpak_gamelist

# ----------------------------------
clear

# 2. Directory Creation
echo "Creating necessary directories..."
mkdir -p "$DESKTOP_DIR" || error_exit "Failed to create $DESKTOP_DIR"
mkdir -p "$IMAGES_DIR" || error_exit "Failed to create $IMAGES_DIR"
echo "Directories created."

# 3. .desktop File Creation
echo "Creating .desktop file..."
echo "$DESKTOP_CONTENT" > "$DESKTOP_FILE" || error_exit "Failed to create $DESKTOP_FILE"
echo "$DESKTOP_CONTENT" > "$PATH_DESKTOP" || error_exit "Failed to create $PATH_DESKTOP"
echo ".desktop file created at $DESKTOP_FILE and $PATH_DESKTOP"

# 4. Image Download
download_file "$MARQUEE_URL" "$MARQUEE_IMG"
download_file "$THUMB_URL" "$THUMB_IMG"

# 5. Ports Script Creation
echo "Creating ports script..."
echo "$PORT_SCRIPT_CONTENT" > "$PORT_SCRIPT_PATH" || error_exit "Failed to create $PORT_SCRIPT_PATH"
chmod 777 "$PORT_SCRIPT_PATH" || error_exit "Failed to make $PORT_SCRIPT_PATH executable."
echo "Ports script created."

# 6. gamelist.xml Update
add_everest_to_ports_gamelist
clear

# 7. Final Message
echo ""
echo "========================================="
echo "  Installation Complete!"
echo "========================================="
echo "Everest Flatpak installed and launcher created!"
echo "You may need to restart EmulationStation for the changes"
echo "in the gamelist.xml and the new shortcut to appear."
echo ""

exit 0
