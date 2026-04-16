#!/bin/bash
#
# Add Non-Steam Games to EmulationStation
# Scans non-steam-games/ for .exe files, generates Proton direct launchers,
# and updates gamelist.xml so games appear in ES > Steam.
#

STEAM_DIR="/userdata/system/add-ons/steam"
STEAM_APPS="${STEAM_DIR}/.local/share/Steam/steamapps"
GAMES_DIR="${STEAM_DIR}/non-steam-games"
DIALOG_TITLE="Add Non-Steam Games"

# yad needs X; ensure we can connect (no terminal required)
export DISPLAY="${DISPLAY:-:0.0}"
export HOME="${HOME:-/root}"

if [ -d "/userdata/.roms_base" ]; then
  ROMS_ROOT="/userdata/.roms_base"
else
  ROMS_ROOT="/userdata/roms"
fi
ROMS_DIR="${ROMS_ROOT}/steam"
IMAGES_DIR="${ROMS_DIR}/images"
GAMELIST="${ROMS_DIR}/gamelist.xml"

mkdir -p "$GAMES_DIR" "$ROMS_DIR" "$IMAGES_DIR"

###############################################################################
# Proton auto-detection: prefer Proton 10/9 (better controller support), else Experimental, else newest
###############################################################################
detect_proton() {
  [ -x "$STEAM_APPS/common/Proton 10.0/proton" ] && echo "Proton 10.0" && return
  [ -x "$STEAM_APPS/common/Proton 9.0/proton" ] && echo "Proton 9.0" && return
  [ -x "$STEAM_APPS/common/Proton - Experimental/proton" ] && echo "Proton - Experimental" && return
  local best="" best_ver=0
  for p in "$STEAM_APPS"/common/Proton*/proton; do
    [ -x "$p" ] || continue
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

###############################################################################
# CRC32 shortcut ID (matches Steam's non-Steam ID range)
###############################################################################
generate_shortcut_id() {
  python3 -c "
import binascii, sys
crc = binascii.crc32(sys.argv[1].encode()) & 0xFFFFFFFF
print(crc | 0x80000000)
" "$1"
}

###############################################################################
# Ensure gamelist.xml exists
###############################################################################
ensure_gamelist() {
  if [ ! -f "$GAMELIST" ]; then
    cat > "$GAMELIST" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<gameList>
</gameList>
XML
  fi
}

###############################################################################
# Scan for new games (returns game_name|exe1|exe2|... for each folder)
###############################################################################
scan_games() {
  local games=()
  for game_dir in "$GAMES_DIR"/*/; do
    [ -d "$game_dir" ] || continue
    local exes=()
    while IFS= read -r exe; do
      [ -n "$exe" ] && exes+=("$exe")
    done < <(find "$game_dir" -maxdepth 1 -iname '*.exe' 2>/dev/null | sort)
    [ ${#exes[@]} -eq 0 ] && continue

    local game_name
    game_name="$(basename "$game_dir")"
    local slug
    slug="$(echo "$game_name" | tr ' ' '_' | tr -dc '[:alnum:]_-' | head -c 80)"
    # Skip if launcher already exists for any exe in this folder
    local skip=0 shortcut_id
    for exe in "${exes[@]}"; do
      shortcut_id="$(generate_shortcut_id "$exe")"
      [ -f "${ROMS_DIR}/${shortcut_id}_${slug}.sh" ] && skip=1 && break
    done
    [ "$skip" -eq 1 ] && continue

    games+=("${game_name}|$(IFS='|'; echo "${exes[*]}")")
  done
  printf '%s\n' "${games[@]}"
}

###############################################################################
# Pick exe: auto-pick using heuristic (no radiolist — evmapy/focus unreliable from ES)
# Excludes utility exes (KeyConfig, Setup, Launcher, etc.), prefers main game exe.
###############################################################################
pick_exe() {
  local exes=("$@")
  if [ ${#exes[@]} -eq 1 ]; then
    echo "${exes[0]}"
    return
  fi
  # Exclude common utility exes (case-insensitive)
  local utility_patterns="keyconfig|^config$|setup|uninstall|^install$|vcredist|dxsetup|unins[0-9]+|msiexec|regsvr|^launcher$"
  local candidates=()
  for exe in "${exes[@]}"; do
    local base
    base="$(basename "$exe" .exe | tr '[:upper:]' '[:lower:]')"
    echo "$base" | grep -qE "$utility_patterns" && continue
    candidates+=("$exe")
  done
  [ ${#candidates[@]} -eq 0 ] && candidates=("${exes[@]}")
  # Use first candidate (no interactive picker — avoids focus/evmapy issues)
  echo "${candidates[0]}"
}

###############################################################################
# Create launcher for one game
###############################################################################
create_launcher() {
  local game_name="$1" exe_path="$2" shortcut_id="$3" slug="$4" proton_name="$5"
  local sh_file="${ROMS_DIR}/${shortcut_id}_${slug}.sh"
  local start_dir
  start_dir="$(dirname "$exe_path")"
  local exe_basename
  exe_basename="$(basename "$exe_path")"

  cat > "$sh_file" <<LAUNCHER
#!/bin/bash
export DISPLAY=:0.0
export RIM_ALLOW_ROOT=1
export HOME=${STEAM_DIR}
ulimit -H -n 819200 && ulimit -S -n 819200

# Steam Deck controller: allow detection (Steam blacklists 28de:1205 via SDL_GAMECONTROLLER_IGNORE_DEVICES)
unset SDL_GAMECONTROLLER_IGNORE_DEVICES
# SDL mapping for Proton/Wine (no Steam Input)
export SDL_GAMECONTROLLERCONFIG="03000000de2800000512000011010000,Steam Deck Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,guide:b10,leftshoulder:b4,leftstick:b8,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b9,righttrigger:a5,rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux"

STEAM_DIR="${STEAM_DIR}"
STEAM_APPS="\${STEAM_DIR}/.local/share/Steam/steamapps"
COMPAT_DATA="\${STEAM_APPS}/compatdata/${shortcut_id}"
export STEAM_COMPAT_DATA_PATH="\$COMPAT_DATA"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="\${STEAM_DIR}/.local/share/Steam"
export STEAM_COMPAT_APP_ID=${shortcut_id}
PROTON_PATH="\${STEAM_APPS}/common/${proton_name}/proton"

if [ ! -d "\$COMPAT_DATA/pfx" ]; then
  mkdir -p "\$COMPAT_DATA"
  "\$PROTON_PATH" run wineboot -u
fi

cd "${start_dir}" || exit 1
"\$PROTON_PATH" run "${exe_path}" &
PID=\$!
wait \$PID

pkill -f proton 2>/dev/null || true
pkill -f steam 2>/dev/null || true
pkill -f steamwebhelper 2>/dev/null || true
LAUNCHER
  chmod +x "$sh_file"

  cat > "${sh_file}.keys" <<'KEYS'
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
}

###############################################################################
# Add gamelist.xml entry
###############################################################################
add_gamelist_entry() {
  local game_name="$1" shortcut_id="$2" slug="$3"
  local sh_basename="${shortcut_id}_${slug}.sh"

  grep -q "<path>./${sh_basename}</path>" "$GAMELIST" 2>/dev/null && return

  sed -i '/<\/gameList>/d' "$GAMELIST"
  cat >> "$GAMELIST" <<ENTRY
  <game>
    <path>./${sh_basename}</path>
    <name>${game_name}</name>
    <genre>Non-Steam</genre>
    <lang>en</lang>
  </game>
</gameList>
ENTRY
}

###############################################################################
# yad helpers (GTK dialogs, no terminal needed — works when launched from ES)
###############################################################################
# Info dialogs: --no-buttons + timeout = auto-close; --timeout-indicator shows countdown
yad_info() {
  yad --info --title "$DIALOG_TITLE" --text "$1" --timeout="${2:-3}" --no-wrap --no-buttons --timeout-indicator=bottom 2>/dev/null || true
}
###############################################################################
# Main
###############################################################################

# Static "Scanning..." (no progress bar) — avoids 0% stuck display
yad --info --title "$DIALOG_TITLE" --text "Scanning for games in:\n$GAMES_DIR\n\nPlease wait..." --no-wrap --no-buttons 2>/dev/null &
YAD_PID=$!
mapfile -t game_list < <(scan_games)
total=${#game_list[@]}
kill "$YAD_PID" 2>/dev/null || true

if [ "$total" -eq 0 ]; then
  yad_info "No new games found.\n\nTo add games:\n\n1. Create a folder for each game in:\n   $GAMES_DIR\n\n2. Place the .exe and game files inside\n\n3. Run this app again" 8
  exit 0
fi

game_names=()
for entry in "${game_list[@]}"; do
  IFS='|' read -r name _ <<< "$entry"
  game_names+=("$name")
done

# Resolve exe for each game (pick if multiple; yad radiolist when >1 exe)
resolved_list=()
for entry in "${game_list[@]}"; do
  IFS='|' read -r name rest <<< "$entry"
  exes=()
  IFS='|' read -ra exes_arr <<< "$rest"
  for exe in "${exes_arr[@]}"; do
    [ -n "$exe" ] && exes+=("$exe")
  done
  exe_path="$(pick_exe "$name" "${exes[@]}")"
  [ -z "$exe_path" ] || resolved_list+=("${name}|${exe_path}|$(generate_shortcut_id "$exe_path")|$(echo "$name" | tr ' ' '_' | tr -dc '[:alnum:]_-' | head -c 80)")
done

total=${#resolved_list[@]}
[ "$total" -eq 0 ] && yad_info "No games selected." 3 && exit 0

proton_name="$(detect_proton)"
ensure_gamelist

# Static "Processing..." (no progress bar) — avoids stuck 0% when launched from ES
yad --info --title "$DIALOG_TITLE" --text "Processing $total game(s)...\n\nSetting up launchers..." --no-wrap --no-buttons 2>/dev/null &
YAD_PID=$!
results=()
for entry in "${resolved_list[@]}"; do
  IFS='|' read -r name exe_path shortcut_id slug <<< "$entry"
  create_launcher "$name" "$exe_path" "$shortcut_id" "$slug" "$proton_name"
  add_gamelist_entry "$name" "$shortcut_id" "$slug"
  results+=("$name")
done
kill "$YAD_PID" 2>/dev/null || true

done_text="Successfully added $total game(s):\n\n"
for name in "${results[@]}"; do
  done_text+="  ✓ $name\n"
done
done_text+="\nYour game list has been updated.\nNew games are now available in the Steam section."

yad_info "$done_text" 5

# Reload ES in background with timeout — don't block script exit
(curl -s --connect-timeout 2 --max-time 5 http://127.0.0.1:1234/reloadgames >/dev/null 2>&1 &)

exit 0
