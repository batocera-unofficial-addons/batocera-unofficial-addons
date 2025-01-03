#!/bin/bash

# Step 1: Detect system architecture
echo "Detecting system architecture..."
arch=$(uname -m)

if [ "$arch" == "x86_64" ]; then
    echo "Architecture: x86_64 detected."
    app_url=$(curl -s https://api.github.com/repositories/295226865/releases/latest | \
    jq -r ".assets[] | select(.name | contains(\"linux-x64\")) | .browser_download_url")
elif [ "$arch" == "aarch64" ]; then
    echo "Architecture: arm64 detected."
    app_url=$(curl -s https://api.github.com/repositories/295226865/releases/latest | \
    jq -r ".assets[] | select(.name | contains(\"linux-arm64\")) | .browser_download_url")
else
    echo "Unsupported architecture: $arch. Exiting."
    exit 1
fi

# Step 2: Validate app_url
if [ -z "$app_url" ]; then
    echo "Error: Failed to fetch the download URL for YouTube TV."
    echo "Debugging information:"
    curl -s https://api.github.com/repositories/295226865/releases/latest
    exit 1
fi

# Step 3: Download the archive
echo "Downloading YouTube TV archive from $app_url..."
app_dir="/userdata/system/add-ons/youtube-tv"
temp_dir="$app_dir/temp"
mkdir -p "$temp_dir"
wget -q --show-progress -O "$temp_dir/youtube-tv.zip" "$app_url"

if [ $? -ne 0 ]; then
    echo "Failed to download YouTube TV archive."
    exit 1
fi

# Step 4: Extract the downloaded archive
echo "Extracting YouTube TV files..."
mkdir -p "$app_dir"
unzip -o "$temp_dir/youtube-tv.zip" -d "$temp_dir/youtube-tv-extracted"
mv "$temp_dir/youtube-tv-extracted/"*/* "$app_dir"
chmod a+x "$app_dir/YouTubeonTV"

# Cleanup temp files
rm -rf "$temp_dir"
echo "Extraction complete. Files moved to $app_dir."

# Step 5: Create a launcher script using the original command
echo "Creating YouTube TV script in Ports..."
ports_dir="/userdata/roms/ports"
mkdir -p "$ports_dir"
cat << EOF > "$ports_dir/YouTubeTV.sh"
#!/bin/bash
sed -i "s,!appArgs.disableOldBuildWarning,1 == 0,g" "$app_dir/resources/app/lib/main.js" 2>/dev/null
QT_SCALE_FACTOR="1" \
GDK_SCALE="1" \
DISPLAY=:0.0 \
"$app_dir/YouTubeonTV" --no-sandbox --test-type "\$@"
EOF

chmod +x "$ports_dir/YouTubeTV.sh"

# Step 6: Download keys file
echo "Downloading keys file..."
keys_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/youtubetv/extra/YoutubeTV.sh.keys"
keys_file="$ports_dir/YoutubeTV.sh.keys"
curl -L -o "$keys_file" "$keys_url"

if [ $? -ne 0 ]; then
    echo "Failed to download keys file."
    exit 1
fi

echo "Keys file downloaded to $keys_file."

# Step 7: Refresh the Ports menu
echo "Refreshing Ports menu..."
curl http://127.0.0.1:1234/reloadgames

# Step 8: Add an entry to gamelist.xml
echo "Adding YouTube TV entry to gamelist.xml..."
gamelist_file="$ports_dir/gamelist.xml"
logo_url="https://github.com/DTJW92/batocera-unofficial-addons/raw/main/youtubetv/extra/youtubetv-logo.jpg"
logo_path="$ports_dir/images/youtubetv-logo.jpg"

# Ensure the logo directory exists and download the logo
mkdir -p "$(dirname "$logo_path")"
curl -L -o "$logo_path" "$logo_url"

# Ensure the gamelist.xml exists
if [ ! -f "$gamelist_file" ]; then
    echo '<?xml version="1.0" encoding="UTF-8"?><gameList></gameList>' > "$gamelist_file"
fi

curl http://127.0.0.1:1234/reloadgames

# Add the YouTube TV entry
xmlstarlet ed -L \
    -s "/gameList" -t elem -n "game" -v "" \
    -s "/gameList/game[last()]" -t elem -n "path" -v "./YouTubeTV.sh" \
    -s "/gameList/game[last()]" -t elem -n "name" -v "YouTube TV" \
    -s "/gameList/game[last()]" -t elem -n "image" -v "./images/youtubetv-logo.jpg" \
    "$gamelist_file"

# Refresh the Ports menu
curl http://127.0.0.1:1234/reloadgames

echo
echo "Installation complete! You can now launch YouTube TV from the Ports menu."
