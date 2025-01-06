
#!/bin/bash

# Variables to update for different apps
APP_NAME="Fightcade"
REPO_BASE_URL="https://web.fightcade.com/download/"
AMD_SUFFIX="Fightcade-linux-latest.tar.gz"
ARM_SUFFIX=""
ICON_URL=""
# Directories
ADDONS_DIR="/userdata/system/add-ons"
CONFIGS_DIR="/userdata/system/configs"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"
APP_CONFIG_DIR="${CONFIGS_DIR}/${APP_NAME,,}"
PERSISTENT_DESKTOP="${APP_CONFIG_DIR}/${APP_NAME,,}.desktop"
DESKTOP_FILE="${DESKTOP_DIR}/${APP_NAME,,}.desktop"

# Ensure directories exist
echo "Creating necessary directories..."
mkdir -p "$APP_CONFIG_DIR" "$ADDONS_DIR/${APP_NAME,,}"
mkdir -p $ADDONS_DIR/${APP_NAME,,}/extra

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
wget -q --show-progress -O "$ADDONS_DIR/${APP_NAME,,}/${APP_NAME,,}" "$appimage_url"

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
# Create the directory for the lib files
LIB_DIR="$ADDONS_DIR/${APP_NAME,,}/lib"
mkdir -p "$LIB_DIR"

# Download lib.zip into the lib directory
echo "Downloading lib.zip into $LIB_DIR..."
wget -c -q --show-progress -O "$LIB_DIR/lib.zip" "https://archive.org/download/lib_20240806/lib.zip"

if [ $? -ne 0 ]; then
    echo "Failed to download lib.zip."
    exit 1
fi

# Extract the lib.zip file
echo "Extracting lib.zip into $LIB_DIR..."
unzip -q "$LIB_DIR/lib.zip" -d "$LIB_DIR"

if [ $? -ne 0 ]; then
    echo "Failed to extract lib.zip."
    exit 1
fi

# Remove the lib.zip file after extraction
echo "Cleaning up lib.zip..."
rm "$LIB_DIR/lib.zip"

if [ $? -ne 0 ]; then
    echo "Failed to remove lib.zip."
    exit 1
fi

echo "lib.zip downloaded, extracted, and cleaned up successfully in $LIB_DIR."

# Create the directory for the bin files
BIN_DIR="$ADDONS_DIR/${APP_NAME,,}/bin"
mkdir -p "$BIN_DIR"

# Download the wine AppImage and save it as "wine"
echo "Downloading wine AppImage into $BIN_DIR as 'wine'..."
wget -c -q --show-progress -O "$BIN_DIR/wine" "https://github.com/mmtrt/WINE_AppImage/releases/download/continuous-staging_ge_proton/wine-staging_ge-proton_8-26-x86_64.AppImage"

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

# Define the emulator directory
EMULATOR_DIR="$ADDONS_DIR/${APP_NAME,,}/${APP_NAME}/emulator"
cd "$EMULATOR_DIR"

# Download the JSON file archive
echo "Downloading json.zip into $EMULATOR_DIR..."
wget -q --show-progress -O "json.zip" "https://archive.org/download/Fightcade_Json/json.zip"

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

# Move JSON files to the emulator directory
echo "Moving JSON files to $EMULATOR_DIR..."
mv ./json/* . 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Failed to move JSON files."
    exit 1
fi
sleep 2

# Remove the extracted json directory and the zip file
echo "Cleaning up extracted files..."
rm -r "./json" 2>/dev/null
rm "json.zip" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "Failed to clean up files."
    exit 1
fi

echo "JSON files downloaded, extracted, moved, and cleaned up successfully in $EMULATOR_DIR."

# Step 3: Create persistent desktop entry
echo "Creating persistent desktop entry for $APP_NAME..."
cat <<EOF > "$PERSISTENT_DESKTOP"
#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=/userdata/system/add-ons/fightcade/Fightcade/Fightcade2.sh
Name=Fightcade
Comment=Fightcade
Categories=Game;Emulator;ArcadeGame
Icon=/userdata/system/add-ons/fightcade/Fightcade/fc2-electron/resources/app/icon.png
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored to /usr/share/applications
echo "Ensuring $APP_NAME desktop entry is restored at startup..."
cat <<EOF > "${APP_CONFIG_DIR}/restore_desktop_entry.sh"
#!/bin/bash
# Restore $APP_NAME desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring $APP_NAME desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "$APP_NAME desktop entry restored."
else
    echo "$APP_NAME desktop entry already exists."
fi
EOF
chmod +x "${APP_CONFIG_DIR}/restore_desktop_entry.sh"

# Add to startup
echo "Adding desktop entry restore script to startup..."
cat <<EOF > "$CUSTOM_SCRIPT"
#!/bin/bash
# Restore $APP_NAME desktop entry at startup
bash "${APP_CONFIG_DIR}/restore_desktop_entry.sh" &
EOF
chmod +x "$CUSTOM_SCRIPT"

echo "$APP_NAME desktop entry creation complete."
