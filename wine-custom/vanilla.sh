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
choice=$(dialog --stdout --title "Select Wine/Proton Version" --menu "Choose which Wine/Proton version to install:" 20 80 12 "${menu_args[@]}")

if [ -z "$choice" ]; then
    echo "Installation cancelled."
    exit 1
fi

# Process the selected version
version="$choice"
url=$(echo "$release_data" | jq -r ".[] | select(.tag_name == \"$version\") | .assets[] | select(.name | endswith(\"amd64.tar.xz\")).browser_download_url" | head -n1)

if [[ -z "$url" ]]; then
    echo "No compatible download found for Wine ${version}."
    exit 1
fi

# Create directory for the selected version
mkdir -p "${INSTALL_DIR}wine-${version}"
cd "${INSTALL_DIR}wine-${version}"

# Download the selected version
echo "Downloading wine ${version} from $url"
wget -q --tries=10 --no-check-certificate --no-cache --no-cookies --show-progress -O "${INSTALL_DIR}wine-${version}/wine-${version}.tar.xz" "$url"

# Check if the download was successful
if [ -f "${INSTALL_DIR}wine-${version}/wine-${version}.tar.xz" ]; then
    echo "Unpacking Wine ${version}..."
    cd ${INSTALL_DIR}wine-${version}
    tar --strip-components=1 -xf "${INSTALL_DIR}wine-${version}/wine-${version}.tar.xz"
    rm "wine-${version}.tar.xz"
    echo "Installation of Wine ${version} complete."
else
    echo "Failed to download Wine ${version}."
fi

# Return to the initial directory
cd -

echo "Installation complete."

