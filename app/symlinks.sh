#!/bin/bash
# Updated 11/12/25

# Enable safe file globbing
shopt -s nullglob

ADDONS_BASE_DIR="/userdata/system/add-ons"
DEP_DIR="$ADDONS_BASE_DIR/.dep"

# Helper: create a single symlink with correct mode
create_one_symlink() {
    local file="$1"
    local target_dir="$2"

    # Set permissions based on target dir
    if [[ "$target_dir" == "/usr/bin" ]]; then
        chmod +x "$file"
    else
        chmod a+r "$file"
    fi

    local symlink_target="$target_dir/$(basename "$file")"

    if [ -e "$symlink_target" ]; then
        if [ -L "$symlink_target" ]; then
            # Already a symlink; check where it points
            local link_target
            link_target="$(readlink "$symlink_target")"
            if [[ "$link_target" == "$file" ]]; then
                echo "Symlink already exists: $symlink_target -> $link_target. Skipping."
            else
                echo "Symlink name conflict: $symlink_target points to $link_target, expected $file. Skipping."
            fi
        else
            echo "File exists at target location: $symlink_target. Skipping."
        fi
    else
        echo "Creating symlink: $symlink_target -> $file"
        ln -s "$file" "$symlink_target"
    fi
}

# Helper: remove a single symlink (only if it points to this file)
remove_one_symlink() {
    local file="$1"
    local target_dir="$2"

    local symlink_target="$target_dir/$(basename "$file")"

    if [ -L "$symlink_target" ]; then
        local link_target
        link_target="$(readlink "$symlink_target")"
        if [[ "$link_target" == "$file" ]]; then
            echo "Removing symlink: $symlink_target"
            rm "$symlink_target"
        else
            echo "Symlink $symlink_target does not point to $file (points to $link_target). Skipping."
        fi
    elif [ -e "$symlink_target" ]; then
        echo "Non-symlink file exists at $symlink_target. Skipping."
    else
        echo "No symlink at $symlink_target. Skipping."
    fi
}

create_symlinks() {
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        [ -d "$addon_dir" ] || continue
        for folder in bin lib; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Scanning $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    [ -f "$file" ] || continue
                    local target_dir="/usr/bin"
                    [[ "$folder" == "lib" ]] && target_dir="/usr/lib"
                    create_one_symlink "$file" "$target_dir"
                done
            fi
        done
    done

    if [ -d "$DEP_DIR" ]; then
        echo "Scanning .dep folder..."
        for file in "$DEP_DIR"/*; do
            [ -f "$file" ] || continue
            local target_dir="/usr/bin"
            [[ "$(basename "$file")" == *lib* ]] && target_dir="/usr/lib"
            create_one_symlink "$file" "$target_dir"
        done
    fi

    echo "Symlink creation pass completed!"
}

remove_symlinks() {
    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        [ -d "$addon_dir" ] || continue
        for folder in bin lib; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Scanning $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    [ -f "$file" ] || continue
                    local target_dir="/usr/bin"
                    [[ "$folder" == "lib" ]] && target_dir="/usr/lib"
                    remove_one_symlink "$file" "$target_dir"
                done
            fi
        done
    done

    if [ -d "$DEP_DIR" ]; then
        echo "Scanning .dep folder..."
        for file in "$DEP_DIR"/*; do
            [ -f "$file" ] || continue
            local target_dir="/usr/bin"
            [[ "$(basename "$file")" == *lib* ]] && target_dir="/usr/lib"
            remove_one_symlink "$file" "$target_dir"
        done
    fi

    echo "Symlink removal pass completed!"
}

check_status() {
    echo "Checking the status of symlinks..."

    for addon_dir in "$ADDONS_BASE_DIR"/*; do
        [ -d "$addon_dir" ] || continue
        for folder in bin lib; do
            if [ -d "$addon_dir/$folder" ]; then
                echo "Scanning $folder folder in: $addon_dir"
                for file in "$addon_dir/$folder"/*; do
                    [ -f "$file" ] || continue
                    local target_dir="/usr/bin"
                    [[ "$folder" == "lib" ]] && target_dir="/usr/lib"
                    local symlink_target="$target_dir/$(basename "$file")"

                    if [ -L "$symlink_target" ]; then
                        local link_target
                        link_target="$(readlink "$symlink_target")"
                        echo "Symlink exists: $symlink_target -> $link_target"
                    elif [ -e "$symlink_target" ]; then
                        echo "Non-symlink file at: $symlink_target"
                    else
                        echo "Missing: $symlink_target"
                    fi
                done
            fi
        done
    done

    if [ -d "$DEP_DIR" ]; then
        echo "Checking .dep folder..."
        for file in "$DEP_DIR"/*; do
            [ -f "$file" ] || continue
            local target_dir="/usr/bin"
            [[ "$(basename "$file")" == *lib* ]] && target_dir="/usr/lib"
            local symlink_target="$target_dir/$(basename "$file")"

            if [ -L "$symlink_target" ]; then
                local link_target
                link_target="$(readlink "$symlink_target")"
                echo "Symlink exists: $symlink_target -> $link_target"
            elif [ -e "$symlink_target" ]; then
                echo "Non-symlink file at: $symlink_target"
            else
                echo "Missing: $symlink_target"
            fi
        done
    fi
}

watch_loop() {
    echo "Entering watch loop (interval: ${WATCH_INTERVAL:-10}s)..."
    while true; do
        create_symlinks
        sleep "${WATCH_INTERVAL:-10}"
    done
}

case "$1" in
    start)
        # If the service gets SIGTERM/SIGINT (e.g. Batocera stops it),
        # clean up symlinks before exiting.
        trap 'echo "Received stop signal, cleaning up symlinks..."; remove_symlinks; exit 0' SIGINT SIGTERM
        echo "Starting symlink manager..."
        create_symlinks
        watch_loop
        ;;
    stop)
        echo "Stopping symlink manager (one-shot cleanup)..."
        remove_symlinks
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
