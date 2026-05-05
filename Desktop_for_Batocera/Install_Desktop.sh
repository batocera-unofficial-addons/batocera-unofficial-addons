#!/bin/bash

echo "Desktop for Batocera — Installer"
echo "================================="

TEMP_DIR="/userdata/tmp/Desktop_for_Batocera"
SFS_FILE="$TEMP_DIR/Desktop_for_Batocera.squashfs"
EXTRACT_DIR="$TEMP_DIR/extracted"
ADDON_NAME="desktop"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
DEST_DIR="${ADDON_DIR}/rootfs"
DRL_REMOVER="/userdata/system/configs/bat-drl/Remover_Desktop.sh"
BASE_URL="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/releases/download/AppImages"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  SFS_URL="$BASE_URL/Desktop_for_batocera_8.8.squashfs" ;;
    aarch64) SFS_URL="$BASE_URL/Desktop_for_batocera_8.8_arm64.squashfs" ;;
    *)
        echo "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Detect existing DRL install
if [ -f "$DRL_REMOVER" ]; then
    dialog --title "Existing Desktop Detected" \
        --yesno "An existing Desktop for Batocera (DRL) installation was detected.\n\nIt must be removed before installing the new version.\n\nRun the uninstaller now?" 12 55
    if [ $? -eq 0 ]; then
        echo "Removing old DRL installation..."
        function yad() { return 0; }; export -f yad
        bash "$DRL_REMOVER"
        unset -f yad

        echo "Cleaning up DRL remnants..."
        rm -rf /userdata/system/Desktop
        rm -rf /userdata/system/configs/bat-drl/Desktop
        rm -rf /userdata/system/configs/bat-drl/tint2
        rm -rf /userdata/system/configs/bat-drl/AntiMicroX
        rm -f /userdata/system/configs/bat-drl/Nav_Redist2.joystick.amgp
        rm -rf /userdata/system/add-ons/desktop_drl
        rm -f /userdata/system/services/desktop_drl
        rm -rf /userdata/system/.config/tint2
        rm -rf /userdata/system/.config/jgmenu
        rm -rf /userdata/system/.config/libfm
        rm -rf /userdata/system/.config/pcmanfm
        rm -rf /userdata/system/.config/sublime-text
    else
        echo "Installation cancelled."
        exit 0
    fi
fi

# Detect existing install — back up customisations before updating
BACKUP_DIR="$TEMP_DIR/backup"
IS_UPDATE=0
if [ -d "$ADDON_DIR/rootfs" ]; then
    IS_UPDATE=1
    echo "Existing install detected — backing up customisations..."
    mkdir -p "$BACKUP_DIR"
    [ -d /userdata/system/Desktop ]             && cp -r /userdata/system/Desktop             "$BACKUP_DIR/Desktop"
    [ -f /userdata/system/.config/tint2/tint2rc ] && cp /userdata/system/.config/tint2/tint2rc "$BACKUP_DIR/tint2rc"
    [ -d /userdata/system/.config/jgmenu ]      && cp -r /userdata/system/.config/jgmenu      "$BACKUP_DIR/jgmenu"
    [ -f /userdata/system/.config/pcmanfm/default/desktop-items-0.conf ] && \
        cp /userdata/system/.config/pcmanfm/default/desktop-items-0.conf "$BACKUP_DIR/desktop-items-0.conf"
    PALETTE_FILE="/userdata/system/add-ons/desktop/config/Desktop/theme/current.palette"
    [ -f "$PALETTE_FILE" ] && cp "$PALETTE_FILE" "$BACKUP_DIR/current.palette"

    echo "Stopping desktop service..."
    batocera-services stop desktop
fi

# Create temp directories
mkdir -p "$TEMP_DIR" "$EXTRACT_DIR" "$DEST_DIR"

# Download squashfs
echo "Downloading..."
curl -L -o "$SFS_FILE" "$SFS_URL"

if [ ! -f "$SFS_FILE" ]; then
    echo "Error: Download failed."
    exit 1
fi

# Extract
echo "Extracting..."
unsquashfs -f -d "$EXTRACT_DIR" "$SFS_FILE"

if [ $? -ne 0 ]; then
    echo "Error: Extraction failed."
    rm -rf "$TEMP_DIR"
    exit 1
fi

# userdata content goes directly to /userdata (persistent)
echo "Installing userdata files..."
cp -r "$EXTRACT_DIR/userdata/." /userdata/ 2>/dev/null || true

# Root FS content goes into rootfs for the service to symlink on each boot
echo "Installing root FS files..."
for dir in usr etc lib; do
    [ -d "$EXTRACT_DIR/$dir" ] && cp -r "$EXTRACT_DIR/$dir" "$DEST_DIR/" || true
done

# Icon packs
if [ -d "$EXTRACT_DIR/icons" ]; then
    echo "Installing icon packs..."
    cp -r "$EXTRACT_DIR/icons" "$ADDON_DIR/"
fi

# Restore customisations if updating
if [ "$IS_UPDATE" -eq 1 ]; then
    echo "Restoring customisations..."
    [ -d "$BACKUP_DIR/Desktop" ]       && rm -rf /userdata/system/Desktop && cp -r "$BACKUP_DIR/Desktop" /userdata/system/Desktop
    [ -f "$BACKUP_DIR/tint2rc" ]       && cp "$BACKUP_DIR/tint2rc" /userdata/system/.config/tint2/tint2rc
    [ -d "$BACKUP_DIR/jgmenu" ]        && rm -rf /userdata/system/.config/jgmenu && cp -r "$BACKUP_DIR/jgmenu" /userdata/system/.config/jgmenu
    [ -f "$BACKUP_DIR/desktop-items-0.conf" ] && \
        cp "$BACKUP_DIR/desktop-items-0.conf" /userdata/system/.config/pcmanfm/default/desktop-items-0.conf
    [ -f "$BACKUP_DIR/current.palette" ] && mkdir -p "$(dirname "$PALETTE_FILE")" && cp "$BACKUP_DIR/current.palette" "$PALETTE_FILE"
fi

# Cleanup
echo "Cleaning up..."
rm -rf "$TEMP_DIR"

# Write the desktop service script
echo "Installing desktop service..."
mkdir -p /userdata/system/services
cat << 'SERVICEEOF' > /userdata/system/services/desktop
#!/bin/bash

ADDON_NAME="desktop"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
ROOTFS="${ADDON_DIR}/rootfs"
ICONS_DIR="${ADDON_DIR}/icons"
LOG="/userdata/system/logs/${ADDON_NAME}.log"

log() { echo "$(date): $*" | tee -a "$LOG"; }

link_file() {
    local src="$1"
    local target="${src#${ROOTFS}}"
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        local cur; cur="$(readlink "$target")"
        if [ "$cur" = "$src" ]; then
            return
        else
            log "Conflict: $target -> $cur (expected $src). Skipping."
            return
        fi
    elif [ -e "$target" ]; then
        log "Backing up: $target -> ${target}.bak"
        mv "$target" "${target}.bak"
    fi

    log "Linking: $target -> $src"
    ln -s "$src" "$target"
}

unlink_file() {
    local src="$1"
    local target="${src#${ROOTFS}}"

    if [ -L "$target" ]; then
        local cur; cur="$(readlink "$target")"
        if [ "$cur" = "$src" ]; then
            log "Removing symlink: $target"
            rm "$target"
            [ -e "${target}.bak" ] && { log "Restoring: ${target}.bak"; mv "${target}.bak" "$target"; }
        else
            log "Symlink $target -> $cur, not our file. Skipping."
        fi
    elif [ -e "${target}.bak" ]; then
        log "Orphan backup found — restoring: ${target}.bak"
        mv "${target}.bak" "$target"
    fi
}

apply_symlinks() {
    [ -d "$ROOTFS" ] || { log "ERROR: rootfs missing at $ROOTFS"; exit 1; }
    find "$ROOTFS" \( -type f -o -type l \) \
        ! -path "${ROOTFS}/usr/share/themes/*" \
        ! -path "${ROOTFS}/usr/share/tint2/*/*" \
        ! -path "${ROOTFS}/usr/share/icons/*" \
        ! -path "${ROOTFS}/etc/openbox/rc.xml" \
        | while read -r src; do link_file "$src"; done
    log "Symlink pass complete."
}

remove_symlinks() {
    [ -d "$ROOTFS" ] || { log "rootfs missing, nothing to remove."; return; }
    find "$ROOTFS" \( -type f -o -type l \) \
        ! -path "${ROOTFS}/usr/share/themes/*" \
        ! -path "${ROOTFS}/usr/share/tint2/*/*" \
        ! -path "${ROOTFS}/usr/share/icons/*" \
        ! -path "${ROOTFS}/etc/openbox/rc.xml" \
        | while read -r src; do unlink_file "$src"; done
    log "Symlink removal complete."
}

link_dir_packs() {
    local src_dir="$1" target_parent="$2"
    [ -d "$src_dir" ] || return
    local pack target
    for pack in "$src_dir"/*/; do
        [ -d "$pack" ] || continue
        pack="${pack%/}"
        target="${target_parent}/$(basename "$pack")"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            log "Linking: $target -> $pack"
            ln -s "$pack" "$target"
        fi
    done
}

unlink_dir_packs() {
    local src_dir="$1" target_parent="$2"
    [ -d "$src_dir" ] || return
    local pack target
    for pack in "$src_dir"/*/; do
        [ -d "$pack" ] || continue
        pack="${pack%/}"
        target="${target_parent}/$(basename "$pack")"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$pack" ]; then
            log "Removing symlink: $target"
            rm "$target"
        fi
    done
}

link_files_into_dir() {
    local src_dir="$1" target_dir="$2"
    [ -d "$src_dir" ] || return
    mkdir -p "$target_dir"
    local src target
    for src in "$src_dir"/*; do
        [ -e "$src" ] || continue
        target="${target_dir}/$(basename "$src")"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            log "Linking: $target -> $src"
            ln -s "$src" "$target"
        fi
    done
}

unlink_files_from_dir() {
    local src_dir="$1" target_dir="$2"
    [ -d "$src_dir" ] || return
    local src target
    for src in "$src_dir"/*; do
        [ -e "$src" ] || continue
        target="${target_dir}/$(basename "$src")"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
            log "Removing symlink: $target"
            rm "$target"
        fi
    done
}

link_icon_packs() {
    [ -d "$ICONS_DIR" ] || return
    local pack target
    for pack in "$ICONS_DIR"/*/; do
        [ -d "$pack" ] || continue
        pack="${pack%/}"
        target="/usr/share/icons/$(basename "$pack")"
        if [ ! -e "$target" ] && [ ! -L "$target" ]; then
            log "Linking icon pack: $target -> $pack"
            ln -s "$pack" "$target"
        fi
    done
}

unlink_icon_packs() {
    [ -d "$ICONS_DIR" ] || return
    local pack target
    for pack in "$ICONS_DIR"/*/; do
        [ -d "$pack" ] || continue
        pack="${pack%/}"
        target="/usr/share/icons/$(basename "$pack")"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$pack" ]; then
            log "Removing icon pack symlink: $target"
            rm "$target"
        fi
    done
}

case "$1" in
    start)
        mkdir -p /userdata/system/logs
        log "Starting desktop overlay..."
        apply_symlinks
        link_icon_packs
        link_dir_packs "${ROOTFS}/usr/share/icons" "/usr/share/icons"
        link_files_into_dir "${ROOTFS}/usr/share/icons/batocera" "/usr/share/icons/batocera"
        link_dir_packs "${ROOTFS}/usr/share/themes" "/usr/share/themes"
        link_dir_packs "${ROOTFS}/usr/share/tint2" "/usr/share/tint2"
        ;;
    stop)
        mkdir -p /userdata/system/logs
        log "Stopping desktop overlay..."
        remove_symlinks
        unlink_icon_packs
        unlink_dir_packs "${ROOTFS}/usr/share/icons" "/usr/share/icons"
        unlink_files_from_dir "${ROOTFS}/usr/share/icons/batocera" "/usr/share/icons/batocera"
        unlink_dir_packs "${ROOTFS}/usr/share/themes" "/usr/share/themes"
        unlink_dir_packs "${ROOTFS}/usr/share/tint2" "/usr/share/tint2"
        ;;
    status)
        if [ ! -d "$ROOTFS" ]; then
            echo "desktop: not installed (rootfs missing)."
            exit 1
        fi
        missing=0
        while IFS= read -r src; do
            target="${src#${ROOTFS}}"
            [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ] || missing=$((missing+1))
        done < <(find "$ROOTFS" \( -type f -o -type l \))
        [ "$missing" -eq 0 ] && echo "desktop: all symlinks active." \
                              || echo "desktop: ${missing} symlink(s) missing or broken."
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
SERVICEEOF

chmod +x /userdata/system/services/desktop

# Enable and start the service
batocera-services enable desktop
batocera-services start desktop

# Reapply palette icons after update (service must be running for paths to resolve)
if [ "$IS_UPDATE" -eq 1 ] && [ -f "$PALETTE_FILE" ]; then
    PALETTE_NAME=$(cat "$PALETTE_FILE" | tr -d '[:space:]')
    ICONS_SRC="/usr/share/desktop-palettes/icons/palettes/$PALETTE_NAME"
    if [ -d "$ICONS_SRC" ]; then
        echo "Reapplying palette icons ($PALETTE_NAME)..."
        cp "$ICONS_SRC"/* /usr/share/icons/batocera/ 2>/dev/null || true
    fi
fi

echo ""
if [ "$IS_UPDATE" -eq 1 ]; then
    echo "Update complete."
else
    echo "Installation complete. Please restart for changes to take effect."
fi
