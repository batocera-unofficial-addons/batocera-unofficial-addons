# Function to remove symlinks
remove_symlinks() {
    # Base directory containing add-ons with bin and lib folders
    ADDONS_BASE_DIR="/userdata/system/add-ons"

    # Loop through each subdirectory in the add-ons base directory
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        # Check if this is a directory and contains a 'bin' folder
        if [ -d "$addon_dir/bin" ]; then
            echo "Found bin folder in: $addon_dir"

            # Loop through all executables in the bin folder
            for bin_file in "$addon_dir/bin"/*; do
                if [ -f "$bin_file" ] && [ -x "$bin_file" ]; then
                    # Remove the symlink from /usr/bin if it exists
                    symlink_target="/usr/bin/$(basename "$bin_file")"
                    if [ -L "$symlink_target" ]; then
                        echo "Removing symlink: $symlink_target"
                        rm "$symlink_target"
                    else
                        echo "Symlink does not exist: $symlink_target. Skipping."
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
                    # Remove the symlink from /usr/lib if it exists
                    symlink_target="/usr/lib/$(basename "$lib_file")"
                    if [ -L "$symlink_target" ]; then
                        echo "Removing symlink: $symlink_target"
                        rm "$symlink_target"
                    else
                        echo "Symlink does not exist: $symlink_target. Skipping."
                    fi
                fi
            done
        fi
                # Check if this is a directory and contains a 'lib' folder
        if [ -d "$addon_dir/share" ]; then
            echo "Found lib folder in: $addon_dir"

            # Loop through all files in the lib folder
            for lib_file in "$addon_dir/share"/*; do
                if [ -f "$share_folder" ]; then
                    # Remove the symlink from /usr/lib if it exists
                    symlink_target="/usr/share/$(basename "$share_folder")"
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

    echo "Symlink removal completed!"
}
export -f remove-symlinks

##################################################################################
##################################################################################
##################################################################################

    echo
	echo -e "  # # #"
    echo -e "  #" 
    echo -e "  #   FIGHTCADE2 CLOSED, " 
    echo -e "  #   UNLINKING WINE ENVIRONMENT,"
	
		remove-symlinks 2>/dev/null 

	echo -e "  #   DONE. "
    echo -e "  #" 
	echo -e "  # # #"
	echo
 
exit 0; exit 1; exit 2 
##################################################################################
##################################################################################
##################################################################################
