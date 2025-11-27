#!/bin/bash

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

# Check if version is provided via environment variable (from GUI)
if [ -n "$WINE_VERSION" ]; then
    # Version pre-selected from GUI
    version="$WINE_VERSION"
    echo "Installing pre-selected version: $version"
    echo "Note: Testing has shown Wine-GE versions above 8.15 appear broken on Batocera."
else
    # Display a notice using dialog
    dialog --msgbox "Note: Testing has shown Wine-GE versions above 8.15 appear broken on Batocera." 10 60

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
        choice=$(dialog --stdout --title "Select Wine-GE Version" --menu "Choose Wine-GE version ($page_info):" 25 90 20 "${menu_args[@]}")

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
fi

# Get download URL for the selected version
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

