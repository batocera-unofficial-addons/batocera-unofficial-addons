#!/bin/bash

APP_NAME="YARG"
INSTALL_DIR="/userdata/system/add-ons/yarg"
LOGS_DIR="/userdata/system/logs"
PORTS_DIR="/userdata/roms/ports"
GAME_LIST="/userdata/roms/ports/gamelist.xml"
LOGO_PATH="${PORTS_DIR}/images/yarg-logo.png"
PORT_SCRIPT="${PORTS_DIR}/${APP_NAME}.sh"
DESKTOP_FILE="/usr/share/applications/YARC-Launcher.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/yarg/YARC-Launcher.desktop"
ICON_URL="https://static.wikitide.net/yargwiki/3/3c/YARG_Icon.png"

# Step 1: Detect architecture
echo "Detecting system architecture..."
arch=$(uname -m)
if [ "$arch" != "x86_64" ]; then
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Fetch latest YARC Launcher release
echo "Fetching latest YARC Launcher release..."
LATEST=$(curl -s https://api.github.com/repos/YARC-Official/YARC-Launcher/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
if [ -z "$LATEST" ]; then
    echo "Failed to fetch latest release. Exiting."
    exit 1
fi
LAUNCHER_URL="https://github.com/YARC-Official/YARC-Launcher/releases/download/${LATEST}/YARC.Launcher_${LATEST#v}_amd64.AppImage"
echo "Latest version: $LATEST"

# Step 3: Download launcher AppImage
echo "Downloading YARC Launcher..."
mkdir -p "$INSTALL_DIR" "$LOGS_DIR"
wget -q --show-progress -O "${INSTALL_DIR}/yarg-launcher.AppImage" "$LAUNCHER_URL"
if [ $? -ne 0 ]; then
    echo "Failed to download YARC Launcher. Exiting."
    exit 1
fi
chmod a+x "${INSTALL_DIR}/yarg-launcher.AppImage"
echo "YARC Launcher downloaded and marked as executable."

# Step 4: Create desktop entry for F1 Applications
echo "Creating desktop entry for YARC Launcher..."
mkdir -p "/userdata/system/configs/yarg" "${INSTALL_DIR}/extra"

echo "Downloading icon..."
wget -q --show-progress -O "${INSTALL_DIR}/extra/icon.png" "$ICON_URL"

cat > "${INSTALL_DIR}/yarg-launcher.sh" << 'EOF'
#!/bin/bash
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/yarg
cd /userdata/system/add-ons/yarg
./yarg-launcher.AppImage
EOF
chmod +x "${INSTALL_DIR}/yarg-launcher.sh"

cat > "$PERSISTENT_DESKTOP" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=YARC Launcher
Exec=/userdata/system/add-ons/yarg/yarg-launcher.sh
Icon=/userdata/system/add-ons/yarg/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF
chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Restore desktop entry on boot
cat > "/userdata/system/configs/yarg/restore_desktop_entry.sh" << 'EOF'
#!/bin/bash
if [ ! -f "/usr/share/applications/YARC-Launcher.desktop" ]; then
    cp "/userdata/system/configs/yarg/YARC-Launcher.desktop" "/usr/share/applications/YARC-Launcher.desktop"
    chmod +x "/usr/share/applications/YARC-Launcher.desktop"
fi
EOF
chmod +x "/userdata/system/configs/yarg/restore_desktop_entry.sh"

CUSTOM_SH="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/yarg/restore_desktop_entry.sh" "$CUSTOM_SH" 2>/dev/null; then
    echo 'bash "/userdata/system/configs/yarg/restore_desktop_entry.sh" &' >> "$CUSTOM_SH"
fi
chmod +x "$CUSTOM_SH"

# Step 5: Create Ports script pointing directly to the game
echo "Creating YARG Ports script..."
mkdir -p "$PORTS_DIR"
cat > "$PORT_SCRIPT" << 'EOF'
#!/bin/bash
export DISPLAY=:0.0
export HOME=/userdata/system/add-ons/yarg

INSTALL_DIR="/userdata/system/add-ons/yarg"
LOG_FILE="/userdata/system/logs/yarg.log"
mkdir -p /userdata/system/logs

exec &> >(tee -a "$LOG_FILE")
echo "$(date): Launching YARG"

# Find the game binary installed by YARC Launcher
GAME=$(find "${INSTALL_DIR}/.local/share/YARC/YARG Installs" -maxdepth 4 -name 'YARG' -type f 2>/dev/null | head -1)

if [ -x "$GAME" ]; then
    echo "Found game at: $GAME"
    cd "$(dirname "$GAME")"
    ./YARG "$@"
else
    echo "YARG game not found. Launching YARC Launcher to install..."
    cd "$INSTALL_DIR"
    ./yarg-launcher.AppImage
fi
EOF
chmod +x "$PORT_SCRIPT"

# Step 6: Add to gamelist.xml
echo "Downloading YARG logo..."
curl -L -o "$LOGO_PATH" "https://yarg.in/twitter-image.png"

echo "Adding YARG to gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/yarg-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete!"
echo "  - YARC Launcher available in F1 > Applications"
echo "  - Use the launcher to install YARG, then launch from Ports"
