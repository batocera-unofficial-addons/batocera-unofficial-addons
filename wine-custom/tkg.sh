#!/bin/bash

# API endpoint for GitHub releases
REPO_URL="https://api.github.com/repos/Kron4ek/Wine-Builds/releases?per_page=300"

# Directory to store custom Wine versions
INSTALL_DIR="/userdata/system/wine/custom/"
mkdir -p "$INSTALL_DIR"

# Fetch release data from GitHub
echo "Fetching release information..."
release_data=$(curl -s $REPO_URL)

# Check if curl succeeded
if [[ $? -ne 0 ]]; then
    echo "Failed to fetch release data."
    exit 1
fi

# Build options for dialog menu - filter only tkg-staging builds (limit to first 20 for usability)
menu_args=()
i=0
while IFS= read -r line && [ $i -lt 20 ]; do
    name=$(echo "$line" | jq -r '.name')
    tag=$(echo "$line" | jq -r '.tag_name')
    tkg_staging_assets=$(echo "$line" | jq -c '.assets[] | select(.name | contains("staging-tkg"))')
    if [ -n "$tkg_staging_assets" ]; then
        description="${name} - ${tag}"
        menu_args+=("$tag" "$description")
        ((i++))
    fi
done < <(echo "$release_data" | jq -c '.[]')

# Show dialog menu for version selection
choice=$(dialog --stdout --title "Select Wine TKG-Staging Version" --menu "Choose which Wine TKG-Staging version to install:" 20 80 12 "${menu_args[@]}")

if [ -z "$choice" ]; then
    echo "Installation cancelled."
    exit 1
fi

# Process the selected version
version="$choice"
url=$(echo "$release_data" | jq -r ".[] | select(.tag_name == \"$version\") | .assets[] | select(.name | contains(\"staging-tkg\") and endswith(\"amd64.tar.xz\")).browser_download_url" | head -n1)

if [[ -z "$url" ]]; then
    echo "No compatible download found for Wine ${version}."
    exit 1
fi

# Define output folder
output_folder="${INSTALL_DIR}wine-${version}-staging-tkg"

# Create directory for the selected version
mkdir -p "$output_folder"
cd "$output_folder"

# Download the selected version
echo "Downloading wine ${version} from $url"
wget -q --tries=10 --no-check-certificate --no-cache --no-cookies --show-progress -O "${output_folder}/wine-${version}-staging-tkg.tar.xz" "$url"

# Check if the download was successful
if [ -f "${output_folder}/wine-${version}-staging-tkg.tar.xz" ]; then
    echo "Unpacking Wine ${version}..."
    cd "$output_folder"
    tar --strip-components=1 -xf "${output_folder}/wine-${version}-staging-tkg.tar.xz"
    rm "wine-${version}-staging-tkg.tar.xz"
    echo "Installation of Wine ${version} complete."
else
    echo "Failed to download Wine ${version}."
fi

# Return to the initial directory
cd -

echo "Installation complete."
