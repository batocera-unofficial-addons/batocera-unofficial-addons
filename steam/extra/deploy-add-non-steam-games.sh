#!/bin/bash
# Deploy Add Non-Steam Games to remote Batocera (no BUA Steam reinstall)
# Run from Mac: ./deploy-add-non-steam-games.sh

set -e
HOST="${1:-batocera.local}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Deploying Add Non-Steam Games to $HOST..."

# 1. Copy files via scp (you'll be prompted for password)
scp -o StrictHostKeyChecking=no \
  "$SCRIPT_DIR/add-non-steam-game.py" \
  "$SCRIPT_DIR/force-exit-non-steam-game.sh" \
  "$SCRIPT_DIR/restore-steam-deck-controller.sh" \
  "$SCRIPT_DIR/Add_Non-Steam_Games.sh.keys" \
  "$SCRIPT_DIR/add-non-steam-games.jpg" \
  "$SCRIPT_DIR/add-non-steam-games-marquee.png" \
  "$SCRIPT_DIR/add-non-steam-games-thumb.png" \
  root@$HOST:/tmp/

# 2. Move and set up on remote
ssh -o StrictHostKeyChecking=no root@$HOST "
  mv /tmp/add-non-steam-game.py /userdata/system/add-ons/steam/extra/
  chmod +x /userdata/system/add-ons/steam/extra/add-non-steam-game.py
  mv /tmp/force-exit-non-steam-game.sh /userdata/system/add-ons/steam/extra/ 2>/dev/null || true
  chmod +x /userdata/system/add-ons/steam/extra/force-exit-non-steam-game.sh 2>/dev/null || true
  mv /tmp/restore-steam-deck-controller.sh /userdata/system/add-ons/steam/extra/ 2>/dev/null || true
  chmod +x /userdata/system/add-ons/steam/extra/restore-steam-deck-controller.sh 2>/dev/null || true

  mv /tmp/add-non-steam-games.jpg /tmp/add-non-steam-games-marquee.png /tmp/add-non-steam-games-thumb.png /userdata/roms/steam/images/
  if [ -s /tmp/Add_Non-Steam_Games.sh.keys ]; then
    cp /tmp/Add_Non-Steam_Games.sh.keys /userdata/.roms_base/steam/ 2>/dev/null || true
    cp /tmp/Add_Non-Steam_Games.sh.keys /userdata/roms/steam/ 2>/dev/null || true
  fi
  for KEYS_PATH in /userdata/.roms_base/steam/Add_Non-Steam_Games.sh.keys /userdata/roms/steam/Add_Non-Steam_Games.sh.keys; do
    if [ ! -s \"\$KEYS_PATH\" ] && [ -d \"\$(dirname \"\$KEYS_PATH\")\" ]; then
      cat <<'KEYS' > \"\$KEYS_PATH\"
{\"actions_player1\":[{\"trigger\":[\"hotkey\",\"start\"],\"type\":\"key\",\"target\":\"KEY_ENTER\",\"description\":\"Override steam exec\"},{\"trigger\":[\"hotkey\",\"select\"],\"type\":\"exec\",\"target\":\"pkill -9 -f add-non-steam-game\",\"description\":\"Exit\"},{\"trigger\":\"up\",\"type\":\"key\",\"target\":\"KEY_UP\"},{\"trigger\":\"down\",\"type\":\"key\",\"target\":\"KEY_DOWN\"},{\"trigger\":\"left\",\"type\":\"key\",\"target\":\"KEY_LEFT\"},{\"trigger\":\"right\",\"type\":\"key\",\"target\":\"KEY_RIGHT\"},{\"trigger\":\"start\",\"type\":\"key\",\"target\":\"KEY_ENTER\"},{\"trigger\":\"a\",\"type\":\"key\",\"target\":\"KEY_ENTER\"},{\"trigger\":\"select\",\"type\":\"key\",\"target\":\"KEY_ESC\"}]}
KEYS
    fi
  done

  cat <<'WRAPPER' > /userdata/roms/steam/Add_Non-Steam_Games.sh
#!/bin/bash
# Pygame UI — reads controller directly, no evmapy/focus issues
# Wayland: use XWayland (DISPLAY=:0 + SDL_VIDEODRIVER=x11); Hotkey+Start restores display if black
export HOME=/root
export DISPLAY=:0
export SDL_VIDEODRIVER=x11
if [ -n "${ADD_NON_STEAM_DEBUG}" ]; then
  exec python3 /userdata/system/add-ons/steam/extra/add-non-steam-game.py 2>/tmp/add-non-steam-game.log
fi
# Show loading dialog immediately (yad appears before pygame); 3s gives display time to settle
yad --info --title "Add Non-Steam Games" --text "Loading..." --no-buttons --timeout=3 2>/dev/null &
sleep 3
kill \$! 2>/dev/null || true
python3 /userdata/system/add-ons/steam/extra/add-non-steam-game.py
WRAPPER
  chmod +x /userdata/roms/steam/Add_Non-Steam_Games.sh

  mkdir -p /userdata/system/add-ons/steam/non-steam-games

  # Patch existing Non-Steam launchers: Proton 10 (better controller support)
  if [ -x /userdata/system/add-ons/steam/.local/share/Steam/steamapps/common/Proton\ 10.0/proton ]; then
    for roms in /userdata/roms/steam /userdata/.roms_base/steam; do
      [ -d \"\$roms\" ] || continue
      for f in \"\$roms\"/*_[0-9]*.sh; do
        [ -f \"\$f\" ] || continue
        grep -q 'Proton - Experimental' \"\$f\" || continue
        sed -i 's|Proton - Experimental|Proton 10.0|g' \"\$f\" 2>/dev/null && echo \"Proton 10: \$(basename \$f)\"
      done
    done
  fi

  # Patch existing Non-Steam launchers: allow Steam Deck controller (unset blacklist)
  for roms in /userdata/roms/steam /userdata/.roms_base/steam; do
    [ -d \"\$roms\" ] || continue
    for f in \"\$roms\"/*_[0-9]*.sh; do
      [ -f \"\$f\" ] || continue
      grep -q 'SDL_GAMECONTROLLERCONFIG' \"\$f\" || continue
      grep -q 'SDL_GAMECONTROLLER_IGNORE_DEVICES' \"\$f\" && continue
      sed -i '/export SDL_GAMECONTROLLERCONFIG=/i unset SDL_GAMECONTROLLER_IGNORE_DEVICES' \"\$f\" 2>/dev/null && echo \"Patched: \$(basename \$f)\"
    done
  done

  if ! grep -q 'Add_Non-Steam_Games.sh' /userdata/roms/steam/gamelist.xml 2>/dev/null; then
    xmlstarlet ed -s '/gameList' -t elem -n 'game' -v '' \
      -s '/gameList/game[last()]' -t elem -n 'path' -v './Add_Non-Steam_Games.sh' \
      -s '/gameList/game[last()]' -t elem -n 'name' -v 'Add Non-Steam Games' \
      -s '/gameList/game[last()]' -t elem -n 'desc' -v 'Scan for Windows games and add them to EmulationStation with Proton.' \
      -s '/gameList/game[last()]' -t elem -n 'image' -v './images/add-non-steam-games.jpg' \
      -s '/gameList/game[last()]' -t elem -n 'marquee' -v './images/add-non-steam-games-marquee.png' \
      -s '/gameList/game[last()]' -t elem -n 'thumbnail' -v './images/add-non-steam-games-thumb.png' \
      -s '/gameList/game[last()]' -t elem -n 'genre' -v 'Utilities' \
      -s '/gameList/game[last()]' -t elem -n 'lang' -v 'en' \
      /userdata/roms/steam/gamelist.xml > /tmp/gamelist.xml.tmp
    mv /tmp/gamelist.xml.tmp /userdata/roms/steam/gamelist.xml
  fi

  curl -s http://127.0.0.1:1234/reloadgames

  # Patch steam.keys so Hotkey+Start restores display (kill ES → restart fixes black screen)
  STEAM_KEYS=/userdata/system/configs/evmapy/steam.keys
  if [ -f \"\$STEAM_KEYS\" ]; then
    cp \"\$STEAM_KEYS\" \"\$STEAM_KEYS.bak\"
    sed -i 's|kill \\\$(pidof steam)|kill \\\$(pidof steam) 2>/dev/null; killall emulationstation|' \"\$STEAM_KEYS\"
    echo \"Patched steam.keys: Hotkey+Start now restores display\"
  fi
"

echo "Done. Add Non-Steam Games in ES > Steam. Hotkey+Start restores display when black."
