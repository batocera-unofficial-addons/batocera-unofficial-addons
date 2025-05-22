#!/bin/bash

APPNAME="FileZilla"
APPURL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main/filezilla/extra/FileZilla_3.68.1_x86_64-linux-gnu.tar.xz"
DEST="/userdata/system/add-ons/${APPNAME,,}"
DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME,,}/${APPNAME}.desktop"
ICON_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/${APPNAME,,}/extra/icon.png"
TAR_FILE="$DEST/FileZilla_3.68.1_x86_64-linux-gnu.tar.xz"

# Create necessary directories
mkdir -p "$DEST"
mkdir -p "$DEST/extra"
mkdir -p "/userdata/system/configs/${APPNAME,,}"

# Download FileZilla
echo "Downloading ${APPNAME}..."
wget -q --show-progress -O "$TAR_FILE" "$APPURL"

# Extract FileZilla (keeping the FileZilla3 directory)
echo "Extracting ${APPNAME}..."
tar -xvf "$TAR_FILE" -C "$DEST"
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
Name=${APPNAME}
Exec=$DEST/FileZilla3/bin/filezilla
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
