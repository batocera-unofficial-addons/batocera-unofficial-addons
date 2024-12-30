#!/bin/bash
# Clone Hero Installer for Batocera

# Configuration
APP_NAME="Clone Hero"
INSTALL_DIR="/userdata/system/add-ons/clonehero"
APP_EXEC="$INSTALL_DIR/CloneHero"
CONFIG_DIR="$INSTALL_DIR/config"
HOME_DIR="$INSTALL_DIR/home"
ROMS_DIR="$INSTALL_DIR/roms"
PORTS_DIR="/userdata/roms/ports"
LOGO_URL="https://raw.githubusercontent.com/KevoBato/batocera-assets/main/logos/clonehero.png"
LOGO_PATH="$PORTS_DIR/clonehero.png"
GAME_LIST="$PORTS_DIR/gamelist.xml"
GAME_URL="https://github.com/clonehero-game/releases/releases/download/v1.1.0.4261-PTB/clonehero-linux.tar.xz"

# Functions
log() { echo -e "\e[1;32m$1\e[0m"; }
error() { echo -e "\e[1;31m$1\e[0m"; exit 1; }

setup_directories() {
  log "Setting up directories..."
  mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$HOME_DIR" "$ROMS_DIR"
}

download_game() {
  log "Downloading Clone Hero..."
  curl -L "$GAME_URL" -o /tmp/clonehero.tar.xz || error "Failed to download game."
  tar -xvf /tmp/clonehero.tar.xz -C "$INSTALL_DIR" --strip-components=1 || error "Failed to extract game files."
  rm /tmp/clonehero.tar.xz
}

create_launcher() {
  log "Creating launcher script..."
  cat <<EOF >"$PORTS_DIR/Clone Hero.sh"
#!/bin/bash
export CLONEHERO_HOME="$HOME_DIR"
export XDG_CONFIG_HOME="$CONFIG_DIR"
export XDG_DATA_HOME="$INSTALL_DIR"
export CLONEHERO_ROMS="$ROMS_DIR"
exec "$APP_EXEC"
EOF
  chmod +x "$PORTS_DIR/Clone Hero.sh"
}

add_to_ports() {
  log "Adding to Ports menu..."
  curl -L "$LOGO_URL" -o "$LOGO_PATH" || error "Failed to download logo."
  if [ ! -f "$GAME_LIST" ]; then
    echo "<?xml version='1.0'?><gameList />" > "$GAME_LIST"
  fi

  curl http://127.0.0.1:1234/reloadgames
  
  xmlstarlet ed -L \
    -s "/gameList" -t elem -n "game" \
    -s "/gameList/game[last()]" -t elem -n "path" -v "./Clone Hero.sh" \
    -s "/gameList/game[last()]" -t elem -n "name" -v "$APP_NAME" \
    -s "/gameList/game[last()]" -t elem -n "image" -v "$LOGO_PATH" \
    "$GAME_LIST"

  curl http://127.0.0.1:1234/reloadgames
}



cleanup() {
  log "Cleaning up..."
  rm -rf /tmp/clonehero.tar.xz
}

# Main
log "Starting $APP_NAME installation..."
setup_directories
if [ ! -f "$APP_EXEC" ]; then
  download_game
fi
create_launcher
add_to_ports
cleanup
log "$APP_NAME installation complete!"
