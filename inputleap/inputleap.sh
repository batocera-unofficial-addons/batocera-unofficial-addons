#!/bin/bash
# BUA Installer: InputLeap (Flatpak)
# kevobato 2025

APPNAME="InputLeap"
APP_ID="io.github.input_leap.input-leap"
INSTALL_DIR="/userdata/system/bua/inputleap"
FLATPAK_GAMELIST="/userdata/roms/flatpak/gamelist.xml"
ICON_URL="https://raw.githubusercontent.com/input-leap/input-leap/master/res/input-leap.png"
ICON_PATH="/userdata/system/add-ons/${APPNAME,,}/extra/${APPNAME,,}-icon.png"
DESKTOP_ENTRY="/userdata/system/configs/${APPNAME,,}/${APPNAME,,}.desktop"
DESKTOP_DIR="/usr/share/applications"
CUSTOM_SCRIPT="/userdata/system/custom.sh"

mkdir -p "/userdata/system/add-ons/${APPNAME,,}/extra"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

echo "[+] Installing InputLeap via Flatpak..."

# Ensure directories exist
mkdir -p "$INSTALL_DIR"

# Add Flathub remote if missing
if ! flatpak remotes | grep -q "^flathub"; then
    echo "[+] Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install InputLeap Flatpak if not already installed
if ! flatpak list | grep -q "$APP_ID"; then
    echo "[+] Pulling InputLeap from Flathub..."
    flatpak install --system -y flathub "$APP_ID"
else
    echo "[*] InputLeap already installed, skipping download."
fi

echo "Updating Batocera Flatpaks..."
batocera-flatpak-update &> /dev/null

# Overwrite the flatpak gamelist.xml with InputLeap entry
update_flatpak_gamelist() {
    echo "Updating flatpak gamelist.xml with InputLeap entry..."

    if [ ! -f "${FLATPAK_GAMELIST}" ]; then
        echo "<gameList />" > "${FLATPAK_GAMELIST}"
    fi

    # Ensure xmlstarlet is installed
    if ! command -v xmlstarlet &> /dev/null; then
        echo "xmlstarlet is not installed. Skipping flatpak gamelist update."
        return
    fi

    xmlstarlet ed --inplace \
        -d "/gameList/game[path='./Input Leap.flatpak']" \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./Input Leap.flatpak" \
        -s "/gameList/game[last()]" -t elem -n name -v "Input Leap" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/Input Leap.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "true" \
        -s "/gameList/game[last()]" -t elem -n lang -v "en" \
        "${FLATPAK_GAMELIST}"

    echo "Flatpak gamelist.xml updated with InputLeap entry."
}

# Create launcher for InputLeap
create_launcher() {
# Download icon
curl -L -o "$ICON_PATH" "$ICON_URL"

# Create desktop entry
cat <<EOF > "${DESKTOP_ENTRY}"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=flatpak run $APP_ID --no-sandbox --socket=network --device=all --filesystem=host --share=network
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
}

# Update flatpak gamelist to hide the default entry
update_flatpak_gamelist

# Run all steps
create_launcher

echo "[+] ${APPNAME} setup complete with desktop entry."
sleep 5

