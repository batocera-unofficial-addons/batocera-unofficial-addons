#!/bin/bash

APP_ID="io.itch.itch"
LAUNCHER_PATH="/userdata/roms/ports/itchio.sh"

echo "📦 Ensuring Flathub user remote is added..."
if ! flatpak remote-list --user | grep -q "^flathub"; then
    flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "✅ Flathub remote added for user."
else
    echo "✔️ Flathub remote already present for user."
fi

echo "🔧 Installing Itch.io Flatpak (user install)..."
flatpak install --user -y flathub "$APP_ID"

echo "🔐 Setting permissions to allow full filesystem access..."
flatpak override --user "$APP_ID" --filesystem=host

echo "🚀 Creating launcher at $LAUNCHER_PATH..."
cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
flatpak run $APP_ID --no-sandbox

EOF

chmod +x "$LAUNCHER_PATH"

echo "✅ Itch.io Flatpak installed and launcher created!"
