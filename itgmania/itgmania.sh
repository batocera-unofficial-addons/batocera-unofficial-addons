#!/bin/bash

# Variables
install_dir="/userdata/system/add-ons/itgmania"
ports_dir="/userdata/roms/ports"
base_url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/itgmania"

# Get latest ITGMania release URL
echo "Fetching latest ITGMania release..."
itgmania_url=$(curl -s https://api.github.com/repos/ITGmania/ITGmania/releases/latest \
    | grep browser_download_url \
    | grep "Linux\.tar\.gz" \
    | grep -v "no-songs" \
    | cut -d '"' -f 4)

if [ -z "$itgmania_url" ]; then
    dialog --title "ITGMania" --msgbox "Failed to fetch ITGMania release URL. Please check your internet connection." 8 60
    exit 1
fi

# Prepare install directory
# ITGMania keeps settings, profiles and scores in $install_dir/.itgmania (the
# launcher's HOME), and songs, courses, themes or noteskins you add go into
# the install folder itself. Reinstalling only replaces the files that came
# with the previous release (listed in $manifest), so all of that is kept.
manifest="$install_dir/.bua-files"
echo "Setting up installation directory at $install_dir..."
mkdir -p "$install_dir"

# Download
echo "Downloading ITGMania..."
wget -q --show-progress -O "$install_dir/itgmania.tar.gz" "$itgmania_url"

if [ $? -ne 0 ] || [ ! -s "$install_dir/itgmania.tar.gz" ]; then
    rm -f "$install_dir/itgmania.tar.gz"
    dialog --title "ITGMania" --msgbox "Failed to download ITGMania." 8 60
    exit 1
fi

# Remove the files of the previous release (not your data)
if [ -f "$manifest" ]; then
    echo "Removing files from the previous ITGMania release..."
    while IFS= read -r rel; do
        [ -n "$rel" ] && rm -f "$install_dir/$rel"
    done < "$manifest"
    find "$install_dir" -mindepth 1 -depth -type d -empty ! -path "$install_dir/.itgmania*" -delete 2>/dev/null
    rm -f "$manifest"
fi

# Extract, listing the release's files (paths without the two stripped
# folders) so a reinstall or uninstall removes exactly these and nothing
# you added.
echo "Extracting..."
tar -xvzf "$install_dir/itgmania.tar.gz" -C "$install_dir" --strip-components=2 \
    | grep -v '/$' | cut -d/ -f3- | grep -v '^$' > "$manifest"
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
    rm -f "$install_dir/itgmania.tar.gz"
    dialog --title "ITGMania" --msgbox "Failed to extract ITGMania." 8 60
    exit 1
fi
rm -f "$install_dir/itgmania.tar.gz"
chmod +x "$install_dir/itgmania"

# Create ports launcher
echo "Creating ports launcher..."
mkdir -p "$ports_dir/images"
cat << 'PORTSCRIPT' > "$ports_dir/ITGMania.sh"
#!/bin/bash
export $(cat /proc/1/environ | tr '\0' '\n')
export DISPLAY=:0.0
export HOME="/userdata/system/add-ons/itgmania"
cd /userdata/system/add-ons/itgmania
./itgmania
PORTSCRIPT
chmod +x "$ports_dir/ITGMania.sh"

# Download logo and update gamelist
echo "Downloading logo..."
curl -L -o "$ports_dir/images/itgmania-logo.png" "$base_url/extra/itgmania-logo.png"

echo "Updating gamelist..."
if [ ! -f "$ports_dir/gamelist.xml" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$ports_dir/gamelist.xml"
fi
# -d drops an entry left by an earlier install, so a reinstall doesn't add a second one
xmlstarlet ed -d "/gameList/game[path='./ITGMania.sh']" \
  -s "/gameList" -t elem -n "game" -v "" \
  -s "/gameList/game[last()]" -t elem -n "path" -v "./ITGMania.sh" \
  -s "/gameList/game[last()]" -t elem -n "name" -v "ITGMania" \
  -s "/gameList/game[last()]" -t elem -n "image" -v "./images/itgmania-logo.png" \
  "$ports_dir/gamelist.xml" > "$ports_dir/gamelist.xml.tmp" && mv "$ports_dir/gamelist.xml.tmp" "$ports_dir/gamelist.xml"
curl -s http://127.0.0.1:1234/reloadgames

echo "ITGMania installation complete."
