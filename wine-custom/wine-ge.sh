#!/bin/bash

# Display a notice using dialog
dialog --msgbox "Note: Testing has shown Wine-GE versions above 8.15 appear broken on Batocera." 10 60

# API endpoint for GitHub releases with 100 releases per page
REPO_URL="https://api.github.com/repos/GloriousEggroll/wine-ge-custom/releases?per_page=100"

# Directory to store custom Wine versions
INSTALL_DIR="/userdata/system/wine/custom/"
mkdir -p "$INSTALL_DIR"

# Check for required commands
for cmd in jq wget curl tar; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed."
        exit 1
    fi
done

# Fetch release data from GitHub (up to 100 releases)
echo "Fetching release information..."
release_data=$(curl -s "$REPO_URL")

# Check if curl succeeded
if [[ $? -ne 0 || -z "$release_data" ]]; then
    echo "Failed to fetch release data."
    exit 1
fi

# Build options for dialog menu (limit to first 20 for usability)
menu_args=()
i=0
while IFS= read -r line && [ $i -lt 20 ]; do
    name=$(echo "$line" | jq -r '.name')
    tag=$(echo "$line" | jq -r '.tag_name')
    description="${name} - ${tag}"
    menu_args+=("$tag" "$description")
    ((i++))
done < <(echo "$release_data" | jq -c '.[]')

# Show dialog menu for version selection
choice=$(dialog --stdout --title "Select Wine-GE Version" --menu "Choose which Wine-GE version to install:" 20 80 12 "${menu_args[@]}")

if [ -z "$choice" ]; then
    echo "Installation cancelled."
    exit 1
fi

# Process the selected version
version="$choice"
url=$(echo "$release_data" | jq -r ".[] | select(.tag_name == \"$version\") | .assets[] | select(.name | endswith(\"x86_64.tar.xz\")).browser_download_url" | head -n1)

if [[ -z "$url" ]]; then
    echo "No compatible download found for Wine ${version}."
    exit 1
fi

# Create directory for the selected version
version_dir="${INSTALL_DIR}wine-${version}"
mkdir -p "$version_dir"
cd "$version_dir" || { echo "Failed to change directory."; exit 1; }

# Download the selected version
echo "Downloading Wine ${version} from $url"
wget -q --tries=10 --no-check-certificate --no-cache --no-cookies --show-progress -O "${version_dir}/wine-${version}.tar.xz" "$url"

# Check if the download was successful
if [ -f "${version_dir}/wine-${version}.tar.xz" ]; then
    echo "Unpacking Wine ${version}..."
    tar --strip-components=1 -xf "${version_dir}/wine-${version}.tar.xz"
    rm "wine-${version}.tar.xz"
    echo "Installation of Wine ${version} complete."
else
    echo "Failed to download Wine ${version}."
fi

# Return to the initial directory
cd - > /dev/null

echo "Installation complete."

