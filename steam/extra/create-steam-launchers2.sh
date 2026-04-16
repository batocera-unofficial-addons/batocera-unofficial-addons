#!/bin/bash
set -e

########################
# CONFIG
########################

# Pin Steam files to internal drive when mergerfs .roms_base exists
if [ -d "/userdata/.roms_base" ]; then
  ROMS_ROOT="/userdata/.roms_base"
else
  ROMS_ROOT="/userdata/roms"
fi
roms="${ROMS_ROOT}/steam"
images="${roms}/images"
GAMELIST_PATH="$roms/gamelist.xml"

# Where Steam lives
STEAM_DIR="/userdata/system/add-ons/steam"
STEAM_APPS="${STEAM_DIR}/.local/share/Steam/steamapps"
PROTON_NAME="Proton - Experimental"

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
export RIM_ALLOW_ROOT=1
export HOME=/userdata/system/add-ons/steam
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
"\$STEAM_LAUNCHER" -gamepadui -silent -applaunch "\$APPID" &
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
      if curl -s -L -f "https://cdn.cloudflare.steamstatic.com/steam/apps/${appid}/header.jpg" -o "$img_file"; then
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

########################
# Non-Steam games (shortcuts.vdf) — Proton direct launch
########################

STEAM_USERDATA="${STEAM_APPS%/steamapps}/userdata"
for shortcuts_vdf in "$STEAM_USERDATA"/*/config/shortcuts.vdf; do
  [[ -f "$shortcuts_vdf" ]] || continue

  # Parse shortcuts (Python script inline)
  while IFS='|' read -r shortcutid name exe startdir; do
    [[ -n "$shortcutid" ]] || continue
    [[ -f "$exe" ]] || continue

    slug="$(echo "$name" | tr ' ' '_' | tr -dc '[:alnum:]_\-' | head -c 80)"
    [[ -n "$slug" ]] || slug="NonSteam_${shortcutid}"
    sh_file="${roms}/${shortcutid}_${slug}.sh"

    if [[ ! -f "$sh_file" ]]; then
      echo "Creating non-Steam launcher for: $name (ShortcutID: $shortcutid)"
      NEW_LAUNCHER_CREATED=true

      cat > "$sh_file" <<NONSTEAM
#!/bin/bash
export DISPLAY=:0.0
export RIM_ALLOW_ROOT=1
export HOME=${STEAM_DIR}
ulimit -H -n 819200 && ulimit -S -n 819200
# Steam Deck controller: allow detection (Steam blacklists 28de:1205 via SDL_GAMECONTROLLER_IGNORE_DEVICES)
unset SDL_GAMECONTROLLER_IGNORE_DEVICES
# SDL mapping for Proton/Wine (no Steam Input)
export SDL_GAMECONTROLLERCONFIG="03000000de2800000512000011010000,Steam Deck Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b10,leftshoulder:b4,leftstick:b8,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b9,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux"
#------------------------------------------------
# Non-Steam Game Launcher (Proton direct)
# Game: ${name}
# ShortcutID: ${shortcutid}

STEAM_DIR="${STEAM_DIR}"
STEAM_APPS="\${STEAM_DIR}/.local/share/Steam/steamapps"
COMPAT_DATA="\${STEAM_APPS}/compatdata/${shortcutid}"
STEAM_COMPAT_CLIENT_INSTALL_PATH="\${STEAM_DIR}/.local/share/Steam"
PROTON_PATH="\${STEAM_APPS}/common/${PROTON_NAME}/proton"
EXE_PATH="${exe}"
START_DIR="${startdir}"

cd "\$STEAM_DIR" || exit 1

export STEAM_COMPAT_DATA_PATH="\$COMPAT_DATA"
export STEAM_COMPAT_CLIENT_INSTALL_PATH
export STEAM_COMPAT_APP_ID=${shortcutid}

cd "\$START_DIR" || exit 1
"\$PROTON_PATH" run "\$EXE_PATH" &
PROTON_PID=\$!

wait \$PROTON_PID

pkill -f steam 2>/dev/null || true
pkill -f steamwebhelper 2>/dev/null || true
#------------------------------------------------
NONSTEAM
      chmod +x "$sh_file"

      keys_file="${sh_file}.keys"
      cat > "$keys_file" <<'KEYS'
{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "exec",
            "target": "/userdata/system/add-ons/steam/extra/force-exit-non-steam-game.sh",
            "description": "Exit game, release input, restart ES"
        }
    ]
}
KEYS

      img_file="${images}/${shortcutid}_${slug}.jpg"
      if [[ ! -f "$img_file" ]]; then
        if [[ -n "$PLACEHOLDER_IMAGE" ]] && [[ -f "$PLACEHOLDER_IMAGE" ]]; then
          cp "$PLACEHOLDER_IMAGE" "$img_file"
        fi
      fi

      if ! grep -q "<path>./$(basename "$sh_file")</path>" "$GAMELIST_PATH"; then
        sed -i '/<\/gameList>/d' "$GAMELIST_PATH"
        echo "  <game>" >> "$GAMELIST_PATH"
        echo "    <path>./$(basename "$sh_file")</path>" >> "$GAMELIST_PATH"
        echo "    <name>${name}</name>" >> "$GAMELIST_PATH"
        [[ -f "$img_file" ]] && echo "    <image>./images/$(basename "$img_file")</image>" >> "$GAMELIST_PATH"
        echo "    <rating>0</rating>" >> "$GAMELIST_PATH"
        echo "    <releasedate>19700101T010000</releasedate>" >> "$GAMELIST_PATH"
        echo "    <lang>en</lang>" >> "$GAMELIST_PATH"
        echo "  </game>" >> "$GAMELIST_PATH"
        echo '</gameList>' >> "$GAMELIST_PATH"
      fi
    fi
  done < <(python3 - "$shortcuts_vdf" "$STEAM_DIR" <<'PYPARSE'
import sys, struct
path, steam_home = sys.argv[1], sys.argv[2]
try:
    data = open(path, 'rb').read()
except OSError:
    sys.exit(0)
marker = b'\x02appid\x00'
pos = 0
while True:
    idx = data.find(marker, pos)
    if idx < 0: break
    val_pos = idx + len(marker)
    if val_pos + 4 > len(data): break
    appid, = struct.unpack_from('<I', data, val_pos)
    pos = val_pos + 4
    aname_idx = data.find(b'\x01AppName\x00', val_pos)
    name = "Unknown"
    if 0 <= aname_idx <= val_pos + 200:
        s_start, s_end = aname_idx + 9, data.find(b'\x00', aname_idx + 9)
        name = data[s_start:s_end].decode('utf-8', errors='replace') if s_end >= 0 else "Unknown"
    exe_idx = data.find(b'\x01Exe\x00', val_pos)
    if exe_idx < 0 or exe_idx > val_pos + 300: continue
    exe_start, exe_end = exe_idx + 5, data.find(b'\x00', exe_idx + 5)
    exe = data[exe_start:exe_end].decode('utf-8', errors='replace').strip('"') if exe_end >= 0 else ""
    sdir_idx = data.find(b'StartDir\x00', val_pos)
    start = ""
    if 0 <= sdir_idx <= val_pos + 400:
        s_start, s_end = sdir_idx + 9, data.find(b'\x00', sdir_idx + 9)
        start = data[s_start:s_end].decode('utf-8', errors='replace') if s_end >= 0 else ""
    if exe:
        if exe.startswith('/root/'): exe = steam_home + exe[5:]
        if start.startswith('/root/'): start = steam_home + start[5:]
        print(f"{appid}|{name}|{exe}|{start}")
PYPARSE
)
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan complete. Sleeping for ${LOOP_DELAY} seconds..."
sleep "$LOOP_DELAY"

done

