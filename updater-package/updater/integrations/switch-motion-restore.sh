#!/bin/bash

LOG="/tmp/restore-switch-motion.log"
RYU="/userdata/system/switch/configgen/generators/ryujinxGenerator.py"
EDEN="/userdata/system/switch/configgen/generators/edenGenerator.py"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"
}

log "Starting Switch motion persistence check"

#
# 1. Global DSU/Cemuhook provider
#
if [ -d /userdata/extra/motion_evdev ]; then
    batocera-services enable motion_evdev >/dev/null 2>&1 || true

    if pgrep -x evdevhook2 >/dev/null 2>&1; then
        log "motion_evdev already running"
    else
        batocera-services start motion_evdev >/dev/null 2>&1 || true
        sleep 1

        if pgrep -x evdevhook2 >/dev/null 2>&1; then
            log "motion_evdev started"
        else
            log "WARNING: motion_evdev did not start"
        fi
    fi
else
    log "WARNING: /userdata/extra/motion_evdev missing"
fi

#
# 2. Ryujinx / Nextendo
#
if [ -f "$RYU" ]; then

python3 - <<'PY'
from pathlib import Path

p = Path(
    "/userdata/system/switch/configgen/generators/"
    "ryujinxGenerator.py"
)

text = p.read_text()
changed = False

desired_marker = "# BUA global DSU/CemuHook motion integration"

desired = '''        # BUA global DSU/CemuHook motion integration
        # evdevhook2 publishes the physical controller IMU on localhost:26766.
        for controller in data.get("input_config", []):
            motion = controller.get("motion")
            if isinstance(motion, dict):
                controller["motion"] = {
                    "motion_backend": "CemuHook",
                    "sensitivity": 100,
                    "gyro_deadzone": 1,
                    "enable_motion": True,
                    "slot": 0,
                    "alt_slot": 0,
                    "mirror_input": True,
                    "dsu_server_host": "127.0.0.1",
                    "dsu_server_port": 26766
                }
'''

current = '''        # Universal DSU/CemuHook motion configuration.
        # evdevhook2 publishes the physical controller IMU on localhost:26766.
        for index, controller in enumerate(data.get("input_config", [])):
            motion = controller.get("motion")
            if isinstance(motion, dict):
                controller["motion"] = {
                    "motion_backend": "CemuHook",
                    "sensitivity": 100,
                    "gyro_deadzone": 1,
                    "enable_motion": True,
                    "slot": 0,
                    "alt_slot": 0,
                    "mirror_input": True,
                    "dsu_server_host": "127.0.0.1",
                    "dsu_server_port": 26766
                }
'''

old_native = '''        # Universal controller motion configuration.
        # Apply native GamepadDriver motion to every generated controller
        # that exposes a motion configuration, independent of its input backend.
        for controller in data.get("input_config", []):
            motion = controller.get("motion")
            if isinstance(motion, dict):
                motion["motion_backend"] = "GamepadDriver"
                motion["enable_motion"] = True
                motion["sensitivity"] = 100
                motion["gyro_deadzone"] = 1
'''

if desired_marker in text:
    print("Ryujinx DSU motion already correct")

elif current in text:
    text = text.replace(current, desired, 1)
    changed = True
    print("Normalized existing Ryujinx DSU motion block")

elif old_native in text:
    text = text.replace(old_native, desired, 1)
    changed = True
    print("Replaced Ryujinx native motion block with DSU")

else:
    print(
        "WARNING: Ryujinx motion insertion block not recognized; "
        "leaving generator unchanged"
    )

compile(text, str(p), "exec")

if changed:
    p.write_text(text)
PY

    if python3 -m py_compile "$RYU" 2>/dev/null; then
        log "Ryujinx motion integration syntax OK"
    else
        log "ERROR: Ryujinx generator failed syntax check"
    fi
else
    log "WARNING: Ryujinx generator missing"
fi

#
# 3. Eden / Citron
#
if [ -f "$EDEN" ]; then

python3 - <<'PY'
from pathlib import Path

p = Path(
    "/userdata/system/switch/configgen/generators/"
    "edenGenerator.py"
)

text = p.read_text()
changed = False

old_motion = '''                yuzuConfig.set("Controls", player_nb_str + "_motionleft\\\\default", "false")
                yuzuConfig.set("Controls", player_nb_str + "_motionleft", '"guid:{},port:{},motion:0,engine:sdl"'.format(pad.guid,guid_port[pad.guid]))
                yuzuConfig.set("Controls", player_nb_str + "_motionright\\\\default", "false")
                yuzuConfig.set("Controls", player_nb_str + "_motionright", '"guid:{},port:{},motion:0,engine:sdl"'.format(pad.guid,guid_port[pad.guid]))
'''

new_motion = '''                yuzuConfig.set("Controls", player_nb_str + "_motionleft\\\\default", "false")
                yuzuConfig.set(
                    "Controls",
                    player_nb_str + "_motionleft",
                    '"motion:0,pad:0,port:26766,guid:0000000000000000000000007f000001,engine:cemuhookudp"'
                )
                yuzuConfig.set("Controls", player_nb_str + "_motionright\\\\default", "false")
                yuzuConfig.set(
                    "Controls",
                    player_nb_str + "_motionright",
                    '"motion:0,pad:0,port:26766,guid:0000000000000000000000007f000001,engine:cemuhookudp"'
                )
'''

if "engine:cemuhookudp" in text:
    print("Eden/Citron controller motion already correct")
elif old_motion in text:
    text = text.replace(old_motion, new_motion, 1)
    changed = True
    print("Installed Eden/Citron Cemuhook controller motion")
else:
    print(
        "WARNING: Eden/Citron SDL motion block not recognized"
    )

global_marker = (
    "# BUA global DSU/Cemuhook motion server"
)

global_block = '''        # BUA global DSU/Cemuhook motion server
        yuzuConfig.set("Controls", "motion_enabled\\\\default", "false")
        yuzuConfig.set("Controls", "motion_enabled", "true")
        yuzuConfig.set("Controls", "udp_input_servers\\\\default", "false")
        yuzuConfig.set("Controls", "udp_input_servers", "127.0.0.1:26766")
        yuzuConfig.set("Controls", "enable_udp_controller\\\\default", "false")
        yuzuConfig.set("Controls", "enable_udp_controller", "false")

'''

old_global_marker = (
    "# Global DSU/Cemuhook motion server provided by evdevhook2."
)

if global_marker in text:
    print("Eden/Citron global DSU server already correct")

elif old_global_marker in text:
    text = text.replace(
        old_global_marker,
        global_marker,
        1,
    )
    changed = True
    print("Normalized existing Eden/Citron DSU server block")

else:
    anchor = '''        with open(yuzuConfigFile, 'w') as configfile:
            yuzuConfig.write(configfile)
'''

    if anchor in text:
        text = text.replace(
            anchor,
            global_block + anchor,
            1,
        )
        changed = True
        print("Installed Eden/Citron global DSU server")
    else:
        print(
            "WARNING: Eden/Citron config-write anchor not found"
        )

compile(text, str(p), "exec")

if changed:
    p.write_text(text)
PY

    if python3 -m py_compile "$EDEN" 2>/dev/null; then
        log "Eden/Citron motion integration syntax OK"
    else
        log "ERROR: Eden/Citron generator failed syntax check"
    fi
else
    log "WARNING: Eden/Citron generator missing"
fi

log "Switch motion persistence check finished"
