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

# Step 2: Download Lutris Parts
echo "Downloading Lutris parts..."
mkdir -p /userdata/system/add-ons/lutris
wget -q --show-progress -O /userdata/system/add-ons/lutris/lutris_part_aa "$appimage_url/lutris_part_aa"
wget -q --show-progress -O /userdata/system/add-ons/lutris/lutris_part_bb "$appimage_url/lutris_part_ab"

if [ $? -ne 0 ]; then
    echo "Failed to download Lutris parts."
    exit 1
fi

# Reassemble the Lutris package
echo "Reassembling Lutris package..."
cat /userdata/system/add-ons/lutris/lutris_part_* > /userdata/system/add-ons/lutris/lutris.tar.xz

# Extract Lutris package
echo "Extracting Lutris..."
tar -xf /userdata/system/add-ons/lutris/lutris.tar.xz -C /userdata/system/add-ons/lutris/

chmod a+x /userdata/system/add-ons/lutris/lutris
echo "Lutris reassembled, extracted, and marked as executable."

# Remove the tar.xz file after extraction
rm /userdata/system/add-ons/lutris/lutris.tar.xz
rm /userdata/system/add-ons/lutris/lutris_part_*

# Create persistent configuration and log directories
mkdir -p /userdata/system/logs
mkdir -p /userdata/system/configs/lutris
mkdir -p /userdata/system/add-ons/lutris/extra
DESKTOP_FILE="/usr/share/applications/Lutris.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/lutris/Lutris.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/lutris/extra/icon.png"
INSTALL_DIR="/userdata/system/add-ons/lutris"

# Step 3: Create the Lutris Launcher Script
echo "Creating Lutris launcher script in Ports..."
mkdir -p /userdata/roms/ports
cat << 'EOF' > /userdata/roms/ports/Lutris.sh
#!/bin/bash
export DISPLAY=:0.0

cd /userdata/system/add-ons/lutris
ulimit -H -n 819200 && ulimit -S -n 819200 && sysctl -w fs.inotify.max_user_watches=8192000 vm.max_map_count=2147483642 fs.file-max=8192000 >/dev/null 2>&1 && dbus-run-session ./lutris
EOF

cat << 'EOF' > /userdata/system/add-ons/lutris/Launcher
#!/bin/bash
export DISPLAY=:0.0

ulimit -H -n 819200 && ulimit -S -n 819200 && sysctl -w fs.inotify.max_user_watches=8192000 vm.max_map_count=2147483642 fs.file-max=8192000 >/dev/null 2>&1 && dbus-run-session /userdata/system/add-ons/lutris/lutris
EOF

chmod +x /userdata/roms/ports/Lutris.sh
chmod +x /userdata/system/add-ons/lutris/Launcher

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
# Restore Lutris desktop entry
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring Lutris desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
    echo "Lutris desktop entry restored."
else
    echo "Lutris desktop entry already exists."
fi
EOF
chmod +x "/userdata/system/configs/lutris/restore_desktop_entry.sh"

# Add to startup script
custom_startup="/userdata/system/custom.sh"
if ! grep -q "/userdata/system/configs/lutris/restore_desktop_entry.sh" "$custom_startup"; then
    echo "Adding Lutris restore script to startup..."
    echo "bash \"/userdata/system/configs/lutris/restore_desktop_entry.sh\" &" >> "$custom_startup"
fi
chmod +x "$custom_startup"

echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

KEYS_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/lutris/extra/Lutris.sh.keys"
# Step 5: Download the key mapping file
echo "Downloading key mapping file..."
curl -L -o "/userdata/roms/ports/Lutris.sh.keys" "$KEYS_URL"
# Download the image
echo "Downloading Lutris logo..."
curl -L -o /userdata/roms/ports/images/lutrislogo.jpg https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/lutris/extra/logo.jpg

echo "Adding logo to Lutris entry in gamelist.xml..."
xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./Lutris.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Lutris" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/lutrislogo.jpg" \
  /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml

curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch Lutris from the F1 Applications menu and the Ports menu."
