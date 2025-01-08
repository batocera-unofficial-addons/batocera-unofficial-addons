#!/usr/bin/env bash

# qBittorrent Installer for Batocera

# App Info
APPNAME="qBittorrent"
APPLINK="https://github.com/ivan-hc/qbittorrent-appimage/releases/download/continuous/qBittorrent_5.0.0-1-archimage3.4.4-2-x86_64.AppImage"
APPHOME="ivan-hc/qbittorrent-appimage"
APPPATH="/userdata/system/add-ons/qbittorrent/qbittorrent.AppImage"
ICON="https://e7.pngegg.com/pngimages/380/378/png-clipart-qbittorrent-comparison-of-bittorrent-clients-others-blue-trademark.png"
COMMAND="/userdata/system/add-ons/qbittorrent/qbittorrent.AppImage"

# Define paths
add_ons="/userdata/system/add-ons"
appdir="$add_ons/qbittorrent"
extradir="$appdir/extra"

# Prepare directories
mkdir -p "$extradir"

# Download and install the app
cd "$extradir"
echo "Downloading $APPNAME..."
curl --progress-bar -L -O "$APPLINK"
chmod +x qBittorrent_5.0.0-1-archimage3.4.4-2-x86_64.AppImage
mv qBittorrent_5.0.0-1-archimage3.4.4-2-x86_64.AppImage "$APPPATH"
curl --progress-bar -L -o "icon.png" "$ICON"

# Create Desktop Shortcut
shortcut="$extradir/qbittorrent.desktop"
echo "[Desktop Entry]" > "$shortcut"
echo "Version=1.0" >> "$shortcut"
echo "Icon=$extradir/icon.png" >> "$shortcut"
echo "Exec=$COMMAND" >> "$shortcut"
echo "Terminal=false" >> "$shortcut"
echo "Type=Application" >> "$shortcut"
echo "Categories=Network;batocera.linux;" >> "$shortcut"
echo "Name=qBittorrent" >> "$shortcut"
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
