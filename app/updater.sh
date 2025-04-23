#!/bin/bash

ADDONS_DIR="/userdata/system/add-ons"
REPO_USER="DTJW92"
REPO_NAME="batocera-unofficial-addons"
REPO_BRANCH="main"
REPO_BASE_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$REPO_BRANCH"
GITHUB_API="https://api.github.com/repos/$REPO_USER/$REPO_NAME/commits"

TEMP_DIR="/tmp/addon-updater"
mkdir -p "$TEMP_DIR"
CHECKLIST_FILE="$TEMP_DIR/checklist.txt"

> "$CHECKLIST_FILE"
UPDATE_COUNT=0

echo "🔍 Scanning installed add-ons..."

# Loop through each add-on
for ADDON_PATH in "$ADDONS_DIR"/*; do
    [ -d "$ADDON_PATH" ] || continue
    ADDON_NAME=$(basename "$ADDON_PATH")
    LOCAL_MODIFIED=$(stat -c %Y "$ADDON_PATH")

    # Get latest commit date from GitHub API
    API_URL="$GITHUB_API?path=$ADDON_NAME/$ADDON_NAME.sh&sha=$REPO_BRANCH"
    REMOTE_MODIFIED=$(curl -s "$API_URL" | jq -r '.[0].commit.committer.date' | xargs -I{} date -d {} +%s 2>/dev/null)

    if [[ -z "$REMOTE_MODIFIED" || "$REMOTE_MODIFIED" == "null" ]]; then
        echo "Skipping $ADDON_NAME — commit not found"
        continue
    fi

    if [ "$REMOTE_MODIFIED" -gt "$LOCAL_MODIFIED" ]; then
        echo "$ADDON_NAME \"$ADDON_NAME has an update\" off" >> "$CHECKLIST_FILE"
        ((UPDATE_COUNT++))
    fi
done

# If everything is up to date
if [ "$UPDATE_COUNT" -eq 0 ]; then
    dialog --msgbox "All installed add-ons are already up to date!" 7 50
    clear
    exit 0
fi

# Show checklist dialog with only outdated items
CHOICES=$(dialog --clear --stdout --no-tags --checklist "Select add-ons to update:" 20 70 15 --file "$CHECKLIST_FILE")

clear

# Perform updates if selected
if [ -n "$CHOICES" ]; then
    for ADDON in $CHOICES; do
        echo "Updating $ADDON..."
        SCRIPT_URL="$REPO_BASE_URL/$ADDON/$ADDON.sh"
        TEMP_SCRIPT="$TEMP_DIR/$ADDON.sh"

        curl -s -L -o "$TEMP_SCRIPT" "$SCRIPT_URL"
        chmod +x "$TEMP_SCRIPT"
        bash "$TEMP_SCRIPT"
        echo "$ADDON updated."
    done
else
    echo "No add-ons selected. Nothing was updated."
fi

rm -rf "$TEMP_DIR"
