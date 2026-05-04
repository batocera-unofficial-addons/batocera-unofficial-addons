#!/bin/bash
#
# nvidiapatch service script for Batocera
# Symlinks patched nvidia libs from /userdata into root FS on each boot.
# Uses .bak pattern to preserve and restore any pre-existing files.

ADDON_NAME="nvidiapatch"
ADDON_DIR="/userdata/system/add-ons/${ADDON_NAME}"
ROOTFS="${ADDON_DIR}/rootfs"
LOG="/userdata/system/logs/${ADDON_NAME}.log"

log() { echo "$(date): $*" | tee -a "$LOG"; }

link_file() {
    local src="$1"
    local target="${src#${ROOTFS}}"
    mkdir -p "$(dirname "$target")"

    if [ -L "$target" ]; then
        local cur; cur="$(readlink "$target")"
        if [ "$cur" = "$src" ]; then
            return  # already correct
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
    find "$ROOTFS" -type f | while read -r src; do link_file "$src"; done
    log "Symlink pass complete."
}

remove_symlinks() {
    [ -d "$ROOTFS" ] || { log "rootfs missing, nothing to remove."; return; }
    find "$ROOTFS" -type f | while read -r src; do unlink_file "$src"; done
    log "Symlink removal complete."
}

case "$1" in
    start)
        mkdir -p /userdata/system/logs
        log "Starting ${ADDON_NAME} overlay..."
        apply_symlinks
        ;;
    stop)
        mkdir -p /userdata/system/logs
        log "Stopping ${ADDON_NAME} overlay..."
        remove_symlinks
        ;;
    status)
        if [ ! -d "$ROOTFS" ]; then
            echo "${ADDON_NAME}: not installed (rootfs missing)."
            exit 1
        fi
        missing=0
        while IFS= read -r src; do
            target="${src#${ROOTFS}}"
            [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ] || missing=$((missing+1))
        done < <(find "$ROOTFS" -type f)
        [ "$missing" -eq 0 ] && echo "${ADDON_NAME}: all symlinks active." \
                              || echo "${ADDON_NAME}: ${missing} symlink(s) missing or broken."
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
