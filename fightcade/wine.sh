#!/bin/bash

# Function to create symlinks
create_symlinks() {
    # Base directory containing add-ons with bin and lib folders
    ADDONS_BASE_DIR="/usr/wine/ge-custom"

    # Loop through each subdirectory in the add-ons base directory
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        # Check if this is a directory and contains a 'bin' folder
        if [ -d "$addon_dir/bin" ]; then
            echo "Found bin folder in: $addon_dir"

            # Loop through all executables in the bin folder
            for bin_file in "$addon_dir/bin"/*; do
                if [ -f "$bin_file" ] && [ -x "$bin_file" ]; then
                    # Create a symlink in /usr/bin if it doesn't already exist
                    symlink_target="/usr/bin/$(basename "$bin_file")"
                    if [ ! -L "$symlink_target" ]; then
                        echo "Creating symlink: $symlink_target -> $bin_file"
                        ln -s "$bin_file" "$symlink_target"
                    else
                        echo "Symlink already exists: $symlink_target. Skipping."
                    fi
                fi
            done
        fi

        # Check if this is a directory and contains a 'lib' folder
        if [ -d "$addon_dir/lib" ]; then
            echo "Found lib folder in: $addon_dir"

            # Loop through all files in the lib folder
            for lib_file in "$addon_dir/lib"/*; do
                if [ -f "$lib_file" ]; then
                    # Create a symlink in /usr/lib if it doesn't already exist
                    symlink_target="/usr/lib/$(basename "$lib_file")"
                    if [ ! -L "$symlink_target" ]; then
                        echo "Creating symlink: $symlink_target -> $lib_file"
                        ln -s "$lib_file" "$symlink_target"
                    else
                        echo "Symlink already exists: $symlink_target. Skipping."
                    fi
                fi
            done
        fi
# Check if this is a directory and contains a 'share' folder
        if [ -d "$addon_dir/share" ]; then
            echo "Found share folder in: $addon_dir"

            # Loop through all files in the lib folder
            for share_folder in "$addon_dir/share"/*; do
                if [ -f "$share_file" ]; then
                    # Create a symlink in /usr/lib if it doesn't already exist
                    symlink_target="/usr/share/$(basename "$share_folder")"
                    if [ ! -L "$symlink_target" ]; then
                        echo "Creating symlink: $symlink_target -> $share_folder"
                        ln -s "$share_folder" "$symlink_target"
                    else
                        echo "Symlink already exists: $symlink_target. Skipping."
                    fi
                fi
            done
        fi
    done

    echo "Symlink creation completed!"
}
export -f create-symlinks 

##################################################################################
##################################################################################
##################################################################################

    echo
	echo -e "  # # #"
    echo -e "  #" 
    echo -e "  #   STARTING WINE ENVIRONMENT FOR BATOCERA"
	
		create-symlinks 2>/dev/null

	echo -e "  #   READY: $(/usr/bin/wine --version)"
    echo -e "  #" 
	echo -e "  # # #"
	echo
 
##################################################################################
##################################################################################
##################################################################################
