#!/bin/bash

# Directory paths
output_dir="/userdata/roms/ps4"
gamelist_path="/userdata/roms/ps4/gamelist.xml"
processed_list="/userdata/system/.local/share/shadPS4/processed_games.txt"
app_image="/userdata/system/add-ons/shadps4/Shadps4-qt.AppImage"
image_dir="/userdata/system/add-ons/shadps4/images"
csv_url="https://raw.githubusercontent.com/DTJW92/batocera-unofficial-addons/refs/heads/main/shadps4/extra/PS4_Title_ID_List.csv"
mkdir -p "$output_dir" "$image_dir"

# Default .keys content
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

# Initialize processed list if it doesn't exist
touch "$processed_list"

# Validate processed games and clean up entries for removed games
temp_processed_list="${processed_list}.tmp"
touch "$temp_processed_list"

while read -r processed_game; do
    if [ -d "$output_dir/$processed_game" ]; then
        echo "$processed_game" >> "$temp_processed_list"
    else
        echo "Game $processed_game no longer exists. Removing from processed list."
        # Remove associated script and keys files
        sanitized_name=$(echo "$processed_game" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
        rm -f "$output_dir/${sanitized_name}.sh" "$output_dir/${sanitized_name}.sh.keys" "$image_dir/${sanitized_name}.png"

        # Remove the game entry from gamelist.xml
        xmlstarlet ed -L \
            -d "/gameList/game[path='./${sanitized_name}.sh']" \
            "$gamelist_path"
    fi
done < "$processed_list"

# Replace the old processed list with the updated one
mv "$temp_processed_list" "$processed_list"

# Initialize gamelist.xml if it doesn't exist
if [ ! -f "$gamelist_path" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist_path"
fi

# Download the CSV file
csv_file="/tmp/PS4_Title_ID_List.csv"
wget -q -O "$csv_file" "$csv_url"

# Iterate through game data directories
for game_dir in "$output_dir"/*/; do
    if [ -d "$game_dir" ]; then
        # Extract game code from the directory name
        game_code=$(basename "$game_dir")

        # Check if the launcher already exists
        sanitized_name=$(echo "$game_code" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
        script_path="${output_dir}/${sanitized_name}.sh"
        keys_path="${output_dir}/${sanitized_name}.sh.keys"

        if [ -f "$script_path" ]; then
            echo "Launcher for game $game_code already exists. Skipping."
            continue
        fi

        # Search the CSV for game details
        csv_entry=$(awk -F ',' -v id="$game_code" '$1 == id {print $0}' "$csv_file")
        if [ -n "$csv_entry" ]; then
            game_name=$(echo "$csv_entry" | awk -F ',' '{print $2}')
            image_url=$(echo "$csv_entry" | awk -F ',' '{print $3}')

            # Download the game image
            image_file="$image_dir/${sanitized_name}.png"
            wget -q -O "$image_file" "$image_url"
        else
            echo "Warning: No entry found for $game_code in CSV. Using game code as name."
            game_name="$game_code"
            image_file=""
        fi

        # Log the extracted game name
        echo "Game name for $game_code: $game_name"

        # Escape special characters in game name
        game_name_escaped=$(echo "$game_name" | xmlstarlet esc)

        # Generate script content
        script_content="#/bin/bash
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

        # Write script and keys file to respective locations
        echo "$script_content" > "$script_path"
        chmod +x "$script_path"
        echo "$keys_content" > "$keys_path"

        echo "Script created: $script_path"
        echo "Keys file created: $keys_path"

        # Update gamelist.xml with the new game
        xmlstarlet ed -L \
            -s "/gameList" -t elem -n "game" -v "" \
            -s "/gameList/game[last()]" -t elem -n "path" -v "./${sanitized_name}.sh" \
            -s "/gameList/game[last()]" -t elem -n "name" -v "${game_name_escaped}" \
            -s "/gameList/game[last()]" -t elem -n "image" -v "${image_file}" \
            -s "/gameList/game[last()]" -t elem -n "rating" -v "0" \
            -s "/gameList/game[last()]" -t elem -n "releasedate" -v "19700101T010000" \
            -s "/gameList/game[last()]" -t elem -n "lang" -v "en" \
            "$gamelist_path"

        # Mark game as processed
        echo "$game_code" >> "$processed_list"
    fi
done
