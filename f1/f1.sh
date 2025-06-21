#!/bin/bash

# Set variables
APP_NAME="F1"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/f1/extra/f1key.jpg"   # Replace with actual logo URL
LOGO_PATH="/userdata/roms/ports/images/${APP_NAME,,}-logo.jpg"
GAME_LIST="/userdata/roms/ports/gamelist.xml"

# Temporary directory for download
TEMP_DIR="/userdata/tmp/Antimicrox"
DRL_FILE="$TEMP_DIR/Antimicrox.DRL"
EXTRACT_DIR="$TEMP_DIR/extracted"
DEST_DIR="/"
PORTS_DIR="/userdata/roms/ports"
MARQUEE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/f1/extra/f1key.jpg"
THUMB_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/f1/extra/f1key.jpg"

MARQUEE_IMG="${IMAGES_DIR}/${APP_NAME}-marquee.png"
THUMB_IMG="${IMAGES_DIR}/${APP_NAME}-thumb.png"
PORT_SCRIPT_PATH="${PORTS_DIR}/${APP_NAME}.sh"
PORT_SCRIPT_NAME="${APP_NAME}.sh"

GAMELIST_ENTRY_CONTENT="	<game>
		<path>./${APP_NAME}</path>
		<name>${APP_NAME}</name>
		<image>./images/${APP_NAME}-thumb.png</image>
		<marquee>./images/${APP_NAME}-marquee.png</marquee>
		<thumbnail>./images/${APP_NAME}-thumb.png</thumbnail>
		<fanart>./images/${APP_NAME}-thumb.png</fanart>
		<titleshot>./images/${APP_NAME}-thumb.png</titleshot>
		<cartridge>./images/${APP_NAME}-thumb.png</cartridge>
		<boxart>./images/${APP_NAME}-marquee.png</boxart>
		<boxback>./images/${APP_NAME}-thumb.png</boxback>
		<wheel>./images/${APP_NAME}-thumb.png</wheel>
		<mix>./images/${APP_NAME}-thumb.png</mix>
		<rating>1</rating>
		<players>1</players>
		<favorite>true</favorite>
		<lang>en</lang>
		<sortname>1 =- ${APP_NAME}</sortname>
		<genreid>0</genreid>
		<screenshot>./images/${APP_NAME}-thumb.png</screenshot>
	</game>"


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

# Create the temporary directories
echo "Creating temporary directories..."
mkdir -p $TEMP_DIR
mkdir -p $EXTRACT_DIR
mkdir -p $PORTS_DIR
clear

# Download the DRL file
echo "Downloading the DRL file..."
curl -L -o $DRL_FILE "https://github.com/DRLEdition19/DRLEdition_Interface/releases/download/files/Antimicrox.DRL"

# Check if download was successful
if [ ! -f "$DRL_FILE" ]; then
    echo "Error: Failed to download DRL file"
    exit 1
fi

# Extract the squashfs file
echo "Extracting the DRL file..."
unsquashfs -f -d "$EXTRACT_DIR" "$DRL_FILE"

# Check if extraction was successful
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract the DRL file"
    rm -rf $TEMP_DIR
    exit 1
fi

# Copia forçada dos arquivos extraídos para o diretório de destino, com sobrescrita
echo "Copying files to the system (forced overwrite)..."
cp -rf "$EXTRACT_DIR"/* "$DEST_DIR"

# Limpeza
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

# Salva alterações
echo "Saving changes..."
batocera-save-overlay
clear

# 2. Directory Creation
echo "Creating necessary directories..."
mkdir -p "$DESKTOP_DIR" || error_exit "Failed to create $DESKTOP_DIR"
mkdir -p "$IMAGES_DIR" || error_exit "Failed to create $IMAGES_DIR"
echo "Directories created."

# 4. Image Download
download_file "$MARQUEE_URL" "$MARQUEE_IMG"
download_file "$THUMB_URL" "$THUMB_IMG"

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

# Step 1: Create the launcher script
echo "Creating ${APP_NAME}.sh..."
cat << 'EOF' > "/userdata/roms/ports/${APP_NAME}.sh"
#!/bin/bash
# Script adapted to work with the antimicrox implemented in "Desktop for Batocera 8.0 by DRL Edition"
export XDG_MENU_PREFIX=batocera-
export XDG_CONFIG_DIRS=/etc/xdg
ANTIMICROX_PROFILE="/userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp"

# fix for exfat on HOME + pcmanfm
export XDG_CACHE_HOME=/tmp/xdg_cache
ANTIMICROX_PROFILE="/userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp"

# Fix xterm via F4 is not previously set up
python << EOF
import configparser
F = '/userdata/system/.config/libfm/libfm.conf'
c = configparser.ConfigParser()
c.read(F)
try:
   t = c['config']['terminal']
except:
   t = None
if (not t or t == ''):
   with open(F, 'w') as wf:
     c['config']['terminal'] = 'xterm'
     c.write(wf)
EOF

### Inicia o AntiMicroX ###
    if [ -e '/dev/input/js0' ]; then
        antimicrox --hidden --profile "$ANTIMICROX_PROFILE" &
        ANTIMICROX_PID=$!
        success "AntiMicroX iniciado (PID: $ANTIMICROX_PID)"
    else
        warning "Nenhum joystick detectado"
    fi

### Inicia o desktop e o pcmanfm ###
batocera-mouse show
DISPLAY=${DISPLAY:-:0.0} pcmanfm /userdata
batocera-mouse hide

### Encerra o AntiMicroX, o desktop e o pcmanfm ###
    if [ -n "${ANTIMICROX_PID}" ]; then
        kill -9 "${ANTIMICROX_PID}" 2>/dev/null
        pkill -9 "${ANTIMICROX_PID}" 2>/dev/null
    fi
    
exit 0
EOF

chmod +x "${APP_NAME}.sh"

# Step 2: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

# Step 3: Final refresh
curl -s http://127.0.0.1:1234/reloadgames

echo "Done! ${APP_NAME} has been added."