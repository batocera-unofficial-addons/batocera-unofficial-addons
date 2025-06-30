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

GAMELIST_ENTRY_CONTENT="	<game>
		<path>./${PORT_SCRIPT_NAME}</path>
		<name>${APP_NAME}</name>
		<desc>=========================================
Discord: discord.gg/KnV6hNzrqT
YouTube: youtube.com/@kevsbatocerabuilds
Developer: KevoBatoYT
=========================================</desc>
		<image>./images/${APP_EXEC}-thumb.png</image>
		<marquee>./images/${APP_EXEC}-marquee.png</marquee>
		<thumbnail>./images/${APP_EXEC}-marquee.png</thumbnail>
		<fanart>./images/${APP_EXEC}-thumb.png</fanart>
		<titleshot>./images/${APP_EXEC}-thumb.png</titleshot>
		<cartridge>./images/${APP_EXEC}-thumb.png</cartridge>
		<boxart>./images/${APP_EXEC}-marquee.png</boxart>
		<boxback>./images/${APP_EXEC}-thumb.png</boxback>
		<wheel>./images/${APP_EXEC}-thumb.png</wheel>
		<mix>./images/${APP_EXEC}-thumb.png</mix>
		<rating>1</rating>
		<developer>KevoBatoYT</developer>
		<publisher>KevoBatoYT</publisher>
		<players>1</players>
		<favorite>true</favorite>
		<lang>en</lang>
		<sortname>1 =- ${APP_NAME}</sortname>
		<genreid>0</genreid>
		<screenshot>./images/${APP_EXEC}-thumb.png</screenshot>
	</game>"

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

# Function to create backup
create_backup() {
    if [ -f "$GAMELIST_PATH" ]; then
        cp -rf "$GAMELIST_PATH" "$BACKUP_PATH"
        echo "gamelist.xml backup created at: $BACKUP_PATH"
    fi
}

# Function to create new gamelist.xml
create_new_gamelist() {
    echo "Creating new gamelist.xml file..."
    cat > "$GAMELIST_PATH" << EOF
<?xml version="1.0"?>
<gameList>
${GAMELIST_ENTRY_CONTENT}
</gameList>
EOF
    echo "gamelist.xml file created successfully!"
}

# Function to check if the entry already exists
check_entry() {
    if [ -f "$GAMELIST_PATH" ]; then
        grep -q "<path>./${PORT_SCRIPT_NAME}</path>" "$GAMELIST_PATH"
        return $?
    else
        return 1
    fi
}

# Function to remove the existing entry (using awk)
remove_entry() {
    echo "Removing existing entry..."
    TEMP_FILE=$(mktemp)
    awk -v script_name="${PORT_SCRIPT_NAME}" '
        BEGIN { game_block = ""; in_game = 0; is_target = 0; }
        /<game>/ { in_game = 1; game_block = $0; is_target = 0; }
        in_game && ! /<game>/ { game_block = game_block "\n" $0 }
        in_game && $0 ~ "<path>./" script_name "</path>" { is_target = 1 }
        /<\/game>/ {
            if (!is_target) { print game_block }
            in_game = 0; game_block = "";
            next
        }
        !in_game { print }
    ' "$GAMELIST_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$GAMELIST_PATH"
    echo "Existing entry removed."
}

# Function to add the entry (using awk)
add_entry() {
    echo "Adding new entry..."
    TEMP_FILE=$(mktemp)
    awk -v entry="${GAMELIST_ENTRY_CONTENT}" '
        /<\/gameList>/ { print entry }
        { print }
    ' "$GAMELIST_PATH" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$GAMELIST_PATH"
    echo "New entry added."
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

# ----------------------------------
clear

# 2. Directory Creation
echo "Creating necessary directories..."
mkdir -p "$DESKTOP_DIR" || error_exit "Failed to create $DESKTOP_DIR"
mkdir -p "$IMAGES_DIR" || error_exit "Failed to create $IMAGES_DIR"
chmod 777 "$GAMELIST_PATH"
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
echo "Updating gamelist.xml..."
if [ ! -f "$GAMELIST_PATH" ] || [ ! -s "$GAMELIST_PATH" ]; then
    create_new_gamelist
else
    create_backup
    if check_entry; then
        remove_entry
    fi
    add_entry
fi
echo "Gamelist.xml updated."
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
