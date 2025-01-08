#!/bin/bash

# 7zip Installer for Batocera

# App Info
APPNAME="7zip"
APPLINK="https://www.7-zip.org/a/7z2409-x64.exe"
APPHOME="7-zip.org v24.09"

# Launcher Command
COMMAND='batocera-wine lutris play /userdata/system/add-ons/7zip/7zFM.exe 2>/dev/null'

# Define paths
add_ons="/userdata/system/add-ons"
appdir="$add_ons/7zip"
extradir="$appdir/extra"

# Prepare directories
mkdir -p "$extradir"

# Save launcher command
command_file="$extradir/command"
echo "$COMMAND" > "$command_file"

# Download and install the app
cd "$extradir"
echo "Downloading $APPNAME..."
curl --progress-bar -O "$APPLINK"

# Create Launcher Script
launcher="$appdir/Launcher"
echo "#!/bin/bash" > "$launcher"
echo "batocera-wine lutris play $appdir/7zFM.exe" >> "$launcher"
chmod +x "$launcher"

# Create Desktop Shortcut
shortcut="$extradir/7zip.desktop"
echo "[Desktop Entry]" > "$shortcut"
echo "Version=1.0" >> "$shortcut"
echo "Icon=$extradir/icon.png" >> "$shortcut"
echo "Exec=$launcher" >> "$shortcut"
echo "Terminal=false" >> "$shortcut"
echo "Type=Application" >> "$shortcut"
echo "Categories=Game;batocera.linux;" >> "$shortcut"
echo "Name=7zip" >> "$shortcut"
cp "$shortcut" /usr/share/applications/

# Add to custom.sh for autostart
csh="/userdata/system/custom.sh"
if ! grep -q "$launcher" "$csh"; then
    echo "$launcher &" >> "$csh"
fi

# Finish
echo "$APPNAME installed successfully."
