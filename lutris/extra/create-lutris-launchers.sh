#!/bin/bash

########################
# CONFIG
########################

roms="/userdata/roms/lutris"
images="/userdata/roms/lutris/images"
GAMELIST_PATH="$roms/gamelist.xml"

LUTRIS_HOME="/userdata/system/add-ons/lutris"
LUTRIS_DB="${LUTRIS_HOME}/.local/share/lutris/pga.db"
LUTRIS_BANNERS="${LUTRIS_HOME}/.local/share/lutris/banners"
LUTRIS_COVERART="${LUTRIS_HOME}/.local/share/lutris/coverart"

LOOP_DELAY=10

########################
# Setup
########################

mkdir -p "$roms" "$images"

echo "Lutris Launcher Generator - Starting continuous mode"
echo "Checking for new games every ${LOOP_DELAY} seconds..."

########################
# Main Loop
########################

while true; do

    # Wait for Lutris DB to exist (Lutris creates it on first launch)
    if [[ ! -f "$LUTRIS_DB" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for Lutris database..."
        sleep "$LOOP_DELAY"
        continue
    fi

    # Ensure gamelist exists with proper structure
    if [[ ! -f "$GAMELIST_PATH" ]]; then
        echo '<?xml version="1.0" encoding="UTF-8"?>' > "$GAMELIST_PATH"
        echo '<gameList>' >> "$GAMELIST_PATH"
        echo '</gameList>' >> "$GAMELIST_PATH"
    fi

    ########################
    # Query installed games
    ########################

    GAME_LIST=$(python3 -c "
import sys, sqlite3
con = sqlite3.connect('$LUTRIS_DB')
rows = con.execute(\"SELECT id, name, slug FROM games WHERE installed=1 ORDER BY name\").fetchall()
for r in rows: print('|'.join(str(x) if x else '' for x in r))
con.close()
" 2>/tmp/lutris_db_err)
    DB_EXIT=$?

    if [[ $DB_EXIT -ne 0 ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] DB read failed — skipping scan."
        sleep "$LOOP_DELAY"
        continue
    fi

    while IFS='|' read -r game_id game_name game_slug; do

        [[ -n "$game_id" ]] || continue
        [[ -n "$game_name" ]] || game_name="game_${game_id}"
        [[ -n "$game_slug" ]] || game_slug="game_${game_id}"

        sh_file="${roms}/${game_slug}.sh"

        # Only create launcher if it doesn't exist
        if [[ ! -f "$sh_file" ]]; then
            echo "Creating launcher: ${game_name} (ID: ${game_id})"

            cat > "$sh_file" <<LAUNCHER
#!/bin/bash
export DISPLAY=:0.0
export XAUTHORITY=/var/run/xauth
export RIM_ALLOW_ROOT=1
export HOME=/userdata/system/add-ons/lutris

# Auto-detect dedicated GPU
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

# Nvidia ICD fix
_NV_ICD_SRC="/usr/share/vulkan/icd.d/nvidia_icd.x86_64.json"
_NV_DRV_DIR="\${HOME}/.local/share/runimage_nvidia"
if [ -f "\$_NV_ICD_SRC" ]; then
    cp -f "\$_NV_ICD_SRC" /etc/nvidia_icd.json 2>/dev/null || true
    [ -f "/usr/share/vulkan/implicit_layer.d/nvidia_production_layers.json" ] && \
        cp -f "/usr/share/vulkan/implicit_layer.d/nvidia_production_layers.json" /etc/nvidia_layers.json 2>/dev/null || true
    [ -f "/usr/share/glvnd/egl_vendor.d/10_nvidia_production.json" ] && \
        cp -f "/usr/share/glvnd/egl_vendor.d/10_nvidia_production.json" /etc/10_nvidia.json 2>/dev/null || true
fi
unset _NV_ICD_SRC _NV_DRV_DIR

ulimit -H -n 819200 && ulimit -S -n 819200
sysctl -w fs.inotify.max_user_watches=8192000 vm.max_map_count=2147483642 fs.file-max=8192000 >/dev/null 2>&1

# Launch game via Lutris
dbus-run-session /userdata/system/add-ons/lutris/lutris "lutris:rungameid/${game_id}"
LAUNCHER
            chmod +x "$sh_file"

            # padtokey profile
            cat > "${sh_file}.keys" <<'KEYS'
{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "exec",
            "target": "pkill -f lutris",
            "description": "Kill Lutris"
        }
    ]
}
KEYS

            # Image — check Lutris local cache first
            img_file="${images}/${game_slug}.jpg"
            if [[ ! -f "$img_file" ]]; then
                for src in \
                    "${LUTRIS_BANNERS}/${game_slug}.jpg" \
                    "${LUTRIS_BANNERS}/${game_slug}.png" \
                    "${LUTRIS_COVERART}/${game_slug}.jpg" \
                    "${LUTRIS_COVERART}/${game_slug}.png"; do
                    if [[ -f "$src" ]]; then
                        cp "$src" "$img_file"
                        break
                    fi
                done
            fi

            # Add to gamelist.xml
            if ! grep -q "<path>./$(basename "$sh_file")</path>" "$GAMELIST_PATH"; then
                sed -i '/<\/gameList>/d' "$GAMELIST_PATH"
                echo "  <game>" >> "$GAMELIST_PATH"
                echo "    <path>./$(basename "$sh_file")</path>" >> "$GAMELIST_PATH"
                echo "    <name>${game_name}</name>" >> "$GAMELIST_PATH"
                [[ -f "$img_file" ]] && \
                    echo "    <image>./images/$(basename "$img_file")</image>" >> "$GAMELIST_PATH"
                echo "    <rating>0</rating>" >> "$GAMELIST_PATH"
                echo "    <releasedate>19700101T010000</releasedate>" >> "$GAMELIST_PATH"
                echo "    <lang>en</lang>" >> "$GAMELIST_PATH"
                echo "  </game>" >> "$GAMELIST_PATH"
                echo '</gameList>' >> "$GAMELIST_PATH"
                echo "  ✓ Added ${game_name} to gamelist.xml"
            fi
        fi

    done <<< "$GAME_LIST"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan complete. Sleeping ${LOOP_DELAY}s..."
    sleep "$LOOP_DELAY"

done
