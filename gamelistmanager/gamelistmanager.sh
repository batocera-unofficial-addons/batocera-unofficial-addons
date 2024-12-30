#!/usr/bin/env bash
######################################################################
# BATOCERA.ADD-ONS/GAMELIST MANAGER INSTALLER
######################################################################

APPNAME="gamelist-manager"
APPDIR="/userdata/system/add-ons/$APPNAME"
APPLINK=$(curl -s https://api.github.com/repos/RobG66/Gamelist-Manager/releases \
          | grep "browser_download_url" \
          | sed 's,^.*https://,https://,g' \
          | cut -d \" -f1 \
          | grep ".zip" \
          | head -n1)
ORIGIN="github.com/RobG66/Gamelist-Manager"

# Color codes for console output
RESET='\033[0m'
GREEN='\033[32m'
RED='\033[31m'
BLUE='\033[34m'

# Helper function for printing colored messages
echo_colored() {
    local color=$1
    shift
    echo -e "${color}$@${RESET}"
}

# Start of the installation script
clear
echo_colored $BLUE "Preparing GAMELIST-MANAGER Installer..."

# Ensure required tools are installed
for cmd in curl unzip dos2unix; do
    command -v $cmd >/dev/null 2>&1 || {
        echo_colored $RED "Error: $cmd is not installed."
        exit 1
    }
done

# Validate the APPLINK URL
if [[ -z "$APPLINK" ]]; then
    echo_colored $RED "Error: Could not determine the download URL."
    exit 1
fi

# Prepare installation directories
mkdir -p "$APPDIR/extra"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Download the application archive
echo_colored $BLUE "Downloading from: $APPLINK"
if ! curl --progress-bar --location "$APPLINK" -o "$TEMP_DIR/app.zip"; then
    echo_colored $RED "Error: Failed to download the application archive."
    exit 1
fi

# Extract the application archive
echo_colored $BLUE "Extracting application archive..."
if ! unzip -oq "$TEMP_DIR/app.zip" -d "$TEMP_DIR"; then
    echo_colored $RED "Error: Failed to extract the application archive."
    exit 1
fi

# Move extracted files to application directory
if [[ ! -d "$TEMP_DIR/Release" ]]; then
    echo_colored $RED "Error: Release directory not found in the archive."
    exit 1
fi
cp -r "$TEMP_DIR/Release" "$APPDIR/"

# Create launcher script
LAUNCHER="$APPDIR/Launcher"
cat <<EOF > "$LAUNCHER"
#!/bin/bash
export DISPLAY=:0.0
unclutter-remote -s
DISPLAY=:0.0 QT_SCALE_FACTOR="1.25" GDK_SCALE="1.25" batocera-wine windows play "$APPDIR/Release/GamelistManager.exe"
EOF
chmod +x "$LAUNCHER"

# Create desktop shortcut
DESKTOP_FILE="$APPDIR/extra/$APPNAME.desktop"
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Icon=$APPDIR/extra/icon.png
Exec=$LAUNCHER
Terminal=false
Type=Application
Categories=Game;batocera.linux;
Name=$APPNAME
EOF
dos2unix "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"
cp "$DESKTOP_FILE" /usr/share/applications/

# Prepare startup script
STARTUP_SCRIPT="$APPDIR/extra/startup"
cat <<EOF > "$STARTUP_SCRIPT"
#!/bin/bash
cp "$DESKTOP_FILE" /usr/share/applications/
EOF
dos2unix "$STARTUP_SCRIPT"
chmod +x "$STARTUP_SCRIPT"

# Add startup script to custom.sh
CUSTOM_SH="/userdata/system/custom.sh"
if [[ -e "$CUSTOM_SH" ]]; then
    grep -q "$STARTUP_SCRIPT" "$CUSTOM_SH" || echo "$STARTUP_SCRIPT" >> "$CUSTOM_SH"
else
    echo "$STARTUP_SCRIPT" > "$CUSTOM_SH"
fi
dos2unix "$CUSTOM_SH"
chmod +x "$CUSTOM_SH"

# Final output
clear
echo_colored $GREEN "$APPNAME has been successfully installed!"
echo_colored $GREEN "It is available under F1 -> Applications."
echo_colored $BLUE "Installation directory: $APPDIR"
exit 0
