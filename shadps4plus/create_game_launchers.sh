#!/bin/bash

# Directory paths
output_dir="/userdata/roms/ps4"
gamelist_path="$output_dir/gamelist.xml"
processed_list="/userdata/system/.local/share/shadPS4/processed_games.txt"
app_image="/userdata/system/add-ons/shadps4/shadps4plus.AppImage"
image_dir="/userdata/system/add-ons/shadps4/images"
csv_url="https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/refs/heads/main/shadps4plus/extra/PS4_Title_ID_List.csv"

# Optional logging
log_file="/userdata/system/logs/shadps4_installer.log"
mkdir -p "$(dirname "$log_file")"
exec >> "$log_file" 2>&1
echo "------ Run on $(date) ------"

mkdir -p "$output_dir" "$image_dir"

# Default keys config
keys_content='{
    "actions_player1": [
        {
            "trigger": [
                "hotkey",
                "start"
            ],
            "type": "key",
            "target": [
                "KEY_LEFTALT",
                "KEY_F4"
            ],
            "description": "Press Alt+F4"
        },
        {
            "trigger": [
                "hotkey",
                "l2"
            ],
            "type": "key",
            "target": "KEY_ESC",
            "description": "Press Esc"
        },
        {
            "trigger": [
                "hotkey",
                "r2"
            ],
            "type": "key",
            "target": "KEY_ENTER",
            "description": "Press Enter"
        }
    ]
}'

# Ensure required files exist
touch "$processed_list"
if [ ! -f "$gamelist_path" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist_path"
fi

# Clean up removed games from processed list
temp_processed_list="${processed_list}.tmp"
touch "$temp_processed_list"

while read -r processed_game; do
    if [ -d "$output_dir/$processed_game" ]; then
        echo "$processed_game" >> "$temp_processed_list"
    else
        echo "Game $processed_game no longer exists. Removing from processed list."
        sanitized_name=$(echo "$processed_game" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
        rm -f "$output_dir/${sanitized_name}.sh" "$output_dir/${sanitized_name}.sh.keys" "$image_dir/${sanitized_name}.png"

        xmlstarlet ed -L \
            -d "/gameList/game[path='./${sanitized_name}.sh']" \
            "$gamelist_path"
    fi
done < "$processed_list"

mv "$temp_processed_list" "$processed_list"

# Download CSV
csv_file="/tmp/PS4_Title_ID_List.csv"
wget -q -O "$csv_file" "$csv_url"
if [ ! -s "$csv_file" ]; then
    echo "Error: Failed to download CSV or file is empty. Exiting."
    exit 1
fi

# Process each game directory
for game_dir in "$output_dir"/*/; do
    [ -d "$game_dir" ] || continue
    game_code=$(basename "$game_dir")
    sanitized_name=$(echo "$game_code" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
    script_path="${output_dir}/${sanitized_name}.sh"
    keys_path="${output_dir}/${sanitized_name}.sh.keys"

    # Skip if already processed
    if xmlstarlet sel -t -v "//game[path='./${sanitized_name}.sh']" "$gamelist_path" | grep -q .; then
        echo "Game $game_code already in gamelist.xml. Skipping."
        continue
    fi

    # Get game info from CSV
    csv_entry=$(awk -F ',' -v id="$game_code" '$1 == id {print $0}' "$csv_file")
    if [ -n "$csv_entry" ]; then
        game_name=$(echo "$csv_entry" | awk -F ',' '{print $2}')
        image_url=$(echo "$csv_entry" | awk -F ',' '{print $3}')
        image_file="$image_dir/${sanitized_name}.png"
        wget -q -O "$image_file" "$image_url"
    else
        echo "Warning: No entry found for $game_code. Using code as name."
        game_name="$game_code"
        image_file=""
    fi

    echo "Game name for $game_code: $game_name"
    game_name_escaped=$(echo "$game_name" | xmlstarlet esc)

    # Create launcher script
    script_content="#!/bin/bash
ulimit -H -n 819200 && ulimit -S -n 819200
#------------------------------------------------
if [ -x \"${app_image}\" ]; then
    batocera-mouse show
    \"${app_image}\" -g \"$game_code\" -f true
    batocera-mouse hide
else
    echo 'AppImage not found or not executable.'
    exit 1
fi
#------------------------------------------------
"

    echo "$script_content" > "$script_path"
    chmod +x "$script_path"
    echo "$keys_content" > "$keys_path"

    echo "Created: $script_path and $keys_path"

    # Update gamelist.xml
    xmlstarlet ed -L \
        -s "/gameList" -t elem -n "game" -v "" \
        -s "/gameList/game[last()]" -t elem -n "path" -v "./${sanitized_name}.sh" \
        -s "/gameList/game[last()]" -t elem -n "name" -v "${game_name_escaped}" \
        -s "/gameList/game[last()]" -t elem -n "image" -v "${image_file}" \
        -s "/gameList/game[last()]" -t elem -n "rating" -v "0" \
        -s "/gameList/game[last()]" -t elem -n "releasedate" -v "19700101T010000" \
        -s "/gameList/game[last()]" -t elem -n "lang" -v "en" \
        "$gamelist_path"

    echo "$game_code" >> "$processed_list"
done
