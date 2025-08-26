#!/bin/bash
# BUA Installer: InputLeap (Flatpak)
# kevobato 2025

APP_ID="io.github.input_leap.input-leap"
INSTALL_DIR="/userdata/system/bua/inputleap"
DESKTOP_DIR="/userdata/system/Desktop"
DESKTOP_FILE="$DESKTOP_DIR/input-leap.desktop"

echo "[+] Installing InputLeap via Flatpak..."

# Ensure directories exist
mkdir -p "$INSTALL_DIR"
mkdir -p "$DESKTOP_DIR"

# Add Flathub remote if missing
if ! flatpak remotes | grep -q "^flathub"; then
    echo "[+] Adding Flathub remote..."
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
fi

# Install InputLeap Flatpak if not already installed
if ! flatpak list | grep -q "$APP_ID"; then
    echo "[+] Pulling InputLeap from Flathub..."
    flatpak install -y flathub "$APP_ID"
else
    echo "[*] InputLeap already installed, skipping download."
fi

# Write .desktop launcher
echo "[+] Creating desktop shortcut at $DESKTOP_FILE"
cat <<EOF > "$DESKTOP_FILE"
[Desktop Entry]
Version=1.0
Type=Application
Name=InputLeap
Exec=flatpak run $APP_ID --no-sandbox --socket=network --device=all --filesystem=host --share=network
Terminal=false
Categories=Utility;Application;batocera.linux;
Icon=/userdata/saves/flatpak/data/.local/share/flatpak/appstream/flathub/x86_64/active/icons/128x128/$APP_ID.png
MimeType=text/plain
EOF

chmod +x "$DESKTOP_FILE"

echo "[+] InputLeap installation complete."
echo "[*] You should now see 'InputLeap' on your Desktop."

