#!/bin/bash

# Set variables
HEROIC_VERSION="2.15.2"
HEROIC_URL="https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases/download/v${HEROIC_VERSION}/Heroic-${HEROIC_VERSION}.tar.xz"
INSTALL_DIR="/userdata/system/add-ons/heroic"
DESKTOP_FILE="/usr/share/applications/heroic.desktop"

# Download Heroic
echo "Downloading Heroic Games Launcher..."
mkdir -p "$INSTALL_DIR"
wget -qO- "$HEROIC_URL" | tar -xJ -C "$INSTALL_DIR" --strip-components=1

# Create desktop file
echo "Creating desktop entry for Heroic..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Heroic Games Launcher
Exec=bash -c "/userdata/system/add-ons/heroic/monitor_heroic.sh &; HOME=/userdata/system/add-ons/heroic /userdata/system/add-ons/heroic/heroic --no-sandbox"
Icon=/userdata/system/add-ons/heroic/resources/app.asar.unpacked/assets/icon.png
Categories=Game;
EOF

# Make Heroic executable
chmod +x "${INSTALL_DIR}/heroic"

echo "Heroic Games Launcher setup complete! A desktop entry has been created at $DESKTOP_FILE."
