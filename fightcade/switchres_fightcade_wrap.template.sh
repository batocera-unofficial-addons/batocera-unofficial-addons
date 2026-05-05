#!/bin/bash
# Installed to fightcade/extra/switchres_fightcade_wrap.sh by fightcade.sh (sed replaces __FIGHTCADE_ADDON__).
# Routes all fcade:// URLs (test game, online, training, replay): Switchres + emulator config patch + fcade.sh + wait + restore.
fightcade_pick_display() {
    [ -S /tmp/.X11-unix/X0 ] && {
        echo ":0.0"
        return
    }
    [ -S /tmp/.X11-unix/X1 ] && {
        echo ":1.0"
        return
    }
    echo ":0.0"
}
export DISPLAY=$(fightcade_pick_display)

FIGHTCADE_ADDON="__FIGHTCADE_ADDON__"
FCADE_SH="${FIGHTCADE_ADDON}/Fightcade/emulator/fcade.sh"
EMU_BASE="${FIGHTCADE_ADDON}/Fightcade/emulator"

W=""; H=""; R=""

fightcade_should_use_switchres() {
    [ -x /usr/bin/switchres ] || return 1
    # Kill switch: touch this file to bypass Switchres entirely.
    [ -f /userdata/system/configs/fightcade-switchres.disable ] && return 1
    local dm
    dm=$(batocera-resolution getDisplayMode 2>/dev/null) || return 1
    [ "$dm" = "xorg" ] || return 1
    if [ -f /userdata/system/configs/fightcade-switchres.force ]; then
        return 0
    fi
    local res w
    res=$(batocera-resolution currentResolution 2>/dev/null) || return 1
    w="${res%%x*}"
    case "$w" in
        '' | *[!0-9]*) return 1 ;;
    esac
    [ "$w" -lt 1024 ] || return 1
    return 0
}

mame_xml_raw() {
    /usr/bin/mame/mame -listxml "$1" 2>/dev/null
}

parse_mame_xml_dims() {
    local xml="$1"
    [ -z "$xml" ] && return 1
    W=$(echo "$xml" | sed -n 's/.*width="\([0-9]*\)".*/\1/p')
    H=$(echo "$xml" | sed -n 's/.*height="\([0-9]*\)".*/\1/p')
    R=$(echo "$xml" | sed -n 's/.*refresh="\([0-9.]*\)".*/\1/p')
    [ -n "$W" ] && [ -n "$H" ] && [ -n "$R" ]
}

resolve_rom_dims() {
    local emu="$1" rom="$2"
    local full_xml display_xml
    W=""; H=""; R=""

    # Console-prefixed ROMs: use hardcoded fallback directly.
    # MAME contains arcade versions with different specs (e.g. arcade Contra
    # is 280x224@59.19 but NES Contra is 256x240@60.10).
    case "$rom" in
        md_*)   W=320; H=224; R=59.92; return 0 ;;
        nes_*)  W=256; H=240; R=60.10; return 0 ;;
        pce_*)  W=256; H=240; R=59.82; return 0 ;;
        tg_*)   W=256; H=240; R=59.82; return 0 ;;
        sms_*)  W=256; H=192; R=59.92; return 0 ;;
        gg_*)   W=160; H=144; R=59.92; return 0 ;;
        cv_*)   W=256; H=192; R=59.92; return 0 ;;
        sg1k_*) W=256; H=192; R=59.92; return 0 ;;
        msx_*)  W=256; H=192; R=59.92; return 0 ;;
        snes_*) W=256; H=224; R=60.10; return 0 ;;
    esac

    # Arcade ROMs: MAME lookup for exact native resolution.
    full_xml=$(mame_xml_raw "$rom")
    display_xml=$(echo "$full_xml" | grep '<display ')
    if parse_mame_xml_dims "$display_xml"; then
        # Neo Geo: MAME reports 320x224 but active pixel area is 304x224.
        if [ "$W" = "320" ] && [ "$H" = "224" ] && echo "$full_xml" | grep -q 'romof="neogeo"'; then
            W=304
        fi
        return 0
    fi

    case "$emu" in
        snes9x)  W=256; H=224; R=60.10; return 0 ;;
        flycast) W=640; H=480; R=59.94; return 0 ;;
    esac

    return 1
}

ini_path_for_emu() {
    local emu="$1"
    case "$emu" in
        fbneo)
            echo "$EMU_BASE/fbneo/config/fcadefbneo.ini"
            ;;
        ggpofba)
            echo "$EMU_BASE/ggpofba/config/ggpofba.ini"
            ;;
        *)
            echo ""
            ;;
    esac
}

snes9x_conf_path() {
    echo "$EMU_BASE/snes9x/fcadesnes9x.conf"
}

patch_wine_ini() {
    local ini="$1" w="$2" h="$3"
    [ -n "$ini" ] || return 0
    [ -f "$ini" ] || return 0
    cp "$ini" "${ini}.bak.switchres"
    sed -i "s/^nVidHorWidth .*/nVidHorWidth $w/" "$ini"
    sed -i "s/^nVidHorHeight .*/nVidHorHeight $h/" "$ini"
    sed -i "s/^bVidAutoSwitchFull .*/bVidAutoSwitchFull 1/" "$ini"
    sed -i "s/^bVidDX9WinFullscreen .*/bVidDX9WinFullscreen 1/" "$ini"
    sed -i "s/^bVidArcaderesHor .*/bVidArcaderesHor 0/" "$ini"
    sed -i "s/^nVidScrnAspectX .*/nVidScrnAspectX 4/" "$ini"
    sed -i "s/^nVidScrnAspectY .*/nVidScrnAspectY 3/" "$ini"
    sed -i "s/^bVidCorrectAspect .*/bVidCorrectAspect 0/" "$ini"
    sed -i "s/^bVidFullStretch .*/bVidFullStretch 1/" "$ini"
}

restore_ini() {
    local ini="$1"
    [ -n "$ini" ] || return 0
    if [ -f "${ini}.bak.switchres" ]; then
        mv -f "${ini}.bak.switchres" "$ini"
    fi
}

patch_snes9x_conf() {
    local conf="$1" w="$2" h="$3"
    [ -f "$conf" ] || return 0
    cp "$conf" "${conf}.bak.switchres"
    sed -i 's/^\([[:space:]]*Fullscreen:Enabled[[:space:]]*=\).*/\1 TRUE/' "$conf"
    sed -i "s/^\([[:space:]]*Fullscreen:Width[[:space:]]*=\).*/\1 $w/" "$conf"
    sed -i "s/^\([[:space:]]*Fullscreen:Height[[:space:]]*=\).*/\1 $h/" "$conf"
    sed -i 's/^\([[:space:]]*HideMenu[[:space:]]*=\).*/\1 TRUE/' "$conf"
    sed -i 's/^\([[:space:]]*Fullscreen:EmulateFullscreen[[:space:]]*=\).*/\1 TRUE/' "$conf"
    sed -i 's/^\([[:space:]]*Stretch:MaintainAspectRatio[[:space:]]*=\).*/\1 FALSE/' "$conf"
    sed -i 's/^\([[:space:]]*Stretch:BilinearFilter[[:space:]]*=\).*/\1 FALSE/' "$conf"
    sed -i "s/^\([[:space:]]*OutputMethod[[:space:]]*=\).*/\1 0/" "$conf"
}

restore_snes9x_conf() {
    local conf="$1"
    if [ -f "${conf}.bak.switchres" ]; then
        mv -f "${conf}.bak.switchres" "$conf"
    fi
}

flycast_cfg_path() {
    echo "$EMU_BASE/flycast/emu.cfg"
}

patch_flycast_cfg() {
    local cfg="$1"
    [ -f "$cfg" ] || return 0
    cp "$cfg" "${cfg}.bak.switchres"
    sed -i 's/^fullscreen = .*/fullscreen = yes/' "$cfg"
    sed -i 's/^rend\.vsync = .*/rend.vsync = yes/' "$cfg"
}

restore_flycast_cfg() {
    local cfg="$1"
    if [ -f "${cfg}.bak.switchres" ]; then
        mv -f "${cfg}.bak.switchres" "$cfg"
    fi
}

# True when display matches what we saved at Fightcade launch (any menu: 240p, 576i, 480i, etc.).
# After Switchres, batocera-resolution currentMode/currentResolution are often empty (no "*" in listModes);
# fall back to parsing "current WxH" from xrandr so restore can succeed.
display_matches_snapshot() {
    local want_mode="$1"
    local want_res="$2"
    local cm cr xr
    cm=$(batocera-resolution currentMode 2>/dev/null)
    cr=$(batocera-resolution currentResolution 2>/dev/null)
    if [ -z "$cr" ]; then
        xr=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
        cr=$xr
    fi
    if [ -n "$want_mode" ] && [ -n "$cm" ] && [ "$cm" = "$want_mode" ]; then
        return 0
    fi
    if [ -n "$want_res" ] && [ -n "$cr" ] && [ "$cr" = "$want_res" ]; then
        return 0
    fi
    return 1
}

# Poll until snapshot matches (exit as soon as X reports menu timing).
poll_snapshot_match() {
    local want_mode="$1"
    local want_res="$2"
    local n
    for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        display_matches_snapshot "$want_mode" "$want_res" && return 0
        sleep 0.05
    done
    return 1
}

# Same parsing as batocera-resolution.xorg setMode: WxHz… -> xrandr --mode W --rate Hz…
restore_via_xrandr_from_pre_mode() {
    local pre="$1"
    local out partres parthz
    [ -z "$pre" ] && return 1
    out=$(batocera-resolution currentOutput 2>/dev/null)
    [ -z "$out" ] && out="DP-1"
    if echo "$pre" | grep -q '\.'; then
        partres=$(echo "$pre" | cut -d'.' -f1)
        parthz=$(echo "$pre" | cut -d'.' -f2-)
        xrandr --output "$out" --mode "$partres" --rate "$parthz" 2>/dev/null || return 1
    else
        xrandr --output "$out" --mode "$pre" 2>/dev/null || return 1
    fi
    return 0
}

restore_display_mode() {
    local pre="$1"
    local snapshot_res="$2"
    local i cr w out
    export DISPLAY=$(fightcade_pick_display)
    if [ -z "$pre" ] && [ -z "$snapshot_res" ]; then
        # No snapshot (edge case): still try ES/boot re-init so X never stays on SR modeline.
        batocera-resolution minTomaxResolution 2>/dev/null || true
        sleep 0.35
        return 0
    fi

    # Fast path: xrandr usually leaves Switchres modes faster than setMode alone.
    [ -n "$pre" ] && restore_via_xrandr_from_pre_mode "$pre" || true
    poll_snapshot_match "$pre" "$snapshot_res" && return 0

    # Same order as manual SSH recover that worked: minTomax re-syncs listModes / ES timing early.
    batocera-resolution minTomaxResolution 2>/dev/null || true
    sleep 0.35
    poll_snapshot_match "$pre" "$snapshot_res" && return 0

    for i in 1 2 3 4 5 6 7 8 9 10; do
        [ -n "$pre" ] && batocera-resolution setMode "$pre" 2>/dev/null || true
        poll_snapshot_match "$pre" "$snapshot_res" && return 0
        sleep 0.2
        # setMode often fails while X is still on a Switchres modeline; xrandr with PRE_MODE works sooner.
        case "$i" in
            1|3|5|7)
                [ -n "$pre" ] && restore_via_xrandr_from_pre_mode "$pre" || true
                poll_snapshot_match "$pre" "$snapshot_res" && return 0
                ;;
        esac
    done

    # Last resort when setMode cannot escape Switchres modes: drive xrandr using the same PRE_MODE string (no hardcoded resolution).
    [ -n "$pre" ] && restore_via_xrandr_from_pre_mode "$pre" || true
    poll_snapshot_match "$pre" "$snapshot_res" && return 0

    # Re-init from es.resolution / boot when X is wedged (no listModes marker); avoids black until reboot.
    batocera-resolution minTomaxResolution 2>/dev/null || true
    sleep 0.5
    if display_matches_snapshot "$pre" "$snapshot_res"; then
        return 0
    fi

    # Still stuck on arcade width (common black-screen state): force Batocera menu-class timing once.
    cr=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
    w="${cr%%x*}"
    case "$w" in
        '' | *[!0-9]*) ;;
        *)
            if [ "$w" -lt 600 ] 2>/dev/null; then
                out=$(batocera-resolution currentOutput 2>/dev/null)
                [ -z "$out" ] && out="DP-1"
                xrandr --output "$out" --mode 641x480i --rate 59.98 2>/dev/null || true
                sleep 0.35
                poll_snapshot_match "$pre" "$snapshot_res" && return 0
                batocera-resolution minTomaxResolution 2>/dev/null || true
                sleep 0.35
            fi
            ;;
    esac
}

# Refresh PRE_MODE / PRE_RES from Batocera + xrandr (globals PRE_MODE, PRE_RES).
fightcade_refresh_menu_snapshot() {
    PRE_MODE=$(batocera-resolution currentMode 2>/dev/null)
    PRE_RES=$(batocera-resolution currentResolution 2>/dev/null)
    if [ -z "$PRE_RES" ]; then
        PRE_RES=$(xrandr 2>/dev/null | sed -n 's/.*current \([0-9]*\) x \([0-9]*\).*/\1x\2/p' | head -1)
    fi
}

# Second TEST GAME in-session: X may still be arcade geometry. If PRE_RES looks like stuck game
# timing use minTomax then re-snapshot. Skip normal CRT menus: 320x240 has height greater than 224.
fightcade_ensure_menu_baseline() {
    local w h
    fightcade_refresh_menu_snapshot
    w="${PRE_RES%%x*}"
    h="${PRE_RES##*x}"
    case "$w" in
        '' | *[!0-9]*) return 0 ;;
    esac
    case "$h" in
        '' | *[!0-9]*) return 0 ;;
    esac
    if [ "$w" -lt 512 ] 2>/dev/null && [ "$h" -le 224 ] 2>/dev/null; then
        batocera-resolution minTomaxResolution 2>/dev/null || true
        sleep 0.6
        fightcade_refresh_menu_snapshot
    fi
}

# After `switchres -s -k`, xrandr sometimes lists modes but the output has no starred active
# mode (duplicate add_mode / round-trip race). CRT stays black while Wine runs. Force the SR mode on.
fightcade_reassert_switchres_output() {
    local out mode w h i
    w="$1"
    h="$2"
    [ -z "$w" ] || [ -z "$h" ] && return 0
    export DISPLAY=$(fightcade_pick_display)
    out=$(batocera-resolution currentOutput 2>/dev/null)
    [ -z "$out" ] && out="DP-1"
    for i in 1 2 3 4 5 6; do
        mode=$(xrandr 2>/dev/null | awk -v W="$w" -v H="$h" '$1 ~ /^SR-/ && index($1, W "x" H) { print $1; exit }')
        [ -z "$mode" ] && mode=$(xrandr 2>/dev/null | awk '$1 ~ /^SR-/ { print $1; exit }')
        [ -z "$mode" ] && return 0
        xrandr --output "$out" --mode "$mode" 2>/dev/null || true
        sleep 0.22
        if xrandr 2>/dev/null | head -1 | grep -q "current ${w} x ${h}"; then
            return 0
        fi
    done
}

# ES round-trip / second session: Switchres modes from prior launches stay in xrandr.
# Next `switchres -s -k` hits duplicate add_mode; RandR ends up with no starred mode.
# delmode can fail if SR-* is still active: fightcade_prep_x_before_switchres sets menu
# timing first, then we strip SR-* twice.
fightcade_drop_stale_switchres_modes() {
    local out m round
    export DISPLAY=$(fightcade_pick_display)
    out=$(batocera-resolution currentOutput 2>/dev/null)
    [ -z "$out" ] && out="DP-1"
    for round in 1 2; do
        for m in $(xrandr 2>/dev/null | awk '$1 ~ /^SR-/ { print $1 }'); do
            [ -z "$m" ] && continue
            xrandr --delmode "$out" "$m" 2>/dev/null || true
            xrandr --rmmode "$m" 2>/dev/null || true
        done
        sleep 0.12
    done
    sleep 0.15
}

# Before every Switchres apply: leave arcade SR timing and refresh PRE_* so restore targets stay valid.
# Same-session consecutive launches: RandR may still hold SR-* from the last game;
# minTomax re-syncs output before delmode (avoids BadAccess / duplicate add_mode black screen).
fightcade_prep_x_before_switchres() {
    export DISPLAY=$(fightcade_pick_display)
    batocera-resolution minTomaxResolution 2>/dev/null || true
    sleep 0.5
    fightcade_refresh_menu_snapshot
}

# Wine may start several seconds after fcade.sh returns. If we restore before the emu exists,
# we yank X back to menu timing during load → black screen / broken raster.
EMU_Pgrep_RE='fcadefbneo\.exe|ggpofba-ng\.exe|fcadesnes9x\.exe|flycast\.elf'

fightcade_kill_wine_orphans() {
    pkill -f "fcadefbneo" 2>/dev/null || true
    pkill -f "ggpofba" 2>/dev/null || true
    pkill -f "fcadesnes9x" 2>/dev/null || true
    pkill -f "flycast\.elf" 2>/dev/null || true
    pkill -f "wineserver.*__FIGHTCADE_ADDON__" 2>/dev/null || true
    pkill -f "winedevice" 2>/dev/null || true
    sleep 0.5
    pkill -9 -f "fcadefbneo" 2>/dev/null || true
    pkill -9 -f "ggpofba" 2>/dev/null || true
    pkill -9 -f "fcadesnes9x" 2>/dev/null || true
    pkill -9 -f "wineserver.*__FIGHTCADE_ADDON__" 2>/dev/null || true
    pkill -9 -f "winedevice" 2>/dev/null || true
}

emu_has_visible_window() {
    local wins
    wins=$(DISPLAY=$(fightcade_pick_display) wmctrl -l 2>/dev/null | grep -i -E 'FBNeo|fbneo|ggpo|snes9x|flycast|Error')
    [ -z "$wins" ] && return 1
    # FBNeo idle with no game means launch failed; safe to restore.
    echo "$wins" | grep -qi 'no game loaded' && return 1
    return 0
}

fightcade_kill_stale_wrappers() {
    local my_pid=$$
    local pid
    for pid in $(pgrep -f 'switchres_fightcade_wrap\.sh' 2>/dev/null); do
        [ "$pid" = "$my_pid" ] && continue
        kill "$pid" 2>/dev/null || true
    done
    sleep 0.2
}

switchres_fightcade_wrap() {
    local URL="$1"
    URL="${URL%%#*}"
    URL="${URL%%\?*}"

    fightcade_kill_stale_wrappers

    if ! fightcade_should_use_switchres; then
        exec "$FCADE_SH" "$URL"
    fi

    local emu rom ini PRE_MODE PRE_RES
    if [[ "$URL" =~ fcade://[^/]+/([^/]+)/([^/]+) ]]; then
        emu="${BASH_REMATCH[1]}"
        rom="${BASH_REMATCH[2]}"
    else
        exec "$FCADE_SH" "$URL"
    fi

    if ! resolve_rom_dims "$emu" "$rom"; then
        exec "$FCADE_SH" "$URL"
    fi

    ini=$(ini_path_for_emu "$emu")
    local snes9x_conf=""
    [ "$emu" = "snes9x" ] && snes9x_conf=$(snes9x_conf_path)
    local flycast_cfg=""
    [ "$emu" = "flycast" ] && flycast_cfg=$(flycast_cfg_path)

    # Patch emulator configs BEFORE calling fcade so the emulator reads correct
    # settings when it starts. This has no visible effect on the display.
    case "$emu" in
        fbneo|ggpofba)
            patch_wine_ini "$ini" "$W" "$H"
            ;;
        snes9x)
            patch_snes9x_conf "$snes9x_conf" "$W" "$H"
            ;;
        flycast)
            patch_flycast_cfg "$flycast_cfg"
            ;;
    esac

    # Let fcade handle the URL (download ROM, launch emulator, etc.).
    "$FCADE_SH" "$URL"

    # fc2-electron fires xdg-open on BOTH room join and TEST GAME.
    # Detect which case by waiting for an actual emulator process to appear.
    # Room join/download never spawns an emulator; exit without touching display.
    local emu_deadline=$((SECONDS + 15))
    local emu_found=0
    while [ "$SECONDS" -lt "$emu_deadline" ]; do
        if pgrep -f "$EMU_Pgrep_RE" >/dev/null 2>&1; then
            emu_found=1
            break
        fi
        sleep 0.25
    done

    if [ "$emu_found" -eq 0 ]; then
        restore_ini "$ini"
        restore_snes9x_conf "$snes9x_conf"
        restore_flycast_cfg "$flycast_cfg"
        return 0
    fi

    # Emulator is running: apply Switchres now.
    export DISPLAY=$(fightcade_pick_display)
    fightcade_ensure_menu_baseline
    fightcade_prep_x_before_switchres

    FIGHTCADE_SWITCHRES_ENGAGED=1
    FIGHTCADE_RESTORE_DONE=0
    FIGHTCADE_PRE_MODE="$PRE_MODE"
    FIGHTCADE_PRE_RES="$PRE_RES"
    FIGHTCADE_INI_PATH="$ini"
    FIGHTCADE_SNES9X_CONF="$snes9x_conf"
    FIGHTCADE_FLYCAST_CFG="$flycast_cfg"

    fightcade_trap_restore() {
        [ "${FIGHTCADE_SWITCHRES_ENGAGED:-0}" != 1 ] && return 0
        [ "${FIGHTCADE_RESTORE_DONE:-0}" = 1 ] && return 0
        export DISPLAY=$(fightcade_pick_display)
        fightcade_kill_wine_orphans
        restore_ini "${FIGHTCADE_INI_PATH}"
        restore_snes9x_conf "${FIGHTCADE_SNES9X_CONF}"
        restore_flycast_cfg "${FIGHTCADE_FLYCAST_CFG}"
        restore_display_mode "${FIGHTCADE_PRE_MODE}" "${FIGHTCADE_PRE_RES}"
    }
    trap 'fightcade_trap_restore' EXIT INT TERM HUP

    fightcade_drop_stale_switchres_modes

    /usr/bin/switchres "$W" "$H" "$R" -s -k 2>&1 || true
    fightcade_reassert_switchres_output "$W" "$H"
    sleep 4
    fightcade_reassert_switchres_output "$W" "$H"

    # Emulator was already detected; skip the initial wait loop and go straight
    # to monitoring for exit (process death or all windows closed).
    while pgrep -f "$EMU_Pgrep_RE" >/dev/null 2>&1; do
        if ! emu_has_visible_window; then
            sleep 1
            if ! emu_has_visible_window; then
                break
            fi
        fi
        sleep 0.4
    done
    sleep 3
    if pgrep -f "$EMU_Pgrep_RE" >/dev/null 2>&1 && ! emu_has_visible_window; then
        : # Process alive but no windows: kill below.
    elif pgrep -f "$EMU_Pgrep_RE" >/dev/null 2>&1; then
        while pgrep -f "$EMU_Pgrep_RE" >/dev/null 2>&1; do
            if ! emu_has_visible_window; then
                sleep 1
                emu_has_visible_window || break
            fi
            sleep 0.4
        done
    fi
    sleep 0.45
    fightcade_kill_wine_orphans

    restore_ini "$ini"
    restore_snes9x_conf "$snes9x_conf"
    restore_flycast_cfg "$flycast_cfg"
    restore_display_mode "$PRE_MODE" "$PRE_RES"

    FIGHTCADE_RESTORE_DONE=1
    trap - EXIT INT TERM HUP
}

switchres_fightcade_wrap "$@"
