#!/bin/bash

APP_ID="io.itch.itch"
APPNAME="itch.io"
LAUNCHER_PATH="/userdata/roms/ports/itch.io.sh"

# Image URL and path
LOGO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/itchio/extra/itch-icon.png"
PORTS_IMAGE_PATH="/userdata/roms/ports/images/itch-icon.png"

echo "🔧 Installing Itch.io Flatpak..."
flatpak install --user -y flathub $APP_ID

echo "🔐 Setting permissions to allow full filesystem access..."
flatpak override $APP_ID --filesystem=host

echo "🚀 Creating launcher at $LAUNCHER_PATH..."
cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
flatpak run $APP_ID --no-sandbox
EOF

chmod +x "$LAUNCHER_PATH"

echo "📥 Downloading Itch.io logo image..."
mkdir -p "$(dirname "$PORTS_IMAGE_PATH")"
curl -fsSL "$LOGO_URL" -o "$PORTS_IMAGE_PATH"

# Ensure gamelist.xml exists
PORTS_GAMELIST="/userdata/roms/ports/gamelist.xml"
if [ ! -f "$PORTS_GAMELIST" ]; then
    echo "⚠️ Ports gamelist.xml not found. Creating a new one."
    echo "<gameList />" > "$PORTS_GAMELIST"
fi

# Add or update the itch.io entry in gamelist.xml
if ! xmlstarlet sel -t -c "//game[path='./itch.io.sh']" "$PORTS_GAMELIST" &>/dev/null; then
    echo "➕ Adding itch.io entry to ports gamelist.xml..."
    xmlstarlet ed --inplace \
        -s "/gameList" -t elem -n game \
        -s "/gameList/game[last()]" -t elem -n path -v "./itch.io.sh" \
        -s "/gameList/game[last()]" -t elem -n name -v "$APPNAME" \
        -s "/gameList/game[last()]" -t elem -n desc -v "Itch.io" \
        -s "/gameList/game[last()]" -t elem -n image -v "./images/itch-icon.png" \
        -s "/gameList/game[last()]" -t elem -n rating -v "0" \
        -s "/gameList/game[last()]" -t elem -n releasedate -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n hidden -v "false" \
        "$PORTS_GAMELIST"
else
    echo "✏️ Updating itch.io entry in ports gamelist.xml..."
    xmlstarlet ed --inplace \
        -u "//game[path='./itch.io.sh']/name" -v "$APPNAME" \
        -u "//game[path='./itch.io.sh']/desc" -v "Itch.io" \
        -u "//game[path='./itch.io.sh']/image" -v "./images/itch-icon.png" \
        -u "//game[path='./itch.io.sh']/hidden" -v "false" \
        "$PORTS_GAMELIST"
fi

echo "✅ Itch.io Flatpak installed, launcher created, and menu entry updated!"
