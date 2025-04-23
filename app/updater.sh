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

echo "🔍 Scanning installed add-ons..."

# Build the checklist
for ADDON_PATH in "$ADDONS_DIR"/*; do
    [ -d "$ADDON_PATH" ] || continue
    ADDON_NAME=$(basename "$ADDON_PATH")
    LOCAL_MODIFIED=$(stat -c %Y "$ADDON_PATH")

    # Use GitHub API to get last commit time of script
    API_URL="$GITHUB_API?path=$ADDON_NAME/$ADDON_NAME.sh&sha=$REPO_BRANCH"
    REMOTE_MODIFIED=$(curl -s "$API_URL" | jq -r '.[0].commit.committer.date' | xargs -I{} date -d {} +%s 2>/dev/null)

    if [[ -z "$REMOTE_MODIFIED" || "$REMOTE_MODIFIED" == "null" ]]; then
        echo "Could not get commit time for $ADDON_NAME" >&2
        continue
    fi

    if [ "$REMOTE_MODIFIED" -gt "$LOCAL_MODIFIED" ]; then
        echo "$ADDON_NAME \"$ADDON_NAME needs update\" off" >> "$CHECKLIST_FILE"
    else
        echo "$ADDON_NAME \"$ADDON_NAME is up to date\" off" >> "$CHECKLIST_FILE"
    fi
done

# Show dialog checklist
CHOICES=$(dialog --clear --stdout --no-tags --checklist "Select add-ons to update:" 20 70 15 --file "$CHECKLIST_FILE")

clear

# Perform updates
if [ -n "$CHOICES" ]; then
    for ADDON in $CHOICES; do
        echo "⬇️ Updating $ADDON..."
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

# Cleanup
rm -rf "$TEMP_DIR"
