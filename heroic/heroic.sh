#!/bin/bash

# Set variables
INSTALL_DIR="/userdata/system/add-ons/heroic"
DESKTOP_FILE="/usr/share/applications/heroic.desktop"
COLLECTIONS_DIR="/userdata/system/configs/emulationstation/collections"
HEROIC_CFG="${COLLECTIONS_DIR}/Heroic.cfg"
LAUNCHERS_SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/heroic/create_game_launchers.sh"
MONITOR_SCRIPT_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/heroic/monitor_heroic.sh"

# Fetch the latest version of Heroic from GitHub API
echo "Fetching the latest version of Heroic Games Launcher..."
HEROIC_URL=$(wget -qO- https://api.github.com/repos/Heroic-Games-Launcher/HeroicGamesLauncher/releases/latest | grep "browser_download_url" | grep "tar.xz" | cut -d '"' -f 4)
HEROIC_VERSION=$(basename "$HEROIC_URL" | sed -E 's/Heroic-([^-]+).*/\1/')

if [ -z "$HEROIC_URL" ]; then
    echo "Failed to fetch the latest Heroic version. Please check your internet connection or the GitHub API."
    exit 1
fi

# Download Heroic
echo "Downloading Heroic Games Launcher version $HEROIC_VERSION..."
mkdir -p "$INSTALL_DIR"
wget --show-progress -qO- "$HEROIC_URL" | tar -xJ -C "$INSTALL_DIR" --strip-components=1

# Download supporting scripts
echo "Downloading create_game_launchers.sh..."
wget --show-progress -qO "${INSTALL_DIR}/create_game_launchers.sh" "$LAUNCHERS_SCRIPT_URL"

echo "Downloading monitor_heroic.sh..."
wget --show-progress -qO "${INSTALL_DIR}/monitor_heroic.sh" "$MONITOR_SCRIPT_URL"

# Make scripts executable
chmod +x "${INSTALL_DIR}/heroic"
chmod +x "${INSTALL_DIR}/create_game_launchers.sh"
chmod +x "${INSTALL_DIR}/monitor_heroic.sh"

# Create desktop entry
echo "Creating desktop entry for Heroic..."
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Type=Application
Name=Heroic Games Launcher
Exec=bash -c "/userdata/system/add-ons/heroic/monitor_heroic.sh &; HOME=/userdata/system/add-ons/heroic /userdata/system/add-ons/heroic/heroic --no-sandbox"
Icon=/userdata/system/add-ons/heroic/resources/app.asar.unpacked/assets/icon.png
Categories=Game;
EOF

chmod +x "$DESKTOP_FILE"

# Create Heroic.cfg
echo "Creating Heroic.cfg for EmulationStation..."
mkdir -p "$COLLECTIONS_DIR"
cat <<EOF > "$HEROIC_CFG"
# Heroic Games Collection
PATH=/userdata/roms/heroic
EXTENSION=.sh
NAME=Heroic Games
EOF

echo "Heroic.cfg created at $HEROIC_CFG."

# Final message
echo "Heroic Games Launcher setup complete! Installed version $HEROIC_VERSION."
echo "A desktop entry has been created at $DESKTOP_FILE."
echo "Heroic.cfg has been created for EmulationStation integration."
