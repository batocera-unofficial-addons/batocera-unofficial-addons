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

# Step 2: Download Lutris
echo "Downloading Lutris..."

mkdir -p /userdata/system/add-ons/lutris

lutris_file="/userdata/system/add-ons/lutris/lutris"

# Always replace — ensures new version is downloaded cleanly
rm -f "$lutris_file"
wget -q --show-progress -O "$lutris_file" "$appimage_url/lutris.AppImage"

if [ $? -ne 0 ]; then
    echo "Failed to download Lutris."
    exit 1
fi

chmod a+x /userdata/system/add-ons/lutris/lutris
echo "Lutris marked as executable."

# Create directories
mkdir -p /userdata/system/logs
mkdir -p /userdata/system/configs/lutris
mkdir -p /userdata/system/add-ons/lutris/extra
DESKTOP_FILE="/usr/share/applications/Lutris.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/lutris/Lutris.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/lutris/extra/icon.png"
INSTALL_DIR="/userdata/system/add-ons/lutris"

echo "Downloading Lutris helper scripts..."
SCRIPTS_BASE_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/lutris/extra"
wget --show-progress -qO "/userdata/system/add-ons/lutris/Launcher" "${SCRIPTS_BASE_URL}/Launcher"
wget --show-progress -qO "/userdata/system/add-ons/lutris/create-lutris-launchers.sh" "${SCRIPTS_BASE_URL}/create-lutris-launchers.sh"

chmod +x /userdata/system/add-ons/lutris/Launcher
chmod +x /userdata/system/add-ons/lutris/create-lutris-launchers.sh

# Use sh emulator so .sh launchers run through configgen (enables videomode, etc.)
BATOCERA_CONF="/userdata/system/batocera.conf"
sed -i '/^lutris\.emulator=/d; /^lutris\.core=/d' "$BATOCERA_CONF" 2>/dev/null || true
echo "lutris.emulator=sh" >> "$BATOCERA_CONF"
echo "lutris.core=sh" >> "$BATOCERA_CONF"

echo "Downloading EmulationStation config..."
mkdir -p /userdata/system/configs/emulationstation
wget --show-progress -qO "/userdata/system/configs/emulationstation/es_systems_lutris.cfg" "${SCRIPTS_BASE_URL}/es_systems_lutris.cfg"
wget --show-progress -qO "/userdata/system/configs/emulationstation/es_features_lutris.cfg" "${SCRIPTS_BASE_URL}/es_features_lutris.cfg"

echo "Downloading icon..."
wget --show-progress -qO "${INSTALL_DIR}/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for Lutris..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Lutris
Exec=/userdata/system/add-ons/lutris/Launcher
Icon=/userdata/system/add-ons/lutris/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored at startup
echo "Ensuring Lutris desktop entry is restored at startup..."
cat <<EOF > "/userdata/system/configs/lutris/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF
chmod +x "/userdata/system/configs/lutris/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "configs/lutris/restore_desktop_entry" "$custom_startup" 2>/dev/null; then
    echo "Adding Lutris restore script to startup..."
    echo "bash \"/userdata/system/configs/lutris/restore_desktop_entry.sh\" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Create launchers in the Lutris system
echo "Creating Lutris system launchers..."
mkdir -p /userdata/roms/lutris/images

# LutrisView (big picture mode)
cat <<'EOF' > "/userdata/roms/lutris/LutrisView.sh"
#!/bin/bash
/userdata/system/add-ons/lutris/Launcher "-lutrisview"
EOF
chmod +x "/userdata/roms/lutris/LutrisView.sh"

echo "Downloading Lutris logo..."
curl -L -o /userdata/roms/lutris/images/lutrislogo.jpg \
    https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/lutris/extra/logo.jpg

echo "Adding LutrisView to gamelist.xml..."
if [[ ! -f /userdata/roms/lutris/gamelist.xml ]]; then
    echo '<?xml version="1.0" encoding="UTF-8"?>' > /userdata/roms/lutris/gamelist.xml
    echo '<gameList>' >> /userdata/roms/lutris/gamelist.xml
    echo '</gameList>' >> /userdata/roms/lutris/gamelist.xml
fi
xmlstarlet ed \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./LutrisView.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "LutrisView" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/lutrislogo.jpg" \
  /userdata/roms/lutris/gamelist.xml > /userdata/roms/lutris/gamelist.xml.tmp \
  && mv /userdata/roms/lutris/gamelist.xml.tmp /userdata/roms/lutris/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

dialog --title "Lutris Installed" --msgbox \
"Lutris has been installed!\n\nLaunch Lutris from the F1 Applications menu or the Lutris system.\nUse LutrisView for a controller-friendly big picture interface.\n\n--- Multi-GPU & Nvidia Vulkan ---\nLutris auto-detects the dedicated GPU and applies Nvidia Vulkan fixes on each launch." \
14 60

# Finish
killall -9 emulationstation
