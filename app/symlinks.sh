#!/bin/bash

# Enable safe file globbing
shopt -s nullglob

# Function to create symlinks
create_symlinks() {
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

                        # Set permissions
                        if [[ "$folder" == "bin" ]]; then
                            chmod +x "$file"
                        else
                            chmod a+r "$file"
                        fi

                        symlink_target="$target_dir/$(basename "$file")"
                        if [ -e "$symlink_target" ]; then
                            if [ -L "$symlink_target" ]; then
                                echo "Symlink already exists: $symlink_target. Skipping."
                            else
                                echo "File exists at target location: $symlink_target. Skipping."
                            fi
                        else
                            echo "Creating symlink: $symlink_target -> $file"
                            ln -s "$file" "$symlink_target"
                        fi
                    fi
                done
            fi
        done
    done

    # Handle files in .dep
    for file in "$DEP_DIR"/*; do
        if [ -f "$file" ]; then
            if [[ "$(basename "$file")" == *lib* ]]; then
                chmod a+r "$file"
                symlink_target="/usr/lib/$(basename "$file")"
            else
                chmod +x "$file"
                symlink_target="/usr/bin/$(basename "$file")"
            fi

            if [ -e "$symlink_target" ]; then
                if [ -L "$symlink_target" ]; then
                    echo "Symlink already exists: $symlink_target. Skipping."
                else
                    echo "File exists at target location: $symlink_target. Skipping."
                fi
            else
                echo "Creating symlink: $symlink_target -> $file"
                ln -s "$file" "$symlink_target"
            fi
        fi
    done

    echo "Symlink creation completed!"
}

# Function to remove symlinks
remove_symlinks() {
    ADDONS_BASE_DIR="/userdata/system/add-ons"
    DEP_DIR="$ADDONS_BASE_DIR/.dep"

    for addon_dir in "$ADDONS_BASE_DIR"/*; do
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
                            echo "Not a symlink or does not exist: $symlink_target. Skipping."
                        fi
                    fi
                done
            fi
        done
    done

    for file in "$DEP_DIR"/*; do
        if [ -f "$file" ]; then
            if [[ "$(basename "$file")" == *lib* ]]; then
                symlink_target="/usr/lib/$(basename "$file")"
            else
                symlink_target="/usr/bin/$(basename "$file")"
            fi

           if [ -L "$symlink_target" ] && [[ "$(readlink "$symlink_target")" == "$file" ]]; then
    echo "Removing symlink: $symlink_target"
    rm "$symlink_target"
else
    echo "Symlink does not point to expected file or not a symlink: $symlink_target. Skipping."
            fi
        fi
    done

    echo "Symlink removal completed!"
}

# Function to check the status of symlinks
check_status() {
    ADDONS_BASE_DIR="/userdata/system/add-ons"

    echo "Checking the status of symlinks..."

    for addon_dir in "$ADDONS_BASE_DIR"/*; do
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
            exit 0
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

    sleep 10
done
