#!/bin/bash

APPNAME="Flashpoint"
APPURL="https://github.com/DTJW92/batocera-unofficial-addons/releases/download/AppImages/flash.tar.xz"
DEST="/userdata/system/add-ons/${APPNAME,,}"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://static.wikia.nocookie.net/logopedia/images/0/0a/Flashpoint_2020_%28Icon%29_%28Alt%29_%281%29.png"
TAR_FILE="$DEST/flash.tar.xz"

# Create necessary directories
mkdir -p "$DEST"
mkdir -p "$DEST/extra"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

# Download Flashpoint
echo "Downloading ${APPNAME}..."
wget -q --show-progress -O "$TAR_FILE" "$APPURL"

# Extract Flashpoint (keeping the Flashpoint3 directory)
echo "Extracting ${APPNAME}..."
tar -xvf "$TAR_FILE" -C "$DEST" --strip-components=1
rm "$TAR_FILE"

# Ensure proper permissions
chmod +x -R "$DEST"

# Download application icon
echo "Downloading icon..."
wget --show-progress -qO "$DEST/extra/icon.png" "$ICON_URL"

# Create persistent desktop entry
echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Flashpoint Archive
Exec=$DEST/start-flashpoint.sh
Icon=$DEST/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"

# Copy the desktop entry to the system location
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

# Ensure the desktop entry is always restored at startup
echo "Ensuring ${APPNAME} desktop entry is restored at startup..."
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME,,}/restore_desktop_entry.sh"

cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
# Restore ${APPNAME} desktop entry
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

# Add the restore script to the startup script
CUSTOM_STARTUP="/userdata/system/custom.sh"

if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

echo "${APPNAME} installation complete!"
