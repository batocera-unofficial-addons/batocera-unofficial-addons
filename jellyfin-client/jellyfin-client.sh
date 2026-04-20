#!/bin/bash

# Variables
APP_NAME="Jellyfin Player"
APP_DIR_NAME="jellyfin-player"
VERSION="1.0.0"
RELEASE_BASE="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages"
KEYS_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/jellyfin-client/extra/JellyfinPlayer.sh.keys"
LOGO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/jellyfin-client/extra/jellyfin-player-logo.jpg"

ADDONS_DIR="/userdata/system/add-ons"
PORTS_DIR="/userdata/roms/ports"
LOGS_DIR="/userdata/system/logs"
APP_INSTALL_DIR="${ADDONS_DIR}/${APP_DIR_NAME}"
PORT_SCRIPT="${PORTS_DIR}/JellyfinPlayer.sh"
KEYS_PATH="${PORTS_DIR}/JellyfinPlayer.sh.keys"
LOGO_PATH="${PORTS_DIR}/images/jellyfin-player-logo.jpg"
GAME_LIST="${PORTS_DIR}/gamelist.xml"

# Detect arch
arch=$(uname -m)
case "$arch" in
    x86_64)  APPIMAGE_URL="${RELEASE_BASE}/JellyfinPlayer-x86_64.AppImage" ;;
    aarch64) APPIMAGE_URL="${RELEASE_BASE}/JellyfinPlayer-aarch64.AppImage" ;;
    *)
        echo "Unsupported architecture: $arch. Exiting."
        exit 1
        ;;
esac

# Create install directory
mkdir -p "${APP_INSTALL_DIR}"
mkdir -p "${LOGS_DIR}"

# Download AppImage
echo "Downloading ${APP_NAME} (${arch})..."
if ! wget -q --show-progress -O "${APP_INSTALL_DIR}/JellyfinPlayer.AppImage" "${APPIMAGE_URL}"; then
    echo "Failed to download ${APP_NAME}. Exiting."
    exit 1
fi
chmod +x "${APP_INSTALL_DIR}/JellyfinPlayer.AppImage"
echo "AppImage ready at ${APP_INSTALL_DIR}/JellyfinPlayer.AppImage"

# Create Launcher script
echo "Creating Launcher..."
cat << 'EOF' > "${APP_INSTALL_DIR}/Launcher"
#!/bin/bash
~/add-ons/.dep/mousemove.sh 2>/dev/null

export DISPLAY=:0.0
export XCURSOR_THEME=Adwaita
export XCURSOR_SIZE=24

APP="/userdata/system/add-ons/jellyfin-player/JellyfinPlayer.AppImage"
"$APP" --no-sandbox --enable-smooth-scrolling
EOF
chmod +x "${APP_INSTALL_DIR}/Launcher"

# Create ports launcher
echo "Creating port script..."
mkdir -p "${PORTS_DIR}"
cat << 'EOF' > "${PORT_SCRIPT}"
#!/bin/bash
killall -9 electron 2>/dev/null
/userdata/system/add-ons/jellyfin-player/Launcher
EOF
chmod +x "${PORT_SCRIPT}"
echo "Port script created at ${PORT_SCRIPT}"

# Download keys file
echo "Downloading keys file..."
if ! curl -fsSL -o "${KEYS_PATH}" "${KEYS_URL}"; then
    echo "Warning: failed to download keys file. Controller mapping may not work."
fi

# Download logo
echo "Downloading logo..."
mkdir -p "${PORTS_DIR}/images"
curl -fsSL -o "${LOGO_PATH}" "${LOGO_URL}" || echo "Warning: failed to download logo."

# Add to ports gamelist.xml
echo "Adding entry to gamelist.xml..."
if [ ! -f "${GAME_LIST}" ]; then
    echo "<gameList />" > "${GAME_LIST}"
fi

xmlstarlet ed --inplace \
    -d "/gameList/game[path='./JellyfinPlayer.sh']" \
    -s "/gameList" -t elem -n game \
    -s "/gameList/game[last()]" -t elem -n path -v "./JellyfinPlayer.sh" \
    -s "/gameList/game[last()]" -t elem -n name -v "Jellyfin Player" \
    -s "/gameList/game[last()]" -t elem -n desc -v "Jellyfin media player with controller support" \
    -s "/gameList/game[last()]" -t elem -n image -v "./images/jellyfin-player-logo.jpg" \
    -s "/gameList/game[last()]" -t elem -n rating -v "0" \
    -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
    -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
    "${GAME_LIST}"

# Reload Ports menu
curl -s http://127.0.0.1:1234/reloadgames > /dev/null

echo ""
echo "${APP_NAME} installation complete!"
echo "Launch from the Ports menu."
