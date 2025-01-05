#!/bin/bash

# Directory paths
game_data_dir="/userdata/system/.local/share/shadPS4/game_data"
output_dir="/userdata/roms/ps4"
images_dir="/userdata/roms/ps4/images"
gamelist_path="/userdata/roms/ps4/gamelist.xml"
processed_list="/userdata/system/.local/share/shadPS4/processed_games.txt"
app_image="/userdata/system/add-ons/shadps4/Shadps4-qt.AppImage"
mkdir -p "$output_dir" "$images_dir"

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
    if [ -d "$game_data_dir/$processed_game" ]; then
        echo "$processed_game" >> "$temp_processed_list"
    else
        echo "Game $processed_game no longer exists. Removing from processed list."
        # Remove associated script, keys, and image files
        sanitized_name=$(echo "$processed_game" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
        rm -f "$output_dir/${sanitized_name}.sh" "$output_dir/${sanitized_name}.sh.keys" "$images_dir/${sanitized_name}.png"

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

# Iterate through game data directories
for game_dir in "$game_data_dir"/*/; do
    if [ -d "$game_dir" ]; then
        # Extract game code from the directory name
        game_code=$(basename "$game_dir")

        # Skip games already processed
        if grep -q "^$game_code$" "$processed_list"; then
            echo "Game $game_code has already been processed. Skipping."
            continue
        fi

        # Extract game name from TROP.XML
        trophy_file="$game_dir/TrophyFiles/trophy00/Xml/TROP.XML"
        if [ -f "$trophy_file" ]; then
            game_name=$(grep -oP '(?<=<title-name>).*?(?=</title-name>)' "$trophy_file")
        else
            echo "Warning: TROP.XML not found for $game_code. Using game code as name."
            game_name="$game_code"
        fi

        # Sanitize game name for script filename
        sanitized_name=$(echo "$game_name" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
        script_path="${output_dir}/${sanitized_name}.sh"
        keys_path="${output_dir}/${sanitized_name}.sh.keys"

        # Copy game image
        image_file="$game_dir/pic1.png"
        if [ -f "$image_file" ]; then
            cp "$image_file" "$images_dir/${sanitized_name}.png"
        else
            echo "Warning: No image found for $game_code."
        fi

        # Generate script content
        script_content="#/bin/bash
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
        game_image="./images/${sanitized_name}.png"
        xmlstarlet ed -L \
            -s "/gameList" -t elem -n "game" -v "" \
            -s "/gameList/game[last()]" -t elem -n "path" -v "./${sanitized_name}.sh" \
            -s "/gameList/game[last()]" -t elem -n "name" -v "${game_name}" \
            -s "/gameList/game[last()]" -t elem -n "image" -v "${game_image}" \
            -s "/gameList/game[last()]" -t elem -n "rating" -v "0" \
            -s "/gameList/game[last()]" -t elem -n "releasedate" -v "19700101T010000" \
            -s "/gameList/game[last()]" -t elem -n "lang" -v "en" \
            "$gamelist_path"

        # Mark game as processed
        echo "$game_code" >> "$processed_list"
    fi
done

killall -9 emulationstation
echo "Script execution completed."
