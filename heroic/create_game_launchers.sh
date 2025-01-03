#!/usr/bin/env bash
# SYNC HEROIC LAUNCHER GAMES TO HEROIC SYSTEM ROMS AND GAMELIST
# ---------------------------------------------------
roms=/userdata/roms/heroic
images=/userdata/roms/heroic/images
icons=/userdata/system/.config/heroic/icons
logs_dir=/userdata/system/.config/heroic/GamesConfig
json_dir=/userdata/system/.config/heroic/GamesConfig
gamelist=/userdata/roms/heroic/gamelist.xml
extra=/userdata/system/add-ons/heroic/extra
list=$extra/gamelist.txt
check=$extra/check.txt
all=$extra/all.txt
gamelist=$roms/gamelist.xml

# Prepare directories
mkdir -p "$images" "$extra" 2>/dev/null
rm -rf "$check" "$all" "$list"

# Generate list of ROMs
find "$roms" -maxdepth 1 -type f -exec basename {} \; | sed 's/\..*//' > "$list"

# Start XML gamelist
if [[ ! -f "$gamelist" ]]; then
  echo "<gameList>" > "$gamelist"
fi

# Check all log files matching the game ID
if [[ -e "$list" ]]; then
  nrgames=$(wc -l < "$list")
  if [[ $nrgames -gt 0 ]]; then
    for gid in $(cat "$list"); do
      icon=$(ls "$icons" | grep "^$gid" | head -n1)

      # Copy icon to images directory
      if [[ -n "$icon" ]]; then
        cp "$icons/$icon" "$images/$icon" 2>/dev/null
      fi

      game_name=""
      for log_file in "$logs_dir/$gid"*.log; do
        if [[ -f "$log_file" ]]; then
          extracted_name=$(grep -oP '(?<=Preparing download for ")[^"]+' "$log_file" | head -n1)
          if [[ -z "$extracted_name" ]]; then
            extracted_name=$(grep -oP '(?<=Launching ")[^"]+' "$log_file" | head -n1)
          fi
          if [[ -n "$extracted_name" ]]; then
            game_name="$extracted_name"
            break
          fi
        fi
      done

      if [[ -z "$game_name" ]]; then
        json_file="$json_dir/$gid.json"
        if [[ -f "$json_file" ]]; then
          extracted_name=$(grep -oP '(?<=winePrefix": "/userdata/system/Games/Heroic/Prefixes/default/)[^"]+' "$json_file" | head -n1)
          if [[ -n "$extracted_name" ]]; then
            game_name="$extracted_name"
          fi
        fi
      fi

      if [[ -z "$game_name" ]]; then
        game_name="$gid"
        echo "Warning: Could not extract game name for ID $gid."
      fi

      sanitized_name=$(echo "$game_name" | tr ' ' '_')

      if [[ -n "$icon" ]]; then
        ext="${icon##*.}"
        mv "$images/$icon" "$images/$sanitized_name.$ext" 2>/dev/null
      fi

      find "$roms" -maxdepth 1 -type f -not -name '*.txt' -exec basename {} \; > "$all"
      dos2unix "$all" 2>/dev/null
      for thisrom in $(cat "$all"); do
        romcheck=$(cat "$roms/$thisrom" 2>/dev/null)
        if [[ -z "$romcheck" || ! -e "$icons/$romcheck.png" ]]; then
          rm -f "$roms/$thisrom" "$images/$romcheck.png" "$images/$romcheck.jpg"
        fi
      done

      if [[ ! -f "$roms/$sanitized_name.txt" ]]; then
        echo "$gid" > "$roms/$sanitized_name.txt"
        echo "$gid" >> "$check"
      fi

      # Ensure the gamelist.xml exists
if [ ! -f "$gamelist" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist"
fi

rom_file=$(find "$roms" -name "$sanitized_name.*" -exec basename {} \; | head -n1 | sed "s|^|./|")
      image_file=$(find "$images" -name "$sanitized_name.*" | head -n1)

      if [[ -n "$rom_file" && -n "$image_file" ]]; then
        # Add entry to gamelist.xml
        xmlstarlet ed -L \
          -s "/gameList" -t elem -n "game" -v "" \
          -s "/gameList/game[last()]" -t elem -n "path" -v "$rom_file" \
          -s "/gameList/game[last()]" -t elem -n "name" -v "$game_name" \
          -s "/gameList/game[last()]" -t elem -n "image" -v "$image_file" \
          "$gamelist"
      else
        echo "Warning: Missing file for ROM $sanitized_name (rom: $rom_file, image: $image_file)"
      fi
    done
  fi
fi

# Ensure gamelist.xml ends with a closing tag
if ! grep -q "</gameList>" "$gamelist"; then
  echo "</gameList>" >> "$gamelist"
fi

# Cleanup temporary files
rm -rf "$list" "$all" "$check"
