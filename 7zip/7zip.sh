#!/usr/bin/env bash

# 7zip Installer for Batocera

# App Info
APPNAME="7zip"
APPLINK="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/7zip/extra/7zip.zip"
APPHOME="7-zip.org v22.01"
ICON="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/7zip/extra/7zip-icon.png"
COMMAND='batocera-wine lutris play /userdata/system/add-ons/7zip/7zip/7zFM.exe 2>/dev/null'

# Define paths
add_ons="/userdata/system/add-ons"
appdir="$add_ons/7zip"
extradir="$appdir/extra"

# Prepare directories
mkdir -p "$extradir"

# Download and install the app
cd "$extradir"
echo "Downloading $APPNAME..."
curl --progress-bar -O "$APPLINK"
unzip -oq 7zip.zip -d "$appdir"
curl --progress-bar -L -o "icon.png" "$ICON"

# Create Desktop Shortcut
shortcut="$extradir/7zip.desktop"
echo "[Desktop Entry]" > "$shortcut"
echo "Version=1.0" >> "$shortcut"
echo "Icon=$extradir/icon.png" >> "$shortcut"
echo "Exec=$COMMAND" >> "$shortcut"
echo "Terminal=false" >> "$shortcut"
echo "Type=Application" >> "$shortcut"
echo "Categories=Game;batocera.linux;" >> "$shortcut"
echo "Name=7zip" >> "$shortcut"
chmod +x "$shortcut"
cp "$shortcut" /usr/share/applications/

# Create persistent desktop script
persistent_script="$extradir/startup.sh"
echo "#!/bin/bash" > "$persistent_script"
echo "if [ ! -f /usr/share/applications/$(basename "$shortcut") ]; then" >> "$persistent_script"
echo "    cp $shortcut /usr/share/applications/" >> "$persistent_script"
echo "fi" >> "$persistent_script"
chmod +x "$persistent_script"

# Add persistent script to custom.sh
csh="/userdata/system/custom.sh"
if ! grep -q "$persistent_script" "$csh"; then
    echo "$persistent_script &" >> "$csh"
fi

# Finish
echo "$APPNAME installed successfully."
