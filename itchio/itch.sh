#!/bin/bash

APP_ID="io.itch.itch"
LAUNCHER_PATH="/userdata/roms/ports/itchio.sh"

echo "📦 Ensuring Flathub remote is added..."
if ! flatpak remote-list | grep -q "^flathub"; then
    flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo
    echo "✅ Flathub remote added."
else
    echo "✔️ Flathub remote already present."
fi

echo "🔧 Installing Itch.io Flatpak (user install)..."
flatpak install --user -y flathub $APP_ID

echo "🔐 Setting permissions to allow full filesystem access..."
flatpak override --user $APP_ID --filesystem=host

echo "🚀 Creating launcher at $LAUNCHER_PATH..."
cat <<EOF > "$LAUNCHER_PATH"
#!/bin/bash
flatpak run $APP_ID --no-sandbox

EOF

chmod +x "$LAUNCHER_PATH"

echo "✅ Itch.io Flatpak installed and launcher created!"
