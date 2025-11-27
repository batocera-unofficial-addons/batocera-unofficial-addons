#!/bin/bash
set -euo pipefail

###############################################################################
# Nazi Zombies: Portable Installer for Batocera
###############################################################################

echo "==================================================================="
echo "Nazi Zombies: Portable Installer"
echo "==================================================================="

# Detect system architecture
echo "[*] Detecting system architecture..."
arch=$(uname -m)

case "$arch" in
    x86_64)
        echo "    Architecture: x86_64 detected"
        DOWNLOAD_URL="https://github.com/nzp-team/nzportable/releases/download/nightly/nzportable-linux64.zip"
        BINARY_NAME="nzportable64-sdl"
        ;;
    aarch64|armv8*|arm64)
        echo "    Architecture: ARM64/aarch64 detected"
        DOWNLOAD_URL="https://github.com/nzp-team/nzportable/releases/download/nightly/nzportable-linuxarm64.zip"
        BINARY_NAME="nzportablearm64-sdl"
        ;;
    *)
        echo "[!] Error: Unsupported architecture: $arch"
        echo "    Supported architectures: x86_64, ARM64/aarch64"
        exit 1
        ;;
esac

# Setup directories
INSTALL_DIR="/userdata/roms/ports/nzp"
TEMP_ZIP="/tmp/nzp.zip"

echo "[*] Creating installation directory..."
mkdir -p "${INSTALL_DIR}"

# Download latest nightly build
echo "[*] Downloading Nazi Zombies: Portable..."
echo "    URL: ${DOWNLOAD_URL}"
if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "${TEMP_ZIP}" "${DOWNLOAD_URL}"
elif command -v curl >/dev/null 2>&1; then
    curl -L -o "${TEMP_ZIP}" "${DOWNLOAD_URL}"
else
    echo "[!] Error: Neither wget nor curl found!"
    exit 1
fi

# Extract the zip file
echo "[*] Extracting archive..."
cd "${INSTALL_DIR}"
unzip -o "${TEMP_ZIP}"

# Clean up
rm -f "${TEMP_ZIP}"

# Make binary executable
chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

# Create launcher script
echo "[*] Creating launcher script..."
PORTS_DIR="/userdata/roms/ports"
LAUNCHER_SCRIPT="${PORTS_DIR}/Nazi Zombies Portable.sh"

cat > "${LAUNCHER_SCRIPT}" <<LAUNCHER_EOF
#!/bin/bash
cd /userdata/roms/ports/nzp
./${BINARY_NAME}
LAUNCHER_EOF

chmod +x "${LAUNCHER_SCRIPT}"

# Download logo
echo "[*] Downloading logo..."
mkdir -p "${PORTS_DIR}/images"
curl -L -o "${PORTS_DIR}/images/nzp-logo.png" \
  "https://media.moddb.com/images/articles/1/51/50682/nzp.png" 2>/dev/null || true

# Add entry to gamelist.xml
echo "[*] Adding entry to gamelist.xml..."
if [ -f /userdata/roms/ports/gamelist.xml ]; then
    xmlstarlet ed -s "/gameList" -t elem -n "game" -v "" \
      -s "/gameList/game[last()]" -t elem -n "path" -v "./Nazi Zombies Portable.sh" \
      -s "/gameList/game[last()]" -t elem -n "name" -v "Nazi Zombies Portable" \
      -s "/gameList/game[last()]" -t elem -n "image" -v "./images/nzp-logo.png" \
      /userdata/roms/ports/gamelist.xml > /userdata/roms/ports/gamelist.xml.tmp && \
      mv /userdata/roms/ports/gamelist.xml.tmp /userdata/roms/ports/gamelist.xml
fi

# Refresh EmulationStation game list
echo "[*] Refreshing EmulationStation..."
curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 || true

echo ""
echo "==================================================================="
echo "Nazi Zombies: Portable installed successfully!"
echo "==================================================================="
echo ""
echo "Launch from: Ports > Nazi Zombies Portable"
echo ""
echo "Installation location: /userdata/roms/ports/nzp"
echo ""
echo "==================================================================="
