#!/bin/bash

# URLs
SCRIPT_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/symlinks.sh"
BATOCERA_ADDONS_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/BUA.sh"
BATOCERA_ADDONS_LOGO_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/batocera-unofficial-addons.png"
BATOCERA_ADDONS_WHEEL_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/batocera-unofficial-addons-wheel.png"
XMLSTARLET_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/xmlstarlet"
ICON_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/icon.png"
BUA_CLI_URL="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/bua_cli.py"

# Paths
DOWNLOAD_DIR="/userdata/system/services"
SCRIPT_NAME="symlink_manager.sh"
SCRIPT_PATH="$DOWNLOAD_DIR/$SCRIPT_NAME"

ROM_PORTS_DIR="/userdata/roms/ports"
BATOCERA_ADDONS_PATH="$ROM_PORTS_DIR/bua.sh"

XMLSTARLET_DEST="/userdata/system/add-ons/.dep/xmlstarlet"
BUA_CLI_DEST="/userdata/system/add-ons/bua/bin/bua"

APPNAME="BUA"
APPNAME_LC="${APPNAME,,}"

DESKTOP_FILE="/usr/share/applications/${APPNAME}.desktop"
PERSISTENT_DESKTOP="/userdata/system/configs/${APPNAME_LC}/${APPNAME}.desktop"
RESTORE_SCRIPT="/userdata/system/configs/${APPNAME_LC}/restore_desktop_entry.sh"
CUSTOM_STARTUP="/userdata/system/custom.sh"

PORTS_IMAGES_DIR="/userdata/roms/ports/images"
BATOCERA_ADDONS_LOGO_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons.png"
BATOCERA_ADDONS_WHEEL_DEST="${PORTS_IMAGES_DIR}/BatoceraUnofficialAddons_Wheel.png"
GAMELIST_XML="${ROM_PORTS_DIR}/gamelist.xml"

# Ensure directories exist
mkdir -p "$DOWNLOAD_DIR" \
         "/userdata/system/add-ons" \
         "/userdata/system/add-ons/${APPNAME_LC}/extra" \
         "/userdata/system/configs/${APPNAME_LC}" \
         "$PORTS_IMAGES_DIR" \
         "$ROM_PORTS_DIR"

# Make sure custom.sh exists to keep grep happy under -euo
touch "$CUSTOM_STARTUP"

echo "Downloading the symlink manager script from $SCRIPT_URL..."
curl -fLs -o "$SCRIPT_PATH" "$SCRIPT_URL"

if [ ! -s "$SCRIPT_PATH" ]; then
    echo "Failed to download the symlink manager script. Exiting."
    exit 1
fi

# Download base dependencies
curl -fLs https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/app/dep.sh | bash

# Remove .sh extension and make executable
SCRIPT_WITHOUT_EXTENSION="${SCRIPT_PATH%.sh}"
mv "$SCRIPT_PATH" "$SCRIPT_WITHOUT_EXTENSION"
chmod +x "$SCRIPT_WITHOUT_EXTENSION"

echo "Enabling batocera-unofficial-addons-symlinks service..."
batocera-services enable symlink_manager

echo "Starting batocera-unofficial-addons-symlinks service..."
batocera-services start symlink_manager &>/dev/null &

echo "Downloading Batocera Unofficial Add-Ons Launcher from $BATOCERA_ADDONS_URL..."
wget --show-progress -O "$BATOCERA_ADDONS_PATH" "$BATOCERA_ADDONS_URL"

if [ ! -s "$BATOCERA_ADDONS_PATH" ]; then
    echo "Failed to download batocera-unofficial-addons launcher. Exiting."
    exit 1
fi

chmod +x "$BATOCERA_ADDONS_PATH"

# Download xmlstarlet
echo "Downloading xmlstarlet..."
mkdir -p "$(dirname "$XMLSTARLET_DEST")"
wget --show-progress -O "$XMLSTARLET_DEST" "$XMLSTARLET_URL"

if [ ! -s "$XMLSTARLET_DEST" ]; then
    echo "Failed to download xmlstarlet. Exiting."
    exit 1
fi

chmod +x "$XMLSTARLET_DEST"

echo "Creating symlink for xmlstarlet in /usr/bin..."
ln -sf "$XMLSTARLET_DEST" /usr/bin/xmlstarlet

# Download the bua command-line tool. symlink_manager links it into /usr/bin
# at boot; link it now so it works straight away.
echo "Downloading the bua command-line tool..."
mkdir -p "$(dirname "${BUA_CLI_DEST}")"
wget --show-progress -O "${BUA_CLI_DEST}" "${BUA_CLI_URL}"

if [ ! -s "${BUA_CLI_DEST}" ]; then
    echo "Failed to download the bua command-line tool. Exiting."
    exit 1
fi

chmod +x "${BUA_CLI_DEST}"
ln -sf "${BUA_CLI_DEST}" /usr/bin/bua

echo "Downloading icon..."
wget --show-progress -O "/userdata/system/add-ons/${APPNAME_LC}/extra/icon.png" "$ICON_URL"

echo "Creating persistent desktop entry for ${APPNAME}..."
cat <<EOF > "$PERSISTENT_DESKTOP"
[Desktop Entry]
Version=1.0
Type=Application
Name=Batocera Unofficial Add Ons
Exec=/userdata/roms/ports/bua.sh
Icon=/userdata/system/add-ons/${APPNAME_LC}/extra/icon.png
Terminal=false
Categories=Game;batocera.linux;
EOF

chmod +x "$PERSISTENT_DESKTOP"
cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

echo "Creating restore script for ${APPNAME} desktop entry..."
cat <<EOF > "$RESTORE_SCRIPT"
#!/bin/bash
if [ ! -f "$DESKTOP_FILE" ]; then
    echo "Restoring ${APPNAME} desktop entry..."
    cp "$PERSISTENT_DESKTOP" "$DESKTOP_FILE"
    chmod +x "$DESKTOP_FILE"
fi
EOF

chmod +x "$RESTORE_SCRIPT"

# Add restore script to startup if not already present
if ! grep -q "$RESTORE_SCRIPT" "$CUSTOM_STARTUP"; then
    echo "Adding ${APPNAME} restore script to startup..."
    echo "bash \"$RESTORE_SCRIPT\" &" >> "$CUSTOM_STARTUP"
fi

chmod +x "$CUSTOM_STARTUP"

echo "Refreshing Ports menu (non-fatal)..."
curl -fs http://127.0.0.1:1234/reloadgames || true

# Ensure gamelist.xml exists
if [ ! -f "$GAMELIST_XML" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$GAMELIST_XML"
fi

echo "Downloading Batocera Unofficial Add-ons logo..."
curl -fLs -o "$BATOCERA_ADDONS_LOGO_DEST" "$BATOCERA_ADDONS_LOGO_URL"
if [ ! -s "$BATOCERA_ADDONS_LOGO_DEST" ]; then
    echo "Failed to download logo. Exiting."
    exit 1
fi

echo "Downloading Batocera Unofficial Add-ons wheel..."
curl -fLs -o "$BATOCERA_ADDONS_WHEEL_DEST" "$BATOCERA_ADDONS_WHEEL_URL"
if [ ! -s "$BATOCERA_ADDONS_WHEEL_DEST" ]; then
    echo "Failed to download wheel image. Exiting."
    exit 1
fi

# Make gamelist.xml idempotent for ./bua.sh
echo "Updating gamelist.xml entry for BUA..."
# Remove any existing entries for ./bua.sh
xmlstarlet ed \
  -P -L \
  -d "/gameList/game[path='./bua.sh']" \
  "$GAMELIST_XML"

# Append fresh entry
xmlstarlet ed \
  -P \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./bua.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "Batocera Unofficial Add-Ons Installer" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/BatoceraUnofficialAddons.png" \
  -s "/gameList/game[last()]" -t elem -n "marquee" -v "./images/BatoceraUnofficialAddons_Wheel.png" \
  "$GAMELIST_XML" > "${GAMELIST_XML}.tmp"

mv "${GAMELIST_XML}.tmp" "$GAMELIST_XML"

curl -fs http://127.0.0.1:1234/reloadgames || true

# Install BUA Python hook (enables add-on configgen generators)
echo "Installing BUA Python hook..."
USERCUSTOMIZE_DIR="/userdata/system/.local/lib/python3.12/site-packages"
mkdir -p "$USERCUSTOMIZE_DIR"
curl -fLs -o "$USERCUSTOMIZE_DIR/usercustomize.py" \
    "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/usercustomize.py"

echo
# BUA updater package: the version-aware Updater screen. It is a release
# asset, checked against this SHA256 before anything is installed; BUA
# works the same without it.
BUA_UPDATER_URL="${BUA_UPDATER_URL:-https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/updater-v1/bua-updater-x86_64.tar.gz}"
BUA_UPDATER_SHA256="2ccfc0205be2611d43f21b35978e17a25b42b029ababf8e0f34afe5d4c7af148"
BUA_UPDATER_DIR="/userdata/system/add-ons/bua/updater"

install_bua_updater() {
    local tmp
    tmp="$(mktemp -d)" || return 1
    if ! curl -fLs --retry 3 -o "$tmp/updater.tar.gz" "$BUA_UPDATER_URL"; then
        echo "Could not download the BUA updater package."
    elif ! echo "$BUA_UPDATER_SHA256  $tmp/updater.tar.gz" | sha256sum -c --status; then
        echo "BUA updater package failed its checksum; not installed."
    elif ! python3 - "$tmp/updater.tar.gz" "$tmp/x" <<'BUA_EXTRACT'
import os, sys, tarfile
# Regular files and folders under updater/ only: no links, devices or ../
with tarfile.open(sys.argv[1]) as tar:
    for m in tar.getmembers():
        parts = m.name.split("/")
        if parts[0] != "updater" or m.name.startswith("/") or ".." in parts or not (m.isfile() or m.isdir()):
            sys.exit(f"unsafe entry: {m.name}")
    tar.extractall(sys.argv[2])
BUA_EXTRACT
    then
        echo "BUA updater package could not be extracted."
    else
        mkdir -p "$(dirname "$BUA_UPDATER_DIR")"
        rm -rf "$BUA_UPDATER_DIR.previous"
        if [ -d "$BUA_UPDATER_DIR" ]; then mv "$BUA_UPDATER_DIR" "$BUA_UPDATER_DIR.previous"; fi
        if mv "$tmp/x/updater" "$BUA_UPDATER_DIR"; then
            rm -rf "$BUA_UPDATER_DIR.previous" "$tmp"
            python3 "$BUA_UPDATER_DIR/install.py" || echo "Warning: BUA updater post-install step failed."
            echo "BUA updater package installed."
            return 0
        fi
        [ -d "$BUA_UPDATER_DIR.previous" ] && mv "$BUA_UPDATER_DIR.previous" "$BUA_UPDATER_DIR"
    fi
    rm -rf "$tmp"
    return 1
}

echo "Installing the BUA updater package..."
install_bua_updater || echo "Continuing without the BUA updater package."

echo "Installation complete! You can now launch Batocera Unofficial Add-Ons from the Ports menu."
