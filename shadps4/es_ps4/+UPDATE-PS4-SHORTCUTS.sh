#!/bin/bash

# Directory paths
desktop_dir="/userdata/system/Desktop"
output_dir="/userdata/roms/ps4"
app_image="/userdata/system/add-ons/shadps4/Shadps4-qt.AppImage"
mkdir -p "$output_dir"

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

# Iterate through .desktop files
for file_path in "$desktop_dir"/*.desktop; do
    if [ -f "$file_path" ]; then
        # Check for 'shadps4' in the Exec line
        if grep -q '^Exec=.*shadps4.*' "$file_path"; then
            # Extract game name and game code
            game_name=$(grep '^Name=' "$file_path" | sed 's/^Name=//')
            game_code=$(grep '^Exec=' "$file_path" | sed -E 's/^Exec=.*shadps4 \"(.*)\/eboot\.bin\"/\1/' | awk -F '/' '{print $NF}')

            # Sanitize game name for script filename
            sanitized_name=$(echo "$game_name" | sed 's/ /_/g' | sed 's/[^a-zA-Z0-9_]//g')
            script_path="${output_dir}/${sanitized_name}.sh"
            keys_path="${output_dir}/${sanitized_name}.sh.keys"

            # Generate script content
            script_content="#!/bin/bash
#------------------------------------------------
if [ -x \"${app_image}\" ]; then
    batocera-mouse show
    \"${app_image}\" -g $game_code -f true
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
        fi
    fi
done

killall -9 emulationstation
echo "Script execution completed."
