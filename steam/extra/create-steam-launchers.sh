#!/bin/bash
set -e

########################
# CONFIG
########################

# Where ES "ROMs" will live
roms="/userdata/roms/steam"
images="/userdata/roms/steam/images"
GAMELIST_PATH="$roms/gamelist.xml"

# Where Steam lives
STEAM_APPS="/userdata/system/add-ons/steam/.steam.config/overlays/upperdir/home/steam/.local/share/Steam/steamapps"

# Optional: a generic placeholder image (if you want one)
# PLACEHOLDER_IMAGE="/userdata/roms/steam/images/steam-placeholder.jpg"

# Loop delay in seconds (how often to check for new games)
LOOP_DELAY=5

########################
# Setup
########################

mkdir -p "$roms" "$images"

echo "Steam Launcher Generator - Starting continuous mode"
echo "Checking for new games every ${LOOP_DELAY} seconds..."
echo "Press Ctrl+C to stop"
echo ""

########################
# Main Loop
########################

while true; do

# Ensure gamelist exists with proper structure
if [[ ! -f "$GAMELIST_PATH" ]]; then
  echo "Creating initial gamelist.xml..."
  echo '<?xml version="1.0" encoding="UTF-8"?>' > "$GAMELIST_PATH"
  echo '<gameList>' >> "$GAMELIST_PATH"
  echo '</gameList>' >> "$GAMELIST_PATH"
fi

########################
# Generate .sh launchers and gamelist entries
########################

NEW_LAUNCHER_CREATED=false

for manifest in "$STEAM_APPS"/appmanifest_*.acf; do
  [[ -f "$manifest" ]] || continue

  # Parse from Valve KV format
  appid=$(grep -m1 '"appid"' "$manifest"  | sed 's/[^0-9]*\([0-9]\+\).*/\1/')
  name=$(grep -m1 '"name"' "$manifest"    | sed 's/.*"\(.*\)".*/\1/')
  installdir=$(grep -m1 '"installdir"' "$manifest" | sed 's/.*"\(.*\)".*/\1/')

  [[ -n "$appid" ]] || continue
  [[ -n "$name"  ]] || name="AppID_${appid}"

  # Sanitize name for filename
  slug="$(echo "$name" | tr ' ' '_' | tr -dc '[:alnum:]_\-')"

  sh_file="${roms}/${appid}_${slug}.sh"

  # Only create launcher if it doesn't exist
  if [[ ! -f "$sh_file" ]]; then
    echo "Creating launcher for: $name (AppID: $appid)"
    NEW_LAUNCHER_CREATED=true

    # Write launcher script
    cat > "$sh_file" <<LAUNCHER
#!/bin/bash
ulimit -H -n 819200 && ulimit -S -n 819200
#------------------------------------------------
# Steam Game Launcher
# Game: ${name}
# AppID: ${appid}

APPID="${appid}"
STEAM_DIR="/userdata/system/add-ons/steam"
STEAM_LAUNCHER="\${STEAM_DIR}/steam"

cd "\$STEAM_DIR" || exit 1

# Launch game via Steam
"\$STEAM_LAUNCHER" fim-exec steam -gamepadui -silent -applaunch "\$APPID" &
STEAM_PID=\$!

# Wait for the game process to finish
wait \$STEAM_PID

# Kill all remaining Steam processes when game closes
pkill -f steam 2>/dev/null || true
pkill -f steamwebhelper 2>/dev/null || true
#------------------------------------------------
LAUNCHER
    chmod +x "$sh_file"

    # Create padtokey profile for this launcher (hotkey+start to kill steam)
    keys_file="${sh_file}.keys"
    cat > "$keys_file" <<'KEYS'
{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "exec",
            "target": "pkill -f steam",
            "description": "Kill Steam"
        }
    ]
}
KEYS
    echo "  ✓ Created padtokey profile"

    # Image path (you can later drop images with this name here)
    img_file="${images}/${appid}_${slug}.jpg"

    # Download Steam header image if it doesn't exist
    if [[ ! -f "$img_file" ]]; then
      echo "Downloading image for: $name (AppID: $appid)"
      if curl -s -f "https://cdn.cloudflare.steamstatic.com/steam/apps/${appid}/header.jpg" -o "$img_file"; then
        echo "  ✓ Image downloaded successfully"
      else
        echo "  ✗ Image not available"
        rm -f "$img_file"
        # Fallback to placeholder if available
        if [[ -n "$PLACEHOLDER_IMAGE" ]] && [[ -f "$PLACEHOLDER_IMAGE" ]]; then
          cp "$PLACEHOLDER_IMAGE" "$img_file"
        fi
      fi
    fi

    # Check if XML entry already exists for this launcher
    if ! grep -q "<path>./$(basename "$sh_file")</path>" "$GAMELIST_PATH"; then
      # Add XML entry for new launcher (insert before closing </gameList>)
      # Remove closing tag temporarily
      sed -i '/<\/gameList>/d' "$GAMELIST_PATH"

      # Append new game entry
      echo "  <game>" >> "$GAMELIST_PATH"
      echo "    <path>./$(basename "$sh_file")</path>" >> "$GAMELIST_PATH"
      echo "    <name>${name}</name>" >> "$GAMELIST_PATH"

      if [[ -f "$img_file" ]]; then
        echo "    <image>./images/$(basename "$img_file")</image>" >> "$GAMELIST_PATH"
      fi

      echo "    <rating>0</rating>" >> "$GAMELIST_PATH"
      echo "    <releasedate>19700101T010000</releasedate>" >> "$GAMELIST_PATH"
      echo "    <lang>en</lang>" >> "$GAMELIST_PATH"
      echo "  </game>" >> "$GAMELIST_PATH"

      # Add closing tag back
      echo '</gameList>' >> "$GAMELIST_PATH"

      echo "  ✓ Added to gamelist.xml"
    else
      echo "  ✓ Entry already exists in gamelist.xml"
    fi
  fi

done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan complete. Sleeping for ${LOOP_DELAY} seconds..."
sleep "$LOOP_DELAY"

done

