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

# Check if version is provided via environment variable (from GUI)
if [ -n "$WINE_VERSION" ]; then
    # Version pre-selected from GUI
    version="$WINE_VERSION"
    echo "Installing pre-selected version: $version"
else
    # Build full list of tkg-staging versions
    all_releases=()
    while IFS= read -r line; do
        tag=$(echo "$line" | jq -r '.tag_name')
        name=$(echo "$line" | jq -r '.name')
        tkg_staging_assets=$(echo "$line" | jq -c '.assets[] | select(.name | contains("staging-tkg"))')
        if [ -n "$tkg_staging_assets" ]; then
            description="${name} - ${tag}"
            all_releases+=("$tag" "$description")
        fi
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
        choice=$(dialog --stdout --title "Select Wine TKG-Staging Version" --menu "Choose Wine TKG-Staging version ($page_info):" 25 90 20 "${menu_args[@]}")

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
