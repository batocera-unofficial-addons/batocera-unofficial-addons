#!/bin/bash

# Set application name
APPNAME="Bottles"

# Paths
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
ICON_URL="https://raw.githubusercontent.com/ivan-hc/Bottles-appimage/main/bottles.png"
ICON_PATH="/userdata/system/add-ons/${APPNAME,,}/extra/${APPNAME,,}-icon.png"
DESKTOP_ENTRY="/userdata/system/configs/${APPNAME,,}/${APPNAME,,}.desktop"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"

# Ensure required directories
mkdir -p "$(dirname "$ICON_PATH")"
mkdir -p "$(dirname "$DESKTOP_ENTRY")"

# Ensure xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null; then
    echo "❌ xmlstarlet is not installed. Please install it to continue."
    exit 1
fi

# Progress bar for flatpak install
show_progress_bar_from_log() {
    local LOGFILE=$1
    local PROGRESS=0

    while kill -0 "$2" 2>/dev/null; do
        if [ -f "$LOGFILE" ]; then
            PROGRESS=$(grep -oE '[0-9]+%' "$LOGFILE" | tail -n 1 | tr -d '%')
            [[ -z "$PROGRESS" ]] && PROGRESS=0
            printf "\r[%-50s] %d%%" "$(printf '#%.0s' $(seq 1 $((PROGRESS / 2))))" "$PROGRESS"
        fi
        sleep 0.5
    done
    printf "\r[%-50s] 100%%\n" "$(printf '#%.0s' $(seq 1 50))"
}

# Install Bottles
echo "📦 Installing Bottles..."
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

LOGFILE="/tmp/bottles_install.log"
flatpak install --system -y flathub com.usebottles.bottles &> "$LOGFILE" &
show_progress_bar_from_log "$LOGFILE" $!

batocera-flatpak-update &>/dev/null
echo "✅ Bottles installed."

# Hide Bottles from flatpak gamelist
if [ ! -f "${FLATPAK_GAMELIST}" ]; then
    echo "<gameList />" > "${FLATPAK_GAMELIST}"
fi

if ! xmlstarlet sel -t -c "//game[path='./Bottles.flatpak']" "${FLATPAK_GAMELIST}" &>/dev/null; then
    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./Bottles.flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "${APPNAME}" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/${APPNAME,,}.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"
    echo "🔒 Bottles hidden from flatpak menu."
fi

# Download icon
curl -L -o "$ICON_PATH" "$ICON_URL"

# Create desktop entry
cat <<EOF > "${DESKTOP_ENTRY}"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=flatpak run com.usebottles.bottles
Icon=${ICON_PATH}
Terminal=false
Categories=Utility;batocera.linux;
EOF

cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
chmod +x "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"

# Restore script for .desktop
cat <<EOF > "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
#!/bin/bash
if [ ! -f "${DESKTOP_DIR}/${APPNAME,,}.desktop" ]; then
    cp "${DESKTOP_ENTRY}" "${DESKTOP_DIR}/${APPNAME,,}.desktop"
    chmod +x "${DESKTOP_DIR}/${APPNAME,,}.desktop"
fi
EOF
chmod +x "/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

# Add restore script to custom.sh if not already added
if ! grep -q "restore_desktop_entry.sh" "${CUSTOM_SCRIPT}" 2>/dev/null; then
    echo "\"/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh\" &" >> "${CUSTOM_SCRIPT}"
fi

echo "✅ ${APPNAME} setup complete with desktop entry."
