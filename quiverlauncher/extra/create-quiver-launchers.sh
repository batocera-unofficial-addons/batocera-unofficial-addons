#!/bin/bash
# Creates an EmulationStation launcher in /userdata/roms/quiver for every app
# installed through Quiver Launcher, and removes launchers for apps that are gone.
#
# Usage:
#   create-quiver-launchers.sh          scan every LOOP_DELAY seconds (while Quiver runs)
#   create-quiver-launchers.sh --once   scan once and exit

########################
# CONFIG
########################

QUIVER_DIR="/userdata/system/add-ons/quiverlauncher"
ROMS="/userdata/roms/quiver"
LOOP_DELAY=10

mkdir -p "$ROMS/images"

########################
# Scan
########################

scan() {
    python3 - "$QUIVER_DIR" "$ROMS" <<'PYEOF'
import json, os, re, sys, urllib.request
import xml.etree.ElementTree as ET

quiver_dir, roms = sys.argv[1], sys.argv[2]
images = os.path.join(roms, "images")
gamelist_path = os.path.join(roms, "gamelist.xml")
MARKER = "# quiver-app: "

def load_json(path):
    try:
        with open(path, encoding="utf-8-sig") as f:
            return json.load(f)
    except (OSError, ValueError):
        return None

settings = load_json(os.path.join(quiver_dir, "settings.json")) or {}
library = load_json(os.path.join(quiver_dir, "apps.json"))
if library is None:
    print("No Quiver library yet (apps.json missing)")
    sys.exit(0)
apps_path = settings.get("AppsPath") or os.path.join(quiver_dir, "Apps")

# Candidate rules follow Quiver's own (GameInstallationService.FindExecutableCandidates on Linux)
NATIVE_EXT = (".appimage", ".x86_64", ".arm64", ".aarch64")
NOT_NATIVE = NATIVE_EXT + (".txt", ".dll", ".so", ".json", ".sh", ".exe")
METADATA = {"version.txt", "installed-build.txt", "lastplayed.txt", "selected_executable.txt",
            "flatpak-install.json", "flatpak-install.pending.json"}
SKIP = re.compile(r"(unins|setup|install|crash|redist|dxsetup|launcherhelper)", re.I)
WRAPPERS = ("launch.sh", "start.sh", "run.sh")

def is_compat_dir(path):
    return os.path.basename(path) in (".steam-compat-data", ".wine-prefix") or (
        os.path.isdir(os.path.join(path, "dosdevices")) and os.path.isdir(os.path.join(path, "drive_c")))

def is_elf(path):
    try:
        with open(path, "rb") as f:
            return f.read(4) == b"\x7fELF"
    except OSError:
        return False

def candidates(game_path, recurse):
    files = []
    for root, dirs, names in os.walk(game_path):
        dirs[:] = [d for d in dirs if not is_compat_dir(os.path.join(root, d))]
        files += [os.path.join(root, n) for n in names
                  if n.lower() not in METADATA and not SKIP.search(n)]
        if not recurse:
            break
    low = lambda f: os.path.basename(f).lower()
    native = [f for f in files if low(f).endswith(NATIVE_EXT)]
    native += [f for f in files if not low(f).endswith(NOT_NATIVE) and ".so." not in low(f) and is_elf(f)]
    exes = [] if native else [f for f in files if low(f).endswith(".exe")]
    scripts = [f for f in files if low(f).endswith(".sh")]
    return native + exes + scripts

def find_executable(game_path):
    """Quiver's saved choice, else the only candidate (top level first), else a
    launch/start/run.sh wrapper script."""
    selected = os.path.join(game_path, "selected_executable.txt")
    if os.path.isfile(selected):
        with open(selected, encoding="utf-8-sig") as f:
            exe = f.read().strip()
        if exe and os.path.exists(exe):
            return exe, None
    for recurse in (False, True):
        found = candidates(game_path, recurse)
        if len(found) == 1:
            return found[0], None
        if len(found) > 1:
            wrappers = [f for f in found if os.path.basename(f).lower() in WRAPPERS]
            if len(wrappers) == 1:
                return wrappers[0], None
            return None, f"{len(found)} executables found; choose one in Quiver"
    return None, "no executable found"

def to_png(data):
    """PNG bytes for a PNG, or the largest PNG frame of an ICO; None otherwise."""
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return data
    if data[:4] != b"\x00\x00\x01\x00":
        return None
    best, best_size = None, -1
    for i in range(int.from_bytes(data[4:6], "little")):
        entry = data[6 + 16 * i: 22 + 16 * i]
        if len(entry) < 16:
            break
        size = (entry[0] or 256) * (entry[1] or 256)
        length = int.from_bytes(entry[8:12], "little")
        offset = int.from_bytes(entry[12:16], "little")
        frame = data[offset:offset + length]
        if frame[:8] == b"\x89PNG\r\n\x1a\n" and size > best_size:
            best, best_size = frame, size
    return best

def slug(name):
    s = re.sub(r"[^A-Za-z0-9._ -]+", "", name).strip().replace(" ", "_")
    return s or "app"

def sh_quote(s):
    return "'" + s.replace("'", "'\\''") + "'"

def launcher_text(folder, exe):
    q = sh_quote(exe)
    if exe.lower().endswith(".exe"):
        run = f"batocera-wine windows play {q}"
    else:
        run = f"cd {sh_quote(os.path.dirname(exe))} && exec {q}"
    return f"""#!/bin/bash
{MARKER}{folder}
export DISPLAY=:0.0
{run}
"""

def folder_pattern(folder):
    """pkill -f pattern for any process started from the folder. An AppImage
    runs its program as a separate process, so killing the AppImage alone
    leaves the app open. The [/] keeps the pattern from matching the shell
    that runs pkill."""
    escaped = re.sub(r"([.^$*+?()\[\]{}|\\])", r"\\\1", folder.rstrip("/") + "/")
    return "[/]" + escaped[1:] if escaped.startswith("/") else escaped

def keys_text(exe, game_path):
    if exe.lower().endswith(".exe"):
        target = "batocera-wine windows stop"
    else:
        target = "pkill -f " + sh_quote(folder_pattern(game_path))
    return json.dumps({"actions_player1": [{
        "trigger": ["hotkey", "start"], "type": "exec",
        "target": target, "description": "Close app"}]}, indent=4) + "\n"

def write_if_changed(path, text, mode=None):
    try:
        with open(path) as f:
            if f.read() == text:
                return False
    except OSError:
        pass
    with open(path, "w") as f:
        f.write(text)
    if mode:
        os.chmod(path, mode)
    return True

# Load or create the gamelist
try:
    tree = ET.parse(gamelist_path)
    gamelist = tree.getroot()
except (OSError, ET.ParseError):
    gamelist = ET.Element("gameList")
    tree = ET.ElementTree(gamelist)
entries = {g.findtext("path"): g for g in gamelist.findall("game")}
changed = False

wanted = {}  # launcher file name -> folder
for app in library.get("apps", []):
    name, folder = app.get("name"), app.get("folderName")
    if not name or not folder:
        continue
    game_path = app.get("installPath") or os.path.join(apps_path, folder)
    if not os.path.isdir(game_path):
        continue  # not installed
    exe, why = find_executable(game_path)
    if not exe:
        print(f"Skipping {name}: {why}")
        continue

    base = slug(name)
    sh_name = base + ".sh"
    wanted[sh_name] = folder
    sh_path = os.path.join(roms, sh_name)
    if write_if_changed(sh_path, launcher_text(folder, exe), 0o755):
        print(f"Launcher for {name}: {exe}")
    write_if_changed(sh_path + ".keys", keys_text(exe, game_path))

    # Image from the app's icon URL, downloaded once
    image = None
    for ext in (".png", ".jpg"):
        if os.path.isfile(os.path.join(images, base + ext)):
            image = base + ext
    url = app.get("appIconUrl")
    if not image and url:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "BUA"})
            with urllib.request.urlopen(req, timeout=15) as r:
                data = r.read()
            if data[:3] == b"\xff\xd8\xff":
                ext = ".jpg"
            else:
                ext, data = ".png", to_png(data)
            if data:
                with open(os.path.join(images, base + ext), "wb") as f:
                    f.write(data)
                image = base + ext
            else:
                print(f"No image for {name}: icon is not PNG/JPEG")
        except Exception as e:
            print(f"No image for {name}: {e}")

    # Gamelist entry
    path = "./" + sh_name
    game = entries.get(path)
    if game is None:
        game = ET.SubElement(gamelist, "game")
        ET.SubElement(game, "path").text = path
        ET.SubElement(game, "name").text = name
        entries[path] = game
        changed = True
    if image and game.find("image") is None:
        ET.SubElement(game, "image").text = "./images/" + image
        changed = True

# Remove launchers this script made for apps that are no longer installed
for file in os.listdir(roms):
    if not file.endswith(".sh") or file in wanted:
        continue
    path = os.path.join(roms, file)
    try:
        with open(path) as f:
            ours = any(line.startswith(MARKER) for line in f)
    except OSError:
        continue
    if not ours:
        continue
    print(f"Removing launcher for uninstalled app: {file}")
    os.remove(path)
    for extra in (path + ".keys", os.path.join(images, file[:-3] + ".png"),
                  os.path.join(images, file[:-3] + ".jpg")):
        if os.path.exists(extra):
            os.remove(extra)
    game = entries.pop("./" + file, None)
    if game is not None:
        gamelist.remove(game)
        changed = True

if changed:
    ET.indent(tree)
    tree.write(gamelist_path, encoding="utf-8", xml_declaration=True)
    print("CHANGED")
PYEOF
}

reload_if_changed() {
    if echo "$1" | grep -q '^CHANGED$'; then
        curl -s http://127.0.0.1:1234/reloadgames >/dev/null 2>&1
    fi
    echo "$1" | grep -v '^CHANGED$'
}

if [[ "$1" == "--once" ]]; then
    reload_if_changed "$(scan)"
    exit 0
fi

echo "Quiver launcher generator - checking every ${LOOP_DELAY}s"
while true; do
    reload_if_changed "$(scan)"
    sleep "$LOOP_DELAY"
done
