#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "aarch64" ]; then
    echo "Architecture: aarch64 detected."
    firefox_url="https://download-installer.cdn.mozilla.net/pub/firefox/releases/137.0.1/linux-aarch64/en-US/firefox-137.0.1.tar.xz"
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Download and extract Firefox for aarch64
mkdir -p /userdata/system/add-ons/firefox/extra
cd /userdata/system/add-ons/firefox
archive_name="firefox-137.0.1.tar.xz"

if [ ! -f "$archive_name" ]; then
    echo "Downloading Firefox from $firefox_url..."
    wget -q --show-progress "$firefox_url" -O "$archive_name"
fi

echo "Extracting Firefox..."
tar -xf "$archive_name" --strip-components=1
chmod +x firefox

# Create persistent log directory
mkdir -p /userdata/system/logs

# Step 3: Create the Firefox Script
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Firefox.sh
#!/bin/bash

# Ensure environment variables from EmulationStation (PID 1)
export $(cat /proc/1/environ | tr '\0' '\n' | grep -E '^DISPLAY|^XAUTHORITY')

export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/firefox"

# Log file
log_file="/tmp/firefox-es.log"
echo "$(date): Launching Firefox" > "$log_file"

# Launch Firefox
cd "$HOME"
./firefox
EOF

chmod +x /userdata/roms/ports/Firefox.sh

APPNAME="Firefox"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/icon.png"

mkdir -p "/userdata/system/configs/${APPNAME,,}"
mkdir -p "/userdata/system/add-ons/${APPNAME,,}/extra"

wget -qO "/userdata/system/add-ons/${APPNAME,,}/extra/icon.png" "$ICON_URL"

cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=${APPNAME}
Exec=/userdata/roms/ports/${APPNAME}.sh
Icon=/userdata/system/add-ons/${APPNAME,,}/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"
cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring ${APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "${APPNAME} desktop entry restored."
else
    echo "${APPNAME} desktop entry already exists."
fi
EOF
chmod +x "$RESTORE_SCRIPT"

CUSTOM_STARTUP="/userdata/system/custom.sh"
if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi
chmod +x "$CUSTOM_STARTUP"

# Step 4: Refresh the Ports menu
curl -s http://127.0.0.1:1234/reloadgames

# Download the image
echo "Downloading Firefox logo..."
curl -L -o /userdata/roms/ports/images/firefox-logo.png https://github.com/DTJW92/batocera-unofficial-addons/raw/main/firefox/extra/firefox-logo.png

echo "Adding logo to Firefox entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Firefox.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Firefox" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/firefox-logo.png" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl -s http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Firefox from the Ports menu."
