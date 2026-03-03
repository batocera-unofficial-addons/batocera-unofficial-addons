#!/bin/bash

# Variables to update for different apps
APP_NAME="Fightcade"
REPO_BASE_URL="https://web.fightcade.com/download/"
AMD_SUFFIX="Fightcade-linux-latest.tar.gz"
ARM_SUFFIX=""
LOGO_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/fightcade/extra/fightcade-logo.png"
SYM_WINE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/fightcade/sym_wine.sh"
# Directories
ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${PORTS_DIR}/images/${APP_NAME,,}-logo.png"
SYM_WINE_SCRIPT="${ADDONS_DIR}/${APP_NAME,,}/extra/sym_wine.sh"

# Remove existing directory for a clean install
if [ -d "$ADDONS_DIR/${APP_NAME,,}" ]; then
  echo "Directory $ADDONS_DIR/${APP_NAME,,} exists. Removing it..."
  rm -rf "$ADDONS_DIR/${APP_NAME,,}"
  echo "Directory $ADDONS_DIR/${APP_NAME,,} has been removed."
else
  echo "Directory $ADDONS_DIR/${APP_NAME,,} does not exist. Continuing..."
fi

# Ensure directories exist
echo "Creating necessary directories..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}/extra"

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="${REPO_BASE_URL}${AMD_SUFFIX}"
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    if [ -n "$ARM_SUFFIX" ]; then
        appimage_url="${REPO_BASE_URL}${ARM_SUFFIX}"
    else
        echo "No ARM64 AppImage suffix provided. Skipping download. Exiting."
        exit 1
    fi
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

if [ -z "$appimage_url" ]; then
    echo "No suitable AppImage found for architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download
echo "Downloading $APP_NAME from $appimage_url..."
mkdir -p "$ADDONS_DIR/${APP_NAME,,}"
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/Fightcade-linux-latest.tar.gz" "$appimage_url"

# Extract the downloaded tar.gz file
echo "Extracting $APP_NAME tar.gz file..."
tar -xzf "$ADDONS_DIR/${APP_NAME,,}/Fightcade-linux-latest.tar.gz" -C "$ADDONS_DIR/${APP_NAME,,}/"

if [ $? -ne 0 ]; then
    echo "Failed to extract $APP_NAME tar.gz file."
    exit 1
fi

# Remove the tar.gz file after successful extraction
echo "Cleaning up the tar.gz file..."
rm "$ADDONS_DIR/${APP_NAME,,}/Fightcade-linux-latest.tar.gz"

if [ $? -ne 0 ]; then
    echo "Failed to remove $APP_NAME tar.gz file."
    exit 1
fi

echo "$APP_NAME tar.gz file extracted and removed successfully."

if [ $? -ne 0 ]; then
    echo "Failed to download $APP_NAME."
    exit 1
fi

# Create the directory for the bin files
BIN_DIR="$ADDONS_DIR/${APP_NAME,,}/usr/bin"
mkdir -p "$BIN_DIR"

# Download the wine AppImage and save it as "wine"
echo "Downloading wine AppImage into $BIN_DIR as 'wine'..."
wget -c -q --show-progress -O "$BIN_DIR/wine" "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/wine-staging_ge-proton_8-26-x86_64.AppImage"

if [ $? -ne 0 ]; then
    echo "Failed to download the wine AppImage."
    exit 1
fi

# Make the downloaded file executable
echo "Making the wine AppImage executable..."
chmod +x "$BIN_DIR/wine"

if [ $? -ne 0 ]; then
    echo "Failed to make the wine AppImage executable."
    exit 1
fi

echo "wine AppImage downloaded and saved as 'wine' in $BIN_DIR."

echo "Downloading sym_wine.sh..."
wget -q --show-progress -O "$SYM_WINE_SCRIPT" "$SYM_WINE_URL"

if [ $? -ne 0 ]; then
    echo "Failed to download sym_wine.sh."
    exit 1
fi

# Make sym_wine.sh executable
chmod +x "$SYM_WINE_SCRIPT"

# Create wine.sh wrapper — the fcade binary invokes this at ../../Resources/wine.sh
# relative to the emulator directory
RESOURCES_DIR="$ADDONS_DIR/${APP_NAME,,}/Resources"
mkdir -p "$RESOURCES_DIR"
cat > "$RESOURCES_DIR/wine.sh" << WINESH
#!/bin/sh
export WINEPREFIX="$ADDONS_DIR/${APP_NAME,,}/.wine"
export WINEDEBUG=-all
$ADDONS_DIR/${APP_NAME,,}/usr/bin/wine "\$@"
WINESH
chmod +x "$RESOURCES_DIR/wine.sh"
echo "Created wine.sh wrapper in $RESOURCES_DIR."

# Define the emulator directory
EMULATOR_DIR="$ADDONS_DIR/${APP_NAME,,}/${APP_NAME}/emulator"
cd "$EMULATOR_DIR"

# Download the JSON file archive
echo "Downloading json.zip into $EMULATOR_DIR..."
wget -q --show-progress -O "json.zip" "https://fightcade.download/fc2json.zip"

if [ $? -ne 0 ]; then
    echo "Failed to download json.zip."
    exit 1
fi

# Extract the json.zip file
echo "Extracting json.zip..."
unzip -q "json.zip"

if [ $? -ne 0 ]; then
    echo "Failed to extract json.zip."
    exit 1
fi

if [ -d "./json" ]; then
    mv ./json/* . 2>/dev/null
else
    mv ./* . 2>/dev/null
fi


# Remove the extracted json directory and the zip file
echo "Cleaning up extracted files..."
[ -d "./json" ] && rm -r "./json"
rm "json.zip" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Failed to clean up files."
    exit 1
fi

echo "JSON files downloaded, extracted, moved, and cleaned up successfully in $EMULATOR_DIR."

# Step 3: Create the app launch script
echo "Creating $APP_NAME script in Ports..."
mkdir -p "$PORTS_DIR"
cat << EOF > "$PORT_SCRIPT"
#!/bin/bash

# Environment setup
export \$(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export LD_LIBRARY_PATH="$ADDONS_DIR/.dep:\${LD_LIBRARY_PATH}"
export HOME=$ADDONS_DIR/${APP_NAME,,}

# Directories and file paths
app_dir="$ADDONS_DIR/${APP_NAME,,}/${APP_NAME}"
log_dir="$LOGS_DIR"
log_file="\${log_dir}/${APP_NAME,,}.log"

# Ensure log directory exists
mkdir -p "\${log_dir}"

# Append all output to the log file
exec &> >(tee -a "\$log_file")
echo "\$(date): Launching $APP_NAME"

# Batocera lacks xdg-open/xdg-mime — fc2-electron needs xdg-open to dispatch
# fcade:// URLs for game launch. Create a shim that routes to upstream fcade.sh.
mkdir -p "\${HOME}/bin"
cat > "\${HOME}/bin/xdg-open" << 'XDGOPEN'
#!/bin/bash
case "\$1" in
    fcade://*)
        $ADDONS_DIR/${APP_NAME,,}/${APP_NAME}/emulator/fcade.sh "\$1"
        ;;
    *)
        echo "xdg-open: no handler for: \$1" >&2
        ;;
esac
XDGOPEN
chmod +x "\${HOME}/bin/xdg-open"
export PATH="\${HOME}/bin:\${PATH}"

# Initialize Wine prefix before starting sym_wine.sh — wineboot blocks and
# would otherwise prevent fc2-electron from starting before sym_wine.sh's
# 10-second monitoring check.
export WINEPREFIX="\${HOME}/.wine"
export WINEDEBUG=-all
if [ ! -d "\${WINEPREFIX}" ]; then
    echo "Initializing Wine prefix at \${WINEPREFIX}..."
    $ADDONS_DIR/${APP_NAME,,}/usr/bin/wine wineboot -u 2>/dev/null
    echo "Wine prefix initialized."
fi

# Start wine symlink manager (creates /usr/bin/wine, monitors fc2-electron)
$ADDONS_DIR/${APP_NAME,,}/extra/sym_wine.sh &

if [ -x "\${app_dir}/${APP_NAME}2.sh" ]; then
    cd "\${app_dir}"
    ./${APP_NAME}2.sh
    echo "$APP_NAME launched."
else
    echo "$APP_NAME not found or not executable."
    exit 1
fi
EOF

chmod +x "$PORT_SCRIPT"

# Step 4: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Download the logo
echo "Downloading $APP_NAME logo..."
curl -L -o "$LOGO_PATH" "$LOGO_URL"
echo "Adding logo to $APP_NAME entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch $APP_NAME from the Ports menu."
