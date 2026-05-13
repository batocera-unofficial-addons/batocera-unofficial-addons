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
STEAM_APPS="/userdata/system/add-ons/steam/.local/share/Steam/steamapps"
STEAM_USERDATA="/userdata/system/add-ons/steam/.local/share/Steam/userdata"

# SteamGridDB API key file (optional — enables name/art lookup for non-Steam games)
# Get a free key at: https://www.steamgriddb.com/profile/preferences/api
SGDB_KEY_FILE="/userdata/system/add-ons/steam/steamgriddb.key"
SGDB_API_KEY=""
if [[ -f "$SGDB_KEY_FILE" ]]; then
  SGDB_API_KEY="$(cat "$SGDB_KEY_FILE" | tr -d '[:space:]')"
fi

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
export DISPLAY=:0.0
export RIM_ALLOW_ROOT=1
export HOME=/userdata/system/add-ons/steam

# Auto-detect dedicated GPU on multi-GPU systems (no-op on single-GPU)
GPU_COUNT=\$(ls -d /sys/class/drm/card[0-9]* 2>/dev/null | wc -l)
if [ "\$GPU_COUNT" -gt 1 ]; then
  boot_vram=0
  for card in /sys/class/drm/card[0-9]*/; do
    if [ "\$(cat "\${card}device/boot_vga" 2>/dev/null)" = "1" ]; then
      boot_vram=\$(cat "\${card}device/mem_info_vram_total" 2>/dev/null || echo 0)
      break
    fi
  done
  for card in /sys/class/drm/card[0-9]*/; do
    if [ "\$(cat "\${card}device/boot_vga" 2>/dev/null)" = "0" ]; then
      card_vram=\$(cat "\${card}device/mem_info_vram_total" 2>/dev/null || echo 0)
      if [ "\$card_vram" -gt "\$boot_vram" ]; then
        pci_raw=\$(grep PCI_SLOT_NAME "\${card}device/uevent" 2>/dev/null | cut -d= -f2)
        if [ -n "\$pci_raw" ]; then
          export DRI_PRIME="pci-\$(echo "\$pci_raw" | tr ':.' '__')"
          break
        fi
      fi
    fi
  done
fi

# Nvidia Vulkan ICD fix
_NV_ICD_SRC="/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json"
_NV_LAYERS_SRC="/usr/share/vulkan/implicit_layer.d/nvidia_production_layers.json"
_NV_EGL_SRC="/usr/share/glvnd/egl_vendor.d/10_nvidia_production.json"
_NV_DRV_DIR="\${HOME}/.local/share/runimage_nvidia"
if [ -f "\$_NV_ICD_SRC" ]; then
    cp -f "\$_NV_ICD_SRC" /etc/nvidia_icd.json 2>/dev/null || true
    [ -f "\$_NV_LAYERS_SRC" ] && cp -f "\$_NV_LAYERS_SRC" /etc/nvidia_layers.json 2>/dev/null || true
    [ -f "\$_NV_EGL_SRC" ] && cp -f "\$_NV_EGL_SRC" /etc/10_nvidia.json 2>/dev/null || true
    _NV_ICD_FLAG="\$_NV_DRV_DIR/.nvidia_icd_fixed_v2"
    if [ ! -f "\$_NV_ICD_FLAG" ]; then
        rm -f "\$_NV_DRV_DIR"/*.nv.drv "\$_NV_DRV_DIR"/.nvidia_icd_fixed 2>/dev/null
        mkdir -p "\$_NV_DRV_DIR" && touch "\$_NV_ICD_FLAG"
    fi
fi
unset _NV_ICD_SRC _NV_LAYERS_SRC _NV_EGL_SRC _NV_DRV_DIR _NV_ICD_FLAG

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
# Non-Steam shortcuts (shortcuts.vdf)
########################

# Look up a game on SteamGridDB by name. Outputs: sgdb_game_id|canonical_name
sgdb_search() {
  local term="$1"
  local key="$2"
  local encoded
  encoded=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$term" 2>/dev/null) || return 1
  local resp
  resp=$(curl -sf -H "Authorization: Bearer $key" \
    "https://www.steamgriddb.com/api/v2/search/autocomplete/${encoded}" 2>/dev/null) || return 1
  python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    if d.get('success') and d['data']:
        g = d['data'][0]
        print(f\"{g['id']}|{g['name']}\")
except Exception:
    pass
" "$resp" 2>/dev/null
}

# Download a 460x215 grid image from SteamGridDB for a given game ID.
sgdb_get_image() {
  local game_id="$1"
  local key="$2"
  local out_file="$3"
  local resp
  resp=$(curl -sf -H "Authorization: Bearer $key" \
    "https://www.steamgriddb.com/api/v2/grids/game/${game_id}?dimensions=460x215&limit=1" 2>/dev/null) || return 1
  local url
  url=$(python3 -c "
import json, sys
try:
    d = json.loads(sys.argv[1])
    if d.get('success') and d['data']:
        print(d['data'][0]['url'])
except Exception:
    pass
" "$resp" 2>/dev/null)
  [[ -n "$url" ]] || return 1
  curl -sf -L "$url" -o "$out_file" 2>/dev/null
}

########################
# Proton detection (for direct launch)
########################
detect_proton() {
  [ -x "$STEAM_APPS/common/Proton 10.0/proton" ] && echo "Proton 10.0" && return
  [ -x "$STEAM_APPS/common/Proton 9.0/proton" ]  && echo "Proton 9.0"  && return
  [ -x "$STEAM_APPS/common/Proton - Experimental/proton" ] && echo "Proton - Experimental" && return
  local best="" best_ver=0
  for p in "$STEAM_APPS"/common/Proton*/proton; do
    [ -x "$p" ] || continue
    local dir ver int_ver
    dir="$(basename "$(dirname "$p")")"
    ver="$(echo "$dir" | grep -oP '[\d.]+')"
    if [ -n "$ver" ]; then
      int_ver=$(echo "$ver" | awk -F. '{ printf "%d%03d", $1, $2 }')
      if [ "$int_ver" -gt "$best_ver" ]; then
        best_ver=$int_ver
        best="$dir"
      fi
    fi
  done
  [ -z "$best" ] && best="Proton - Experimental"
  echo "$best"
}

proton_name="$(detect_proton)"
echo "  Using Proton: $proton_name"

# Parse all shortcuts.vdf files found under userdata
# Parser outputs: appid|appname|search_term|exe|startdir
while IFS='|' read -r appid appname search_term exe_path start_dir; do
  [[ -n "$appid" ]] || continue

  # Skip entirely if a launcher for this appid already exists
  existing=$(ls "${roms}/shortcut_${appid}_"*.sh 2>/dev/null | head -1)
  if [[ -n "$existing" ]]; then
    continue
  fi

  # Resolve display name and artwork via SteamGridDB if key is available
  display_name="$search_term"
  img_file=""

  if [[ -n "$SGDB_API_KEY" ]]; then
    echo "  Looking up on SteamGridDB: $search_term"
    sgdb_result=$(sgdb_search "$search_term" "$SGDB_API_KEY" 2>/dev/null || true)
    if [[ -n "$sgdb_result" ]]; then
      sgdb_id="${sgdb_result%%|*}"
      display_name="${sgdb_result#*|}"
      echo "  ✓ Found: $display_name (SGDB ID: $sgdb_id)"

      slug_img="$(echo "$display_name" | tr ' ' '_' | tr -dc '[:alnum:]_\-')"
      candidate="${images}/${appid}_${slug_img}.jpg"
      if [[ ! -f "$candidate" ]]; then
        if sgdb_get_image "$sgdb_id" "$SGDB_API_KEY" "$candidate" 2>/dev/null; then
          echo "  ✓ Artwork downloaded"
          img_file="$candidate"
        else
          echo "  ✗ No artwork available"
        fi
      else
        img_file="$candidate"
      fi
    else
      echo "  ✗ Not found on SteamGridDB, using: $display_name"
    fi
  else
    [[ -n "$search_term" ]] || display_name="${appname:-Shortcut_${appid}}"
  fi

  slug="$(echo "$display_name" | tr ' ' '_' | tr -dc '[:alnum:]_\-')"
  sh_file="${roms}/shortcut_${appid}_${slug}.sh"

  if [[ ! -f "$sh_file" ]]; then
    echo "Creating non-Steam launcher for: $display_name (AppID: $appid)"
    NEW_LAUNCHER_CREATED=true

    # Paths in shortcuts.vdf use /root/ because Steam runs with HOME=/userdata/system/add-ons/steam
    # but the actual filesystem path is /userdata/system/add-ons/steam/
    ns_steam_home="/userdata/system/add-ons/steam"
    resolved_exe="${exe_path/#\/root\//$ns_steam_home/}"
    resolved_start="${start_dir/#\/root\//$ns_steam_home/}"
    # Determine working directory: prefer StartDir, fall back to exe directory
    local_start_dir="${resolved_start}"
    [[ -z "$local_start_dir" && -n "$resolved_exe" ]] && local_start_dir="$(dirname "$resolved_exe")"

    cat > "$sh_file" <<LAUNCHER
#!/bin/bash
export DISPLAY=:0.0
export RIM_ALLOW_ROOT=1
export HOME=/userdata/system/add-ons/steam

# Auto-detect dedicated GPU on multi-GPU systems (no-op on single-GPU)
GPU_COUNT=\$(ls -d /sys/class/drm/card[0-9]* 2>/dev/null | wc -l)
if [ "\$GPU_COUNT" -gt 1 ]; then
  boot_vram=0
  for card in /sys/class/drm/card[0-9]*/; do
    if [ "\$(cat "\${card}device/boot_vga" 2>/dev/null)" = "1" ]; then
      boot_vram=\$(cat "\${card}device/mem_info_vram_total" 2>/dev/null || echo 0)
      break
    fi
  done
  for card in /sys/class/drm/card[0-9]*/; do
    if [ "\$(cat "\${card}device/boot_vga" 2>/dev/null)" = "0" ]; then
      card_vram=\$(cat "\${card}device/mem_info_vram_total" 2>/dev/null || echo 0)
      if [ "\$card_vram" -gt "\$boot_vram" ]; then
        pci_raw=\$(grep PCI_SLOT_NAME "\${card}device/uevent" 2>/dev/null | cut -d= -f2)
        if [ -n "\$pci_raw" ]; then
          export DRI_PRIME="pci-\$(echo "\$pci_raw" | tr ':.' '__')"
          break
        fi
      fi
    fi
  done
fi

# Nvidia Vulkan ICD fix
_NV_ICD_SRC="/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json"
_NV_LAYERS_SRC="/usr/share/vulkan/implicit_layer.d/nvidia_production_layers.json"
_NV_EGL_SRC="/usr/share/glvnd/egl_vendor.d/10_nvidia_production.json"
_NV_DRV_DIR="\${HOME}/.local/share/runimage_nvidia"
if [ -f "\$_NV_ICD_SRC" ]; then
    cp -f "\$_NV_ICD_SRC" /etc/nvidia_icd.json 2>/dev/null || true
    [ -f "\$_NV_LAYERS_SRC" ] && cp -f "\$_NV_LAYERS_SRC" /etc/nvidia_layers.json 2>/dev/null || true
    [ -f "\$_NV_EGL_SRC" ] && cp -f "\$_NV_EGL_SRC" /etc/10_nvidia.json 2>/dev/null || true
    _NV_ICD_FLAG="\$_NV_DRV_DIR/.nvidia_icd_fixed_v2"
    if [ ! -f "\$_NV_ICD_FLAG" ]; then
        rm -f "\$_NV_DRV_DIR"/*.nv.drv "\$_NV_DRV_DIR"/.nvidia_icd_fixed 2>/dev/null
        mkdir -p "\$_NV_DRV_DIR" && touch "\$_NV_ICD_FLAG"
    fi
fi
unset _NV_ICD_SRC _NV_LAYERS_SRC _NV_EGL_SRC _NV_DRV_DIR _NV_ICD_FLAG

ulimit -H -n 819200 && ulimit -S -n 819200
#------------------------------------------------
# Non-Steam Game Launcher (Proton Direct)
# Game: ${display_name}
# AppID: ${appid}

STEAM_DIR="/userdata/system/add-ons/steam"
STEAM_APPS="\${STEAM_DIR}/.local/share/Steam/steamapps"
COMPAT_DATA="\${STEAM_APPS}/compatdata/${appid}"

export STEAM_COMPAT_DATA_PATH="\$COMPAT_DATA"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\${STEAM_DIR}/.local/share/Steam"
export STEAM_COMPAT_APP_ID="${appid}"

# Steam Deck controller: allow detection
unset SDL_GAMECONTROLLER_IGNORE_DEVICES
export SDL_GAMECONTROLLERCONFIG="03000000de2800000512000011010000,Steam Deck Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b10,leftshoulder:b4,leftstick:b8,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b9,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux"

PROTON_PATH="\${STEAM_APPS}/common/${proton_name}/proton"

# Init Wine prefix if not already set up
if [ ! -d "\$COMPAT_DATA/pfx" ]; then
  mkdir -p "\$COMPAT_DATA"
  "\$PROTON_PATH" run wineboot -u
fi

cd "${local_start_dir}" || exit 1
"\$PROTON_PATH" run "${resolved_exe}" &
PID=\$!
wait \$PID

pkill -f proton 2>/dev/null || true
pkill -f steam 2>/dev/null || true
pkill -f steamwebhelper 2>/dev/null || true
#------------------------------------------------
LAUNCHER
    chmod +x "$sh_file"

    keys_file="${sh_file}.keys"
    cat > "$keys_file" <<'KEYS'
{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "exec",
            "target": "pkill -f proton",
            "description": "Kill game (Proton)"
        }
    ]
}
KEYS
    echo "  ✓ Created padtokey profile"

    if ! grep -q "<path>./$(basename "$sh_file")</path>" "$GAMELIST_PATH"; then
      sed -i '/<\/gameList>/d' "$GAMELIST_PATH"
      echo "  <game>" >> "$GAMELIST_PATH"
      echo "    <path>./$(basename "$sh_file")</path>" >> "$GAMELIST_PATH"
      echo "    <name>${display_name}</name>" >> "$GAMELIST_PATH"
      if [[ -n "$img_file" ]] && [[ -f "$img_file" ]]; then
        echo "    <image>./images/$(basename "$img_file")</image>" >> "$GAMELIST_PATH"
      fi
      echo "    <rating>0</rating>" >> "$GAMELIST_PATH"
      echo "    <releasedate>19700101T010000</releasedate>" >> "$GAMELIST_PATH"
      echo "    <lang>en</lang>" >> "$GAMELIST_PATH"
      echo "  </game>" >> "$GAMELIST_PATH"
      echo '</gameList>' >> "$GAMELIST_PATH"
      echo "  ✓ Added to gamelist.xml"
    else
      echo "  ✓ Entry already exists in gamelist.xml"
    fi
  fi

done < <(
  find "$STEAM_USERDATA" -name 'shortcuts.vdf' 2>/dev/null | while read -r vdf; do
    python3 - "$vdf" <<'PYEOF'
import struct, sys, os

def read_cstr(data, i):
    end = data.index(b'\x00', i)
    return data[i:end].decode('utf-8', errors='replace'), end + 1

def parse_obj(data, i):
    fields = {}
    while i < len(data):
        if data[i] == 8:
            i += 1
            break
        typ = data[i]
        i += 1
        key, i = read_cstr(data, i)
        if typ == 0:
            val, i = parse_obj(data, i)
        elif typ == 1:
            val, i = read_cstr(data, i)
        elif typ == 2:
            val = struct.unpack_from('<i', data, i)[0]
            i += 4
        else:
            break
        fields[key] = val
    return fields, i

data = open(sys.argv[1], 'rb').read()
i = 1
_, i = read_cstr(data, i)
entries, _ = parse_obj(data, i)

for entry in entries.values():
    if not isinstance(entry, dict):
        continue
    appid    = entry.get('appid')
    appname  = entry.get('AppName', '').strip()
    startdir = entry.get('StartDir', '').strip().strip('"')
    if appid is None:
        continue
    if appid < 0:
        appid += 2**32
    # Derive search term: last non-empty component of StartDir, fall back to AppName
    search_term = os.path.basename(startdir.rstrip('/\\')) or appname
    exe     = entry.get('Exe', '').strip().strip('"')
    startdir = entry.get('StartDir', '').strip().strip('"')
    print(f"{appid}|{appname}|{search_term}|{exe}|{startdir}")
PYEOF
  done
)

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan complete. Sleeping for ${LOOP_DELAY} seconds..."
sleep "$LOOP_DELAY"

done

