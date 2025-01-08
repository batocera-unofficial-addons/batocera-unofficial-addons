#!/bin/bash

# 7zip Installer for Batocera

# App Info
APPNAME="7zip"
APPLINK="https://www.7-zip.org/a/7z2409-x64.exe"
APPHOME="7-zip.org v24.09"
ICON="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/7zip/extra/7zip-icon.png"
# Launcher Command
COMMAND='batocera-wine lutris play /userdata/system/add-ons/7zip/7z2409-x64.exe 2>/dev/null'

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
curl --progress-bar -O "$ICON"

# Create Launcher Script
launcher="$appdir/Launcher"
echo "#!/bin/bash" > "$launcher"
echo "batocera-wine lutris play $appdir/7z2409-x64.exe" >> "$launcher"
chmod +x "$launcher"

# Create Desktop Shortcut
shortcut="$extradir/7zip.desktop"
echo "[Desktop Entry]" > "$shortcut"
echo "Version=1.0" >> "$shortcut"
echo "Icon=$extradir/7zip-icon.png" >> "$shortcut"
echo "Exec=$launcher" >> "$shortcut"
echo "Terminal=false" >> "$shortcut"
echo "Type=Application" >> "$shortcut"
echo "Categories=Game;batocera.linux;" >> "$shortcut"
echo "Name=7zip" >> "$shortcut"
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

