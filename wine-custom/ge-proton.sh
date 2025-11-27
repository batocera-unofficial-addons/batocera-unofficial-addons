#!/bin/bash

# API endpoint for GitHub releases with 100 releases per page
REPO_URL="https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases?per_page=100"

# Directory to store custom Wine (Proton-GE) versions
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

# Build full list of available versions
all_releases=()
while IFS= read -r line; do
    tag=$(echo "$line" | jq -r '.tag_name')
    name=$(echo "$line" | jq -r '.name')
    description="${name} - ${tag}"
    all_releases+=("$tag" "$description")
done < <(echo "$release_data" | jq -c '.[]')

total_items=$((${#all_releases[@]} / 2))
items_per_page=100
current_page=0
choice=""

# Pagination loop - allow scrolling through pages
while true; do
    # Calculate page boundaries
    start_idx=$((current_page * items_per_page))
    end_idx=$(((current_page + 1) * items_per_page))
    
    # Build menu for current page
    menu_args=()
    for ((i = start_idx; i < end_idx && i < total_items; i++)); do
        menu_args+=("${all_releases[$((i*2))]}" "${all_releases[$((i*2+1))]}")
    done
    
    # Add navigation options if there are more pages
    has_next=$((end_idx < total_items ? 1 : 0))
    has_prev=$((current_page > 0 ? 1 : 0))
    
    page_info="Page $((current_page + 1)) of $(((total_items + items_per_page - 1) / items_per_page))"
    
    # Add navigation items at bottom
    if [ $has_next -eq 1 ]; then
        menu_args+=("__NEXT__" ">>> Next Page")
    fi
    if [ $has_prev -eq 1 ]; then
        menu_args+=("__PREV__" "<<< Previous Page")
    fi
    
    # Show dialog menu for version selection
    choice=$(dialog --stdout --title "Select Proton-GE Version" --menu "Choose Proton-GE version ($page_info):" 25 90 20 "${menu_args[@]}")
    
    if [ -z "$choice" ]; then
        echo "Installation cancelled."
        exit 1
    fi
    
    # Handle navigation
    if [ "$choice" = "__NEXT__" ]; then
        ((current_page++))
        continue
    elif [ "$choice" = "__PREV__" ]; then
        ((current_page--))
        continue
    else
        # Valid selection made
        break
    fi
done

# Process the selected version
version="$choice"
url=$(echo "$release_data" | jq -r ".[] | select(.tag_name == \"$version\") | .assets[] | select(.name | endswith(\".tar.gz\")).browser_download_url" | head -n1)

if [[ -z "$url" ]]; then
    echo "No compatible download found for Proton ${version}."
    exit 1
fi

# Create directory for the selected version
version_dir="${INSTALL_DIR}proton-${version}"
mkdir -p "$version_dir"
cd "$version_dir" || { echo "Failed to change directory."; exit 1; }

# Download the selected version
echo "Downloading Proton-GE ${version} from $url"
wget -q --tries=10 --no-check-certificate --no-cache --no-cookies --show-progress -O "${version_dir}/proton-${version}.tar.gz" "$url"

# Check if the download was successful
if [ -f "${version_dir}/proton-${version}.tar.gz" ]; then
    echo "Unpacking Proton-GE ${version} in ${version_dir}..."

    # Unpack the .tar.gz file
    tar -xzf "${version_dir}/proton-${version}.tar.gz" --strip-components=1

    # Check if extraction was successful
    if [ "$(ls -A "$version_dir")" ]; then
        echo "Unpacking successful."
        rm "proton-${version}.tar.gz"

        # Check if a "files" folder exists
        if [ -d "${version_dir}/files" ]; then
            echo "Moving files from 'files' folder to parent directory..."

            # Move files from the "files" folder to the parent directory
            mv "${version_dir}/files/"* "${version_dir}/"

            # Remove the "files" folder
            rmdir "${version_dir}/files"

            echo "'files' folder processed and deleted."
        fi
    else
        echo "Unpacking failed, directory is empty."
    fi

    echo "Installation of Proton-GE ${version} complete."
else
    echo "Failed to download Proton-GE ${version}."
fi

# Return to the initial directory
cd - > /dev/null

echo "Installation complete."

