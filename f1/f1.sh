#!/bin/bash

# Set variables
APP_NAME="F1"
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/blob/main/f1/extra/f1key.jpg?raw=true"   # Replace with actual logo URL
LOGO_PATH="/userdata/roms/ports/images/${APP_NAME}-logo.jpg"
GAME_LIST="/userdata/roms/ports/gamelist.xml"

# Temporary directory for download
TEMP_DIR="/userdata/tmp/Antimicrox"
DRL_FILE="$TEMP_DIR/Antimicrox.DRL"
EXTRACT_DIR="$TEMP_DIR/extracted"
DEST_DIR="/"
PORTS_DIR="/userdata/roms/ports"

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

# Salva alterações
echo "Saving changes..."
batocera-save-overlay
clear

# Step 2: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl -s http://127.0.0.1:1234/reloadgames

# Step 3: Download the logo
echo "Downloading logo..."
curl -s -L -o "$LOGO_PATH" "$LOGO_URL"

# Step 4: Add entry to gamelist.xml
echo "Adding $APP_NAME to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME}-logo.jpg" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

# Step 5: Final refresh
curl -s http://127.0.0.1:1234/reloadgames

echo "Done! ${APP_NAME} has been added."
