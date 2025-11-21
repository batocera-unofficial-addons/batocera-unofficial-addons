#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages/"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Check if fusermount3 exists
if ! command -v fusermount3 &> /dev/null; then

    # Display a YES/NO dialog
    dialog --stdout --yesno "BUA needs to be updated to the latest version for this app to run. Do you want to continue?" 10 60
    response=$?
    if [ $response -eq 0 ]; then
    clear
        echo "Updating BUA..."
        curl -L bit.ly/BUAinstaller | bash
    else
        echo "Update declined. Exiting."
        exit 1
    fi
fi

# Step 2: Download Steam Parts
echo "Downloading Steam parts..."
mkdir -p /userdata/system/add-ons/steam
wget -q -c --show-progress -O /userdata/system/add-ons/steam/steam_part_aa "$appimage_url/steam_part_aa"
wget -q -c --show-progress -O /userdata/system/add-ons/steam/steam_part_ab "$appimage_url/steam_part_ab"

if [ $? -ne 0 ]; then
    echo "Failed to download Steam parts."
    exit 1
fi

# Reassemble and extract Steam package
echo "Reassemble and extracting Steam..."
cat /userdata/system/add-ons/steam/steam_part_* | tar -xvJf - -i -C /userdata/system/add-ons/steam

if [ ! -f "/userdata/system/add-ons/steam/steam" ]; then
    echo "Failed to reassemble and extract Steam."
    exit 1
fi

chmod a+x /userdata/system/add-ons/steam/steam
echo "Steam reassembled, extracted, and marked as executable."

# Remove the tar part files after extraction
rm /userdata/system/add-ons/steam/steam_part_*

# Create persistent configuration and log directories
mkdir -p /userdata/system/logs
mkdir -p /userdata/system/configs/steam
mkdir -p /userdata/system/add-ons/steam/extra
DESKTOP_FILE="/usr/share/applications/Steam.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/steam/Steam.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/steam/extra/icon.png"
INSTALL_DIR="/userdata/system/add-ons/steam"

echo "Downloading Steam helper scripts..."
SCRIPTS_BASE_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/steam/extra"
wget --show-progress -qO "/userdata/system/add-ons/steam/Launcher" "${SCRIPTS_BASE_URL}/Launcher"
wget --show-progress -qO "/userdata/system/add-ons/steam/create-steam-launchers.sh" "${SCRIPTS_BASE_URL}/create-steam-launchers.sh"

chmod +x /userdata/system/add-ons/steam/Launcher
chmod +x /userdata/system/add-ons/steam/create-steam-launchers.sh

echo "Downloading EmulationStation config..."
mkdir -p /userdata/system/configs/emulationstation
wget --show-progress -qO "/userdata/system/configs/emulationstation/es_systems_steam.cfg" "${SCRIPTS_BASE_URL}/es_systems_steam.cfg"
wget --show-progress -qO "/userdata/system/configs/emulationstation/es_features_steam.cfg" "${SCRIPTS_BASE_URL}/es_features_steam.cfg"

echo "Downloading icon..."
wget --show-progress -qO "${INSTALL_DIR}/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for Steam..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Steam
Exec=/userdata/system/add-ons/steam/Launcher
Icon=/userdata/system/add-ons/steam/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored at startup
echo "Ensuring Steam desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/steam/restore_desktop_entry.sh"
#!/bin/bash
# Restore Steam desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring Steam desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "Steam desktop entry restored."
else
    echo "Steam desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/steam/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/steam/restore_desktop_entry.sh" "$custom_startup"; then
    echo "Adding Steam restore script to startup..."
    echo "bash \"/userdata/system/configs/steam/restore_desktop_entry.sh\" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Create Big Picture Mode launcher in /userdata/roms/steam
echo "Creating Big Picture Mode launcher..."
mkdir -p /userdata/roms/steam
mkdir -p /userdata/roms/steam/images

cat <<'EOF' > /userdata/roms/steam/Steam_Big_Picture.sh
#!/bin/bash
/userdata/system/add-ons/steam/Launcher "-gamepadui"
EOF
chmod +x /userdata/roms/steam/Steam_Big_Picture.sh

KEYS_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/steam/extra/Steam.sh.keys"
# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "/userdata/roms/steam/Steam_Big_Picture.sh.keys" "$KEYS_URL"
# Download the image
echo "Downloading Steam logo..."
curl -L -o /userdata/roms/steam/images/steamlogo.jpg https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/steam/extra/logo.jpg

echo "Adding logo to Steam entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Steam_Big_Picture.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Steam" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/steamlogo.jpg" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/steam/gamelist.xml.tmp && mv /userdata/roms/steam/gamelist.xml.tmp /userdata/roms/steam/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Steam from the F1 Applications menu and Steam Big Picture Mode from the Ports menu."
# Finish
killall -9 emulationstation