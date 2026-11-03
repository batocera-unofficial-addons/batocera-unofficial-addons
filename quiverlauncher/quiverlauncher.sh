#!/bin/bash

# Variables to update for different apps
APP_NAME="QuiverLauncher"
DISPLAY_NAME="Quiver Launcher"
REPO="tgeorgiadis/quiver-launcher"
AMD_SUFFIX="linux-x64.AppImage"
ARM_SUFFIX="linux-arm64.AppImage"
LOGO_URL="https://raw.githubusercontent.com/tgeorgiadis/quiver-launcher/main/Assets/quiver-icon.png"
SCRIPTS_BASE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/quiverlauncher/extra"

# -----------------------------------------------------------------------------------------------------------------

ADDONS_DIR="/userdata/system/add-ons"
LOGS_DIR="/userdata/system/logs"
APP_DIR="${ADDONS_DIR}/${APP_NAME,,}"
ROMS_DIR="/userdata/roms/quiver"
GAME_LIST="${ROMS_DIR}/gamelist.xml"
MAIN_SCRIPT="${ROMS_DIR}/${APP_NAME}.sh"
LOGO_PATH="${ROMS_DIR}/images/${APP_NAME,,}-logo.png"
ES_CONFIG_DIR="/userdata/system/configs/emulationstation"
BATOCERA_CONF="/userdata/system/batocera.conf"

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    appimage_url=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r ".assets[] | select(.name | endswith(\"$AMD_SUFFIX\")) | .browser_download_url")
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    if [ -n "$ARM_SUFFIX" ]; then
        appimage_url=$(curl -s https://api.github.com/repos/$REPO/releases/latest | jq -r ".assets[] | select(.name | endswith(\"$ARM_SUFFIX\")) | .browser_download_url")
    else
        echo "No ARM64 AppImage suffix provided. Skipping download. Exiting."
        exit 1
    fi
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

if [ -z "$appimage_url" ]; then
    echo "No suitable AppImage found for architecture: $arch. Exiting."
    exit 1
fi

# Batocera 44 replaced emulatorlauncher with batocera-launch; the ES system
# has to call whichever one this Batocera has
batocera_version=$(batocera-version 2>/dev/null)
batocera_major=$(echo "$batocera_version" | grep -o '^[0-9]*')
echo "Batocera version: ${batocera_version:-unknown}"
if [ -z "$batocera_major" ]; then
    echo "Could not read the Batocera version. Exiting."
    exit 1
fi
if [ "$batocera_major" -ge 44 ]; then
    launcher="batocera-launch"
else
    launcher="emulatorlauncher"
fi
if ! command -v "$launcher" >/dev/null; then
    echo "Batocera $batocera_major should have $launcher, but it is missing. Exiting."
    exit 1
fi
echo "Launcher: $launcher"

# Step 2: Download the AppImage
# Quiver keeps its library (apps.json, settings.json, Apps/, Cache/) beside the
# AppImage, so reinstalling only replaces the AppImage and keeps the library.
echo "Downloading $DISPLAY_NAME AppImage from $appimage_url..."
mkdir -p "$APP_DIR"
wget -q --show-progress -O "$APP_DIR/${APP_NAME,,}.AppImage.tmp" "$appimage_url"

if [ $? -ne 0 ] || [ ! -s "$APP_DIR/${APP_NAME,,}.AppImage.tmp" ]; then
    echo "Failed to download $DISPLAY_NAME AppImage."
    rm -f "$APP_DIR/${APP_NAME,,}.AppImage.tmp"
    exit 1
fi

mv -f "$APP_DIR/${APP_NAME,,}.AppImage.tmp" "$APP_DIR/${APP_NAME,,}.AppImage"
chmod a+x "$APP_DIR/${APP_NAME,,}.AppImage"
echo "$DISPLAY_NAME AppImage downloaded and marked as executable."

# Step 3: Default settings
# - Start fullscreen (ES apps run without a window manager)
# - x86_64: run Windows apps through Batocera's own Wine, like the windows system
# Only settings that are still unset are written; Quiver fills in the rest.
echo "Configuring $DISPLAY_NAME settings..."
python3 - "$APP_DIR/settings.json" "$arch" <<'PYEOF'
import json, sys
path, arch = sys.argv[1], sys.argv[2]
try:
    with open(path, encoding="utf-8-sig") as f:
        settings = json.load(f)
    new_install = False
except (OSError, ValueError):
    settings, new_install = {}, True
if new_install:
    settings["StartFullscreen"] = True
if arch == "x86_64" and not settings.get("LinuxWindowsLaunchCommand"):
    settings["LinuxWindowsLaunchCommand"] = "batocera-wine windows play {exe}"
with open(path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
PYEOF

# Step 4: Download helper scripts
echo "Downloading $DISPLAY_NAME helper scripts..."
mkdir -p "$LOGS_DIR"
wget -q --show-progress -O "$APP_DIR/Launcher" "${SCRIPTS_BASE_URL}/Launcher"
wget -q --show-progress -O "$APP_DIR/create-quiver-launchers.sh" "${SCRIPTS_BASE_URL}/create-quiver-launchers.sh"
chmod +x "$APP_DIR/Launcher" "$APP_DIR/create-quiver-launchers.sh"

# Step 5: EmulationStation system
echo "Downloading EmulationStation config..."
mkdir -p "$ES_CONFIG_DIR"
wget -q --show-progress -O "$ES_CONFIG_DIR/es_systems_quiver.cfg" "${SCRIPTS_BASE_URL}/es_systems_quiver.cfg"
wget -q --show-progress -O "$ES_CONFIG_DIR/es_features_quiver.cfg" "${SCRIPTS_BASE_URL}/es_features_quiver.cfg"
if [ "$launcher" = "batocera-launch" ]; then
    sed -i 's|<command>emulatorlauncher |<command>batocera-launch |' "$ES_CONFIG_DIR/es_systems_quiver.cfg"
fi

# Use sh emulator so .sh launchers run through configgen (enables videomode, etc.)
sed -i '/^quiver\.emulator=/d; /^quiver\.core=/d' "$BATOCERA_CONF" 2>/dev/null || true
echo "quiver.emulator=sh" >> "$BATOCERA_CONF"
echo "quiver.core=sh" >> "$BATOCERA_CONF"

# Step 6: Quiver Launcher entry in the quiver system
echo "Creating $DISPLAY_NAME launcher..."
mkdir -p "$ROMS_DIR/images"
cat << EOF > "$MAIN_SCRIPT"
#!/bin/bash
$APP_DIR/Launcher "\$@"
EOF
chmod +x "$MAIN_SCRIPT"

# Hotkey + Start closes Quiver; all other buttons are left to Quiver's own
# gamepad support
echo "Downloading key mapping file..."
curl -fL -o "${MAIN_SCRIPT}.keys" "${SCRIPTS_BASE_URL}/${APP_NAME}.sh.keys"

echo "Downloading $DISPLAY_NAME logo..."
curl -fL -o "$LOGO_PATH" "$LOGO_URL" || rm -f "$LOGO_PATH"

echo "Adding $DISPLAY_NAME to gamelist.xml..."
if [[ ! -f "$GAME_LIST" ]]; then
    echo '<?xml version="1.0" encoding="UTF-8"?>' > "$GAME_LIST"
    echo '<gameList>' >> "$GAME_LIST"
    echo '</gameList>' >> "$GAME_LIST"
fi
xmlstarlet ed -d "/gameList/game[path='./${APP_NAME}.sh']" \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./${APP_NAME}.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "$DISPLAY_NAME" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/${APP_NAME,,}-logo.png" \
  "$GAME_LIST" > "$GAME_LIST.tmp" && mv "$GAME_LIST.tmp" "$GAME_LIST"

# Launchers for apps already in the library (reinstall)
"$APP_DIR/create-quiver-launchers.sh" --once

dialog --title "$DISPLAY_NAME Installed" --msgbox \
"$DISPLAY_NAME has been installed!\n\nOpen it from the Quiver Launcher system in EmulationStation.\n\nApps you install with it get their own entry in the same system after you close Quiver.\n\nHotkey + Start closes Quiver or a running app." \
14 60

# Finish: new system, EmulationStation must restart to show it
killall -9 emulationstation
