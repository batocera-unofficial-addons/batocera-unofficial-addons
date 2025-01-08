#!/usr/bin/env bash

# Viber Installer for Batocera

# App Info
APPNAME="Viber"
APPLINK="https://download.cdn.viber.com/desktop/Linux/viber.AppImage"
APPPATH="/userdata/system/add-ons/viber/viber.AppImage"
ICON="https://e7.pngegg.com/pngimages/216/38/png-clipart-viber-android-google-play-viber-purple-text-thumbnail.png"
COMMAND='su - batocera -c DISPLAY=:0.0 HOME=/userdata/system/add-ons/viber/home XDG_CONFIG_HOME=/userdata/system/add-ons/viber/config QT_SCALE_FACTOR=1.25 GDK_SCALE=1.25 /userdata/system/add-ons/viber/viber.AppImage --no-sandbox --disable-gpu "$@""'

# Define paths
add_ons="/userdata/system/add-ons"
appdir="$add_ons/viber"
extradir="$appdir/extra"

# Prepare directories
mkdir -p "$extradir"

# Download and install the app
cd "$extradir"
echo "Downloading $APPNAME..."
curl --progress-bar -L -o "$APPPATH" "$APPLINK"
chmod +x "$APPPATH"
curl --progress-bar -L -o "icon.png" "$ICON"

# Create Desktop Shortcut
shortcut="$extradir/viber.desktop"
echo "[Desktop Entry]" > "$shortcut"
echo "Version=1.0" >> "$shortcut"
echo "Icon=$extradir/icon.png" >> "$shortcut"
echo "Exec=$COMMAND" >> "$shortcut"
echo "Terminal=false" >> "$shortcut"
echo "Type=Application" >> "$shortcut"
echo "Categories=Utility;Communication;" >> "$shortcut"
echo "Name=Viber" >> "$shortcut"
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

