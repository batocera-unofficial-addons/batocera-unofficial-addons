#!/usr/bin/env bash
# SYNC HEROIC LAUNCHER GAMES TO HEROIC SYSTEM ROMS
# ---------------------------------------------------
roms=/userdata/roms/heroic
images=/userdata/roms/heroic/images
icons=/userdata/system/.config/heroic/icons
logs_dir=/userdata/system/.config/heroic/GamesConfig
json_dir=/userdata/system/.config/heroic/GamesConfig
extra=/userdata/system/add-ons/heroic/extra
list=$extra/gamelist.txt
games=$extra/games.txt
check=$extra/check.txt
all=$extra/all.txt
reload=0

# Prepare directories
mkdir -p "$images" "$extra" 2>/dev/null
rm -rf "$check" "$all" "$list"

# Generate list of game IDs from icons
ls "$icons" | cut -d "." -f1 > "$list"
nrgames=$(wc -l < "$list")

# Process each game ID
if [[ -e "$list" ]]; then
  if [[ $nrgames -gt 0 ]]; then
    for gid in $(cat "$list"); do
      icon=$(ls "$icons" | grep "^$gid" | head -n1)

      # Copy icon to images directory
      if [[ -n "$icon" ]]; then
        cp "$icons/$icon" "$images/$icon" 2>/dev/null
      fi

      # Check all log files matching the game ID
      game_name=""
      for log_file in "$logs_dir/$gid"*.log; do
        if [[ -f "$log_file" ]]; then
          # Attempt to extract game name from standard log format
          extracted_name=$(grep -oP '(?<=Preparing download for ")[^"]+' "$log_file" | head -n1)
          if [[ -z "$extracted_name" ]]; then
            # Attempt to extract game name from -lastPlay.log format
            extracted_name=$(grep -oP '(?<=Launching ")[^"]+' "$log_file" | head -n1)
          fi
          if [[ -n "$extracted_name" ]]; then
            game_name="$extracted_name"
            break
          fi
        fi
      done

      # If no name found, check <gameid>.json for "winePrefix"
      if [[ -z "$game_name" ]]; then
        json_file="$json_dir/$gid.json"
        if [[ -f "$json_file" ]]; then
          extracted_name=$(grep -oP '(?<=winePrefix": "/userdata/system/Games/Heroic/Prefixes/default/)[^"]+' "$json_file" | head -n1)
          if [[ -n "$extracted_name" ]]; then
            game_name="$extracted_name"
          fi
        fi
      fi

      # Fallback to game ID if no name is found
      if [[ -z "$game_name" ]]; then
        game_name="$gid"
        echo "Warning: Could not extract game name for ID $gid."
      fi

      # Sanitize game name (replace spaces with underscores)
      sanitized_name=$(echo "$game_name" | tr ' ' '_')

      # Rename icon to sanitized game name
      if [[ -n "$icon" ]]; then
        ext="${icon##*.}"
        mv "$images/$icon" "$images/$sanitized_name.$ext" 2>/dev/null
      fi

      # Check existing ROMs and remove outdated files
      find "$roms" -maxdepth 1 -type f -not -name '*.txt' -exec basename {} \; > "$all"
      dos2unix "$all" 2>/dev/null
      for thisrom in $(cat "$all"); do
        romcheck=$(cat "$roms/$thisrom" 2>/dev/null)
        if [[ -z "$romcheck" || ! -e "$icons/$romcheck.png" ]]; then
          rm -f "$roms/$thisrom" "$images/$romcheck.png" "$images/$romcheck.jpg"
          reload=1
        fi
      done

      # Create or update the .txt file for the game if it does not exist
      if [[ ! -f "$roms/$sanitized_name.txt" ]]; then
        echo "$gid" > "$roms/$sanitized_name.txt"
        echo "$gid" >> "$check"
      fi
    done
  fi
fi

# Reload games if necessary
if [[ -e "$games" ]]; then
  was=$(cat "$games" | wc -l)
  if [[ "$nrgames" > "$was" ]] || [[ "$reload" = "1" ]]; then
    rm -rf "$games" 2>/dev/null
    echo "$nrgames" > "$games"
    curl http://127.0.0.1:1234/reloadgames
  fi
else 
  echo "$nrgames" > "$games" 
  curl http://127.0.0.1:1234/reloadgames
fi

# Cleanup temporary files
rm -rf "$check" "$all" "$list"
