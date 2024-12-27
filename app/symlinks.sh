#!/bin/bash

# Function to create symlinks
create_symlinks() {
    # Base directory containing add-ons and .dep folder
    ADDONS_BASE_DIR="/userdata/system/add-ons"
    DEP_DIR="$ADDONS_BASE_DIR/.dep"

    # Loop through each subdirectory in the add-ons base directory
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        # Create symlinks for bin and lib files
        for folder in "bin" "lib"; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Found $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    if [ -f "$file" ]; then
                        target_dir="/usr/bin"
                        [[ "$folder" == "lib" ]] && target_dir="/usr/lib"

                        symlink_target="$target_dir/$(basename "$file")"
                        if [ ! -L "$symlink_target" ]; then
                            echo "Creating symlink: $symlink_target -> $file"
                            ln -s "$file" "$symlink_target"
                        else
                            echo "Symlink already exists: $symlink_target. Skipping."
                        fi
                    fi
                done
            fi
        done

        # Handle files in .dep (handling it as originally designed)
        for file in "$DEP_DIR"/*; do
            if [ -f "$file" ]; then
                # Check if the filename contains "lib"
                if [[ "$(basename "$file")" == *lib* ]]; then
                    symlink_target="/usr/lib/$(basename "$file")"
                else
                    symlink_target="/usr/bin/$(basename "$file")"
                fi

                # Create symlink if it doesn't already exist
                if [ ! -L "$symlink_target" ]; then
                    echo "Creating symlink: $symlink_target -> $file"
                    ln -s "$file" "$symlink_target"
                else
                    echo "Symlink already exists: $symlink_target. Skipping."
                fi
            fi
        done
    done

    echo "Symlink creation completed!"
}

# Function to remove symlinks
remove_symlinks() {
    # Base directory containing add-ons and .dep folder
    ADDONS_BASE_DIR="/userdata/system/add-ons"
    DEP_DIR="$ADDONS_BASE_DIR/.dep"

    # Loop through each subdirectory in the add-ons base directory
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        # Remove symlinks for bin and lib files
        for folder in "bin" "lib"; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Found $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    if [ -f "$file" ]; then
                        target_dir="/usr/bin"
                        [[ "$folder" == "lib" ]] && target_dir="/usr/lib"

                        symlink_target="$target_dir/$(basename "$file")"
                        if [ -L "$symlink_target" ]; then
                            echo "Removing symlink: $symlink_target"
                            rm "$symlink_target"
                        else
                            echo "Symlink does not exist: $symlink_target. Skipping."
                        fi
                    fi
                done
            fi
        done

        # Handle files in .dep (removal logic preserved as originally)
        for file in "$DEP_DIR"/*; do
            if [ -f "$file" ]; then
                # Check if the filename contains "lib"
                if [[ "$(basename "$file")" == *lib* ]]; then
                    symlink_target="/usr/lib/$(basename "$file")"
                else
                    symlink_target="/usr/bin/$(basename "$file")"
                fi

                # Remove the symlink if it exists
                if [ -L "$symlink_target" ]; then
                    echo "Removing symlink: $symlink_target"
                    rm "$symlink_target"
                else
                    echo "Symlink does not exist: $symlink_target. Skipping."
                fi
            fi
        done
    done

    echo "Symlink removal completed!"
}

# Function to check the status of symlinks
check_status() {
    # Base directory containing add-ons with bin and lib folders
    ADDONS_BASE_DIR="/userdata/system/add-ons"

    echo "Checking the status of symlinks..."

    # Loop through each subdirectory in the add-ons base directory
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        # Check symlinks in bin and lib folders
        for folder in "bin" "lib"; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Found $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    if [ -f "$file" ]; then
                        target_dir="/usr/bin"
                        [[ "$folder" == "lib" ]] && target_dir="/usr/lib"

                        symlink_target="$target_dir/$(basename "$file")"
                        if [ -L "$symlink_target" ]; then
                            echo "Symlink exists: $symlink_target"
                        else
                            echo "Symlink does not exist: $symlink_target"
                        fi
                    fi
                done
            fi
        done
    done
}

# Infinite loop to keep the service running
while true; do
    case "$1" in
        start)
            echo "Starting symlink creation..."
            create_symlinks
            ;;
        stop)
            echo "Stopping symlink creation..."
            remove_symlinks
            ;;
        status)
            echo "Checking status of symlinks..."
            check_status
            ;;
        *)
            echo "Usage: $0 {start|stop|status}"
            exit 1
            ;;
    esac

    # Sleep for a certain period before the next check (e.g., 60 seconds)
    sleep 10
done
