#!/usr/bin/env python3
"""Prints the kyty_emulator options for a game, built from the settings saved
in Kyty's launcher window (Kyty.ini) the same way the launcher builds them
when it starts a game itself (CreateEmulatorArgs in src/launcher/src/
mainDialog.cpp). kyty.sh uses them for games started from EmulationStation.

A game's own settings win over the global ones; the controller and input
mapping are always global. Prints nothing when Kyty.ini is missing (the
launcher was never opened), so kyty.sh keeps Kyty's built-in defaults.
--game and --fullscreen are left to kyty.sh.

Usage: kyty-args.py <game folder or file>
Output: the options, each followed by a NUL byte.
"""
import json
import os
import re
import sys

INSTALL_DIR = "/userdata/system/add-ons/kytyps5"
CONFIG_HOME = os.environ.get("XDG_CONFIG_HOME") or "/userdata/system/.config"

# Launcher defaults (src/launcher/include/configuration.h)
DEFAULTS = {
    "screen_resolution": "1280x720",
    "user_name": "Kyty",
    "user_id": "1000",
    "audio_input_device": "",
    "present_mode": "Mailbox",
    "gpu_index": "-1",
    "fullscreen_enabled": "false",
    "hdr_enabled": "false",
    "hide_cursor_enabled": "false",
    "stretch_enabled": "false",
    "readback_linear_images": "false",
    "readback_tiled_images": "false",
    "sync_raw_image_buffers": "false",
    "tessellation_enabled": "false",
    "occlusion_queries_enabled": "false",
    "shader_cache_enabled": "true",
    "trophy_enabled": "true",
    "trophy_duration_seconds": "6",
    "perf_overlay_enabled": "false",
    "skip_notice_screen": "false",
    "network_connected": "false",
    "psn_emulation_enabled": "false",
    "vblank_frequency": "60",
    "console_language": "1",
    "vulkan_validation_enabled": "false",
    "shader_validation_enabled": "false",
    "shader_optimization_type": "Performance",
    "shader_log_direction": "Silent",
    "shader_log_folder": "_Shaders",
    "command_buffer_dump_enabled": "false",
    "command_buffer_dump_folder": "_Buffers",
    "printf_direction": "Silent",
    "printf_output_file": "_kyty.txt",
    "profiler_enabled": "false",
    "renderdoc_enabled": "false",
    "pro_enabled": "false",
    "amd_cpu_enabled": "false",
    "guest_tsc_enabled": "false",
}
ENUMS = {
    "present_mode": ("Fifo", "Mailbox", "Immediate"),
    "shader_optimization_type": ("None", "Size", "Performance"),
    "shader_log_direction": ("Silent", "Console", "File"),
    "printf_direction": ("Silent", "Console", "File"),
}


def ini_values(raw):
    """A QSettings INI value as a list of strings (one item for a plain
    value, none for @Invalid()), like QSettings' iniUnescapedStringList."""
    raw = raw.strip()
    if raw == "@Invalid()":
        return []
    items, cur, quoted, was_quoted, i = [], [], False, False, 0
    escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v",
               "\\": "\\", '"': '"', "'": "'", "?": "?", ";": ";", ",": ",", "=": "=", "0": "\0"}
    while i < len(raw):
        ch = raw[i]
        if ch in " \t" and not quoted and not cur and not was_quoted:
            pass  # spaces after a comma
        elif ch == '"':
            quoted = not quoted
            was_quoted = True
        elif ch == "\\" and i + 1 < len(raw):
            i += 1
            nxt = raw[i]
            if nxt == "x":
                m = re.match(r"[0-9a-fA-F]+", raw[i + 1:])
                if m:
                    cur.append(chr(int(m.group(0), 16)))
                    i += len(m.group(0))
            else:
                cur.append(escapes.get(nxt, nxt))
        elif ch == "," and not quoted:
            items.append("".join(cur) if was_quoted else "".join(cur).strip())
            cur, was_quoted = [], False
        else:
            cur.append(ch)
        i += 1
    items.append("".join(cur) if was_quoted else "".join(cur).strip())
    # A value starting with @ is stored as @String(...)
    return [v[8:-1] if v.startswith("@String(") and v.endswith(")") else v for v in items]


def read_ini(path):
    """{section: {key: [values]}}"""
    sections, section = {}, ""
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith(";"):
                continue
            if line.startswith("[") and line.rstrip().endswith("]"):
                section = line.strip()[1:-1]
                sections.setdefault(section, {})
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                sections.setdefault(section, {})[key.strip()] = ini_values(value)
    return sections


def first(values, default=""):
    return values[0] if values else default


def real(path):
    return os.path.realpath(path) if path else ""


def game_title_id(basedir):
    try:
        with open(os.path.join(basedir, "sce_sys", "param.json"), encoding="utf-8") as f:
            root = json.load(f)
    except (OSError, ValueError):
        return ""
    title_id = str(root.get("titleId") or "")
    if not title_id:
        content_id = str(root.get("contentId") or "")
        title_id = content_id[7:16]
    return title_id.strip().upper()


def main():
    if len(sys.argv) < 2:
        return
    target = sys.argv[1].rstrip("/")
    ini_path = os.path.join(INSTALL_DIR, "Kyty.ini")
    if not os.path.isfile(ini_path):
        ini_path = os.path.join(CONFIG_HOME, "Kyty", "Kyty.ini")
    if not os.path.isfile(ini_path):
        return
    ini = read_ini(ini_path)

    # The game folder (an eboot.bin's folder, or an archive itself)
    basedir = target
    if os.path.isfile(target) and os.path.basename(target).lower() == "eboot.bin":
        basedir = os.path.dirname(target)
        if os.path.basename(basedir) == "sce_module":
            basedir = os.path.dirname(basedir)

    glob = ini.get("GlobalConfiguration", {})
    settings = {k: first(glob.get(k, [v]), v) for k, v in DEFAULTS.items()}

    # This game's own settings: GameConfigurations array entries are "<n>\key"
    games = {}
    for key, values in ini.get("GameConfigurations", {}).items():
        if "\\" in key:
            n, name = key.split("\\", 1)
            games.setdefault(n, {})[name] = values
    custom = None
    for entry in games.values():
        paths = {real(first(entry.get("game_path", []))), real(first(entry.get("basedir", [])))}
        if real(basedir) in paths:
            custom = entry
            break
    if custom is not None:
        settings = {k: first(custom.get(k, [v]), v) for k, v in DEFAULTS.items()}

    def flag(name):
        return settings[name].strip().lower() == "true"

    def number(name, low=None, high=None):
        try:
            value = int(settings[name])
        except ValueError:
            return int(DEFAULTS[name])
        if (low is not None and value < low) or (high is not None and value > high):
            return int(DEFAULTS[name])
        return value

    def enum(name):
        return settings[name] if settings[name] in ENUMS[name] else DEFAULTS[name]

    m = re.match(r"^\s*R?(\d+)\s*[xX]\s*(\d+)\s*$", settings["screen_resolution"])
    width, height = (m.group(1), m.group(2)) if m else ("1280", "720")

    args = ["--screen-width", width, "--screen-height", height,
            "--user-name", settings["user_name"] or "Kyty",
            "--user-id", str(number("user_id"))]
    if settings["audio_input_device"]:
        args += ["--mic", settings["audio_input_device"]]
    color = first(glob.get("controller_color", []))
    if re.match(r"^#[0-9a-fA-F]{6}$", color):
        args += ["--controller-color", color.lower()]

    def percent(key, fallback):
        try:
            return str(max(0, min(100, int(first(glob.get(key, []), fallback)))))
        except ValueError:
            return fallback

    args += ["--controller-volume", percent("controller_speaker_volume", "50"),
             "--controller-vibration", percent("controller_vibration_intensity", "100"),
             "--keyboard-player", percent("controller_keyboard_player", "0"),
             "--present-mode", enum("present_mode")]
    if number("gpu_index") >= 0:
        args += ["--gpu", str(number("gpu_index"))]
    for name, option in (("hdr_enabled", "--hdr"), ("hide_cursor_enabled", "--hide-cursor"),
                         ("stretch_enabled", "--stretch"),
                         ("readback_linear_images", "--readback-linear-images"),
                         ("readback_tiled_images", "--readback-tiled-images"),
                         ("sync_raw_image_buffers", "--sync-raw-image-buffers")):
        if flag(name):
            args.append(option)
    if not flag("trophy_enabled"):
        args.append("--no-trophy-notifications")
    args += ["--trophy-duration", str(number("trophy_duration_seconds", 5, 10))]
    for name, option in (("perf_overlay_enabled", "--perf-overlay"),
                         ("skip_notice_screen", "--skip-notice-screen"),
                         ("network_connected", "--network-connected"),
                         ("psn_emulation_enabled", "--emulate-psn"),
                         ("tessellation_enabled", "--tessellation"),
                         ("occlusion_queries_enabled", "--occlusion-queries"),
                         ("shader_cache_enabled", "--shader-cache")):
        if flag(name):
            args.append(option)
    args += ["--vblank-frequency", str(number("vblank_frequency", 30, 360)),
             "--console-language", str(number("console_language", 0, 29))]
    for name, option in (("vulkan_validation_enabled", "--vulkan-validation"),
                         ("shader_validation_enabled", "--shader-validation")):
        if flag(name):
            args.append(option)
    args += ["--shader-optimization-type", enum("shader_optimization_type"),
             "--shader-log-direction", enum("shader_log_direction"),
             "--shader-log-folder", settings["shader_log_folder"]]
    if flag("command_buffer_dump_enabled"):
        args.append("--command-buffer-dump")
    args += ["--command-buffer-dump-folder", settings["command_buffer_dump_folder"],
             "--printf-direction", enum("printf_direction"),
             "--printf-output-file", settings["printf_output_file"]]
    for name, option in (("profiler_enabled", "--profile"), ("pro_enabled", "--trinity"),
                         ("amd_cpu_enabled", "--amd-cpu"), ("guest_tsc_enabled", "--guest-tsc")):
        if flag(name):
            args.append(option)
    for binding in glob.get("host_input_mapping", []):
        if binding:
            args += ["--keymap", binding]
    if flag("renderdoc_enabled"):
        args.append("--rd")

    # Add-ons (DLC) and cheats, by the game's title ID
    addons_dir = first(ini.get("Launcher", {}).get("addons_dir", []))
    if addons_dir:
        args += ["--addcont-dir", addons_dir]
    title_id = game_title_id(basedir) if os.path.isdir(basedir) else ""
    if title_id:
        for entry in ini.get("AdditionalContent", {}).get(title_id, []):
            if entry:
                args += ["--addcont", entry]
        patch = os.path.join(INSTALL_DIR, "_Patches", title_id + ".json")
        if re.match(r"^PPSA[0-9]{5}$", title_id) and os.path.isfile(patch):
            args += ["--game-patch", patch]

    sys.stdout.write("".join(a + "\0" for a in args))


if __name__ == "__main__":
    main()
