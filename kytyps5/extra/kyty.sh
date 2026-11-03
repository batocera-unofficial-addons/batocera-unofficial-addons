#!/bin/bash
# Launch wrapper for KytyPS5, called by the kyty generator (or batocera-launch
# emulator on Batocera 44+) with the ROM path.

install_dir="/userdata/system/add-ons/kytyps5"

# Auto-detect the X display (it can be :0 or :1 depending on how X started)
export DISPLAY=:$(ls /tmp/.X11-unix | head -n1 | tr -dc 0-9).0
export QT_QPA_PLATFORM=xcb
unset WAYLAND_DISPLAY
export SDL_VIDEODRIVER=x11

cd "$install_dir" || exit 1

# A game can be a folder; Kyty wants its eboot.bin
target="${@: -1}"
game_path="$target"
if [ -d "$target" ]; then
    if [ -f "$target/eboot.bin" ]; then
        game_path="$target/eboot.bin"
    elif [ -f "$target/sce_module/eboot.bin" ]; then
        game_path="$target/sce_module/eboot.bin"
    fi
fi

extra_flags=()
grep -q AuthenticAMD /proc/cpuinfo && extra_flags+=(--amd-cpu)

# exec keeps Kyty in the foreground so the launcher waits for it
exec "$install_dir/kyty_emulator" --game "$game_path" --fullscreen "${extra_flags[@]}" > /userdata/system/logs/kyty.log 2>&1
