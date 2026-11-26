#!/usr/bin/env python3
"""BUA Doctor: finds and fixes what breaks in BUA add-ons.

Run from the BUA menu (bua-doctor.sh), it scans the system, shows what it
found as a checklist, and fixes what you tick. Every file it changes or
removes is backed up first, to /userdata/system/backups/bua-doctor/<time>/.

  bua_doctor.py              scan, choose fixes, fix (dialog)
  bua_doctor.py --scan       print what it finds, change nothing
  bua_doctor.py --fix-all    fix everything that is ticked by default
  bua_doctor.py --list-undo  list the runs that can be undone
  bua_doctor.py --undo RUN   put back the files a run changed

Dialogs go through bash, so inside the BUA menu its own controller-friendly
dialog (an exported bash function) is used, and plain dialog elsewhere.

BUA_DOCTOR_ROOT puts every path under another folder (for testing).
"""
from __future__ import annotations

import datetime
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Callable

VERSION = "1.2"
ROOT = os.environ.get("BUA_DOCTOR_ROOT", "")
REPO = "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main"


def P(path: str) -> str:
    """A system path, under BUA_DOCTOR_ROOT when testing."""
    return ROOT + path


USERDATA = "/userdata"
HOME = "/userdata/system"
ADDONS = "/userdata/system/add-ons"
SERVICES = "/userdata/system/services"
SYSTEM_SERVICES = "/usr/share/batocera/services"
BATOCERA_CONF = "/userdata/system/batocera.conf"
CUSTOM_SH = "/userdata/system/custom.sh"
CONFIGS = "/userdata/system/configs"
ES_USER = "/userdata/system/configs/emulationstation"
ES_SYSTEMS = "/usr/share/emulationstation/es_systems.cfg"
APPLICATIONS = "/usr/share/applications"
PORTS = "/userdata/roms/ports"
F1 = "/usr/bin/filemanagerlauncher"
BACKUPS = "/userdata/system/backups/bua-doctor"
LOG = "/userdata/system/logs/bua-doctor.log"

VALID_SERVICE = re.compile(r"^[_A-Za-z][_A-Za-z0-9]*$")
ADDON_REF = re.compile(r"/userdata/system/add-ons/([^/\s\"']+)")

# Services of the old desktops; check_old_desktops removes them as a whole
LEGACY_DESKTOP_SERVICES = {"desktop", "desktop_drl", "lightdesktop"}

# Desktop services that take F1 and the display server they need
DESKTOP_SERVICES = {
    "native_x11_desktop": "x11", "native-x11-desktop": "x11",
    "native_wayland_desktop": "wayland", "native-wayland-desktop": "wayland",
    "kdeplasma": "wayland",
}


# ------------------------------------------------------------------ helpers

def log(msg: str) -> None:
    os.makedirs(os.path.dirname(P(LOG)), exist_ok=True)
    with open(P(LOG), "a", encoding="utf-8") as f:
        f.write(f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S} {msg}\n")


def bua_fds() -> tuple[int, ...]:
    """File descriptor 9, if open. The BUA menu runs jobs with "exec 9>&2"
    and its dialog function sends its markers there; Python closes inherited
    descriptors in child processes unless they are passed on, and without it
    every dialog (ours, and an install script's during a reinstall) fails
    with "9: Bad file descriptor" and waits forever."""
    try:
        os.fstat(9)
        return (9,)
    except OSError:
        return ()


def run(args: list[str], timeout: int = 60) -> tuple[int, str]:
    """Runs a command; never raises. In a test root, system commands are
    only logged."""
    if ROOT:
        log("TEST, not run: " + " ".join(args))
        return 0, ""
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout, pass_fds=bua_fds())
        return p.returncode, p.stdout
    except (OSError, subprocess.SubprocessError) as e:
        return 1, str(e)


def read(path: str) -> str:
    try:
        with open(P(path), encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return ""


def exists(path: str) -> bool:
    return os.path.lexists(P(path))


def pgrep(name: str) -> bool:
    if ROOT:
        return os.path.exists(P(f"/run/test-{name}"))
    return run(["pgrep", "-x", name])[0] == 0


class Backup:
    """Copies a file into this run's backup folder before it is changed, and
    keeps a manifest (what was saved, what this run created, which fixes ran)
    so the run can be undone."""

    def __init__(self) -> None:
        self.stamp = f"{datetime.datetime.now():%Y%m%d-%H%M%S}"
        self.dir = P(f"{BACKUPS}/{self.stamp}")
        self.used = False
        self.manifest: dict = {"version": VERSION, "saved": [], "created": [], "fixes": []}

    def _write_manifest(self) -> None:
        os.makedirs(self.dir, exist_ok=True)
        with open(os.path.join(self.dir, "manifest.json"), "w", encoding="utf-8") as f:
            json.dump(self.manifest, f, indent=1)

    def save(self, path: str) -> None:
        src = P(path)
        if not os.path.lexists(src) or path in self.manifest["saved"] or path in self.manifest["created"]:
            return  # nothing there, or the original is already kept
        dst = os.path.join(self.dir, "files", path.lstrip("/"))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isdir(src) and not os.path.islink(src):
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst, follow_symlinks=False)
        self.manifest["saved"].append(path)
        self.used = True
        self._write_manifest()

    def created(self, path: str) -> None:
        """A file this run made that did not exist before (undo removes it)."""
        if path not in self.manifest["created"] and path not in self.manifest["saved"]:
            self.manifest["created"].append(path)
            self.used = True
            self._write_manifest()

    def fixed(self, title: str, result: str) -> None:
        self.manifest["fixes"].append(f"{title}: {result}")
        if self.used:
            self._write_manifest()

    def remove(self, path: str, keep_copy: bool = True) -> None:
        if keep_copy:
            self.save(path)
        src = P(path)
        if os.path.isdir(src) and not os.path.islink(src):
            shutil.rmtree(src)
        elif os.path.lexists(src):
            os.remove(src)
        log(f"removed {path}")

    def write(self, path: str, text: str) -> None:
        if exists(path):
            self.save(path)
        else:
            self.created(path)
        with open(P(path), "w", encoding="utf-8") as f:
            f.write(text)
        log(f"changed {path}")

    def rename(self, old: str, new: str) -> None:
        self.save(old)
        self.created(new)
        os.rename(P(old), P(new))
        log(f"renamed {old} to {new}")


def conf_get(key: str) -> str:
    for line in read(BATOCERA_CONF).splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    return ""


def conf_set(backup: Backup, key: str, value: str) -> None:
    lines = read(BATOCERA_CONF).splitlines()
    out, done = [], False
    for line in lines:
        if line.startswith(key + "="):
            if not done:
                out.append(f"{key}={value}")
                done = True
            continue
        out.append(line)
    if not done:
        out.append(f"{key}={value}")
    backup.write(BATOCERA_CONF, "\n".join(out) + "\n")


def enabled_services() -> list[str]:
    return conf_get("system.services").split()


def set_enabled(backup: Backup, services: list[str]) -> None:
    conf_set(backup, "system.services", " ".join(services))


def service_file(name: str) -> str | None:
    for d in (SERVICES, SYSTEM_SERVICES):
        if os.path.isfile(P(f"{d}/{name}")):
            return f"{d}/{name}"
    return None


def stop_service(name: str) -> None:
    path = service_file(name)
    if path:
        run(["bash", P(path), "stop"])


def batocera_major() -> int:
    if ROOT:
        text = read("/run/test-batocera-version")
    else:
        text = run(["batocera-version"])[1]
    m = re.match(r"\s*(\d+)", text)
    return int(m.group(1)) if m else 0


def user_site() -> str:
    """Python's per-user site-packages as EmulationStation sees it."""
    v = f"python{sys.version_info.major}.{sys.version_info.minor}"
    return f"{HOME}/.local/lib/{v}/site-packages"


def addon_exists(name: str) -> bool:
    return os.path.isdir(P(f"{ADDONS}/{name}"))


def missing_addons(text: str) -> list[str]:
    """Add-on folders a script refers to that are gone ([] if it refers to
    none, or if any of them is still there)."""
    refs = sorted(set(ADDON_REF.findall(text)))
    if not refs or any(addon_exists(r) for r in refs):
        return []
    return refs


# ---------------------------------------------------------------- findings

@dataclass
class Finding:
    key: str
    title: str          # one line, shown in the checklist (no "|")
    detail: str         # what is wrong and what the fix does
    fix: Callable[[Backup], str] | None = None   # returns a result line
    on: bool = True     # ticked by default
    restart_es: bool = False
    reload_games: bool = False

    def __post_init__(self) -> None:
        self.title = self.title.replace("|", "/")[:70]


CHECKS: list[Callable[[], list[Finding]]] = []


def check(fn: Callable[[], list[Finding]]) -> Callable[[], list[Finding]]:
    CHECKS.append(fn)
    return fn


# ---------------------------------------------------------------- F1

def f1_mounts() -> list[str]:
    """mountinfo 'root' of each mount on F1's launcher, oldest first."""
    if ROOT:
        text = read("/run/test-mountinfo")
    else:
        text = read("/proc/self/mountinfo")
    return [f[3] for f in (l.split() for l in text.splitlines()) if len(f) > 4 and f[4] == F1]


def desktop_services() -> list[str]:
    """User services that bind a launcher over F1."""
    found = []
    try:
        names = sorted(os.listdir(P(SERVICES)))
    except OSError:
        return found
    for n in names:
        text = read(f"{SERVICES}/{n}")
        if n not in LEGACY_DESKTOP_SERVICES and "filemanagerlauncher" in text and "mount --bind" in text:
            found.append(n)
    return found


def service_launcher(name: str) -> str:
    m = re.search(r"^launcher=(\S+)", read(f"{SERVICES}/{name}"), re.M)
    return m.group(1).strip("\"'") if m else ""


@check
def check_f1_stale() -> list[Finding]:
    stale = [r for r in f1_mounts() if r.endswith("//deleted")]
    if not stale:
        return []
    owner = next((s for s in desktop_services()
                  if service_launcher(s) and any(r[:-len("//deleted")].endswith(os.path.basename(service_launcher(s))) for r in stale)), None)

    def fix(_b: Backup) -> str:
        for _ in range(8):
            if not any(r.endswith("//deleted") for r in f1_mounts()):
                break
            run(["umount", "-l", F1])
        if owner:
            run(["bash", P(f"{SERVICES}/{owner}"), "start"])
            return f"F1 bound again to {owner}'s current launcher"
        return "F1 released (Batocera's own F1 is back)"

    return [Finding("f1-stale", "F1 runs a deleted, older launcher",
                    "F1 is bound to a launcher file that was replaced (an add-on update) "
                    "or removed. Fix: release it (open desktops keep running) and "
                    + (f"bind {owner}'s current launcher." if owner else "give F1 back to Batocera."),
                    fix)]


@check
def check_f1_conflict() -> list[Finding]:
    enabled = enabled_services()
    desktops = desktop_services()
    on = [s for s in enabled if s in desktops]   # in the order they were enabled
    if len(on) < 2:
        return []
    # Keep the one holding F1 now; else the last enabled that suits this
    # display server (X11 or Wayland); else the last enabled
    holder = None
    if not ROOT and os.path.exists(F1):
        holder = next((s for s in on if service_launcher(s) and os.path.exists(service_launcher(s))
                       and os.path.samefile(F1, service_launcher(s))), None)
    here = "wayland" if pgrep("labwc") else "x11" if pgrep("openbox") else None
    suits = [s for s in on if DESKTOP_SERVICES.get(s, here) == here] if here else on
    keep = holder or (suits or on)[-1]
    drop = [s for s in on if s != keep]
    why = "the one holding F1 now" if holder else "the last one enabled" + (" that runs here" if here else "")

    def fix(b: Backup) -> str:
        for s in drop:
            stop_service(s)
        set_enabled(b, [s for s in enabled_services() if s not in drop])
        run(["bash", P(f"{SERVICES}/{keep}"), "start"])
        return f"F1 desktop: kept {keep}, switched off {', '.join(drop)}"

    return [Finding("f1-conflict", f"{len(on)} desktops are set to open with F1",
                    f"Enabled: {', '.join(on)}. Only one desktop can open with F1, and which one wins "
                    f"at boot is random. Fix: keep {keep} ({why}) and switch off {', '.join(drop)}. "
                    "They stay installed.", fix)]


@check
def check_f1_wrong_display() -> list[Finding]:
    wayland, x11 = pgrep("labwc"), pgrep("openbox")
    if not (wayland or x11):
        return []
    here = "wayland" if wayland else "x11"
    wrong = [s for s in enabled_services() if DESKTOP_SERVICES.get(s, here) != here and service_file(s)]
    if not wrong:
        return []

    def fix(b: Backup) -> str:
        for s in wrong:
            stop_service(s)
        set_enabled(b, [s for s in enabled_services() if s not in wrong])
        return f"switched off {', '.join(wrong)}"

    other = "X11" if here == "wayland" else "Wayland"
    return [Finding("f1-display", f"{other} desktop takes F1 on {here.upper()}: {', '.join(wrong)}",
                    f"This Batocera runs {here.upper()}, but {', '.join(wrong)} is a desktop for {other} "
                    "(left from before an image switch). At boot it can take F1 with a launcher that "
                    "cannot start. Fix: switch it off; its files stay.", fix)]


@check
def check_old_desktops() -> list[Finding]:
    marks = ["/userdata/system/add-ons/lightdesktop", "/userdata/system/services/lightdesktop",
             "/userdata/system/add-ons/desktop/rootfs", "/userdata/system/services/desktop",
             "/userdata/system/add-ons/native-x11-desktop/rootfs", "/userdata/system/add-ons/desktop_drl",
             "/userdata/system/services/desktop_drl", "/userdata/system/configs/bat-drl/Remover_Desktop.sh",
             "/userdata/roms/ports/Light Desktop.sh"]
    found = [m for m in marks if exists(m)]
    if not found:
        return []

    def fix(_b: Backup) -> str:
        fd, script = tempfile.mkstemp(suffix=".sh")
        os.close(fd)
        try:
            urllib.request.urlretrieve(f"{REPO}/native-desktop/native-desktop-legacy-cleanup.sh", script)
            rc, _ = run(["bash", script, "install"], timeout=600)
        except OSError as e:
            return f"FAILED: could not download the desktop cleanup ({e})"
        finally:
            os.remove(script)
        return "old desktops removed" if rc == 0 else f"FAILED: desktop cleanup exited {rc}"

    return [Finding("old-desktops", "Old desktop left behind (Light Desktop / Desktop for Batocera / DRL)",
                    "Found: " + ", ".join(found) + ". These can hold F1 or leave broken files. "
                    "Fix: run the Native Desktop's cleanup for older desktops (keeps your files in "
                    "Desktop; never touches the Docker Desktop add-on).", fix, reload_games=True)]


# ---------------------------------------------------------------- services

@check
def check_service_names() -> list[Finding]:
    try:
        names = sorted(os.listdir(P(SERVICES)))
    except OSError:
        return []
    found = []
    for n in names:
        if VALID_SERVICE.match(n) or not os.path.isfile(P(f"{SERVICES}/{n}")):
            continue
        new = re.sub(r"[^_A-Za-z0-9]", "_", n)
        if not re.match(r"[_A-Za-z]", new):
            new = "_" + new
        twin = exists(f"{SERVICES}/{new}")

        def fix(b: Backup, n=n, new=new, twin=twin) -> str:
            stop_service(n)
            enabled = enabled_services()
            if twin:
                b.remove(f"{SERVICES}/{n}")
                result = f"removed {n} ({new} replaces it)"
            else:
                b.rename(f"{SERVICES}/{n}", f"{SERVICES}/{new}")
                result = f"renamed {n} to {new}"
            if n in enabled:
                renamed = []
                for s in enabled:
                    s = new if s == n else s
                    if s not in renamed:
                        renamed.append(s)
                set_enabled(b, renamed)
                run(["bash", P(f"{SERVICES}/{new}"), "start"])
            return result

        found.append(Finding(f"svc-name-{n}", f"Service name not allowed: {n}",
                             f"Batocera ignores services whose name has characters other than letters, "
                             f"digits and _, so {n} never starts at boot. Fix: "
                             + (f"remove it ({new} already replaces it)." if twin else f"rename it to {new}."),
                             fix))
    return found


@check
def check_enabled_missing() -> list[Finding]:
    # custom_service: Batocera makes it from custom.sh, and BUA's
    # custom_service_handler moves it back at every boot (see check_custom_sh_runs)
    gone = [s for s in enabled_services() if not service_file(s) and s != "custom_service"]
    if not gone:
        return []

    def fix(b: Backup) -> str:
        set_enabled(b, [s for s in enabled_services() if s not in gone])
        return f"removed {', '.join(gone)} from the enabled services"

    return [Finding("svc-enabled-missing", f"Enabled services with no script: {', '.join(gone)}",
                    "batocera.conf (system.services) enables services whose script is gone. "
                    "Fix: remove them from the list.", fix)]


@check
def check_orphan_services() -> list[Finding]:
    found = []
    try:
        names = sorted(os.listdir(P(SERVICES)))
    except OSError:
        return found
    for n in names:
        if n in LEGACY_DESKTOP_SERVICES:
            continue
        gone = missing_addons(read(f"{SERVICES}/{n}"))
        if not gone:
            continue

        def fix(b: Backup, n=n) -> str:
            stop_service(n)
            if n in enabled_services():
                set_enabled(b, [s for s in enabled_services() if s != n])
            b.remove(f"{SERVICES}/{n}")
            return f"removed service {n}"

        found.append(Finding(f"svc-orphan-{n}", f"Service for a removed add-on: {n}",
                             f"Service {n} runs files from {', '.join(gone)} in add-ons, which is gone. "
                             "Fix: stop it, switch it off and remove it.", fix))
    return found


# ---------------------------------------------------------------- launchers

_APPS: list[dict] | None = None


def bua_apps() -> list[dict]:
    global _APPS
    if _APPS is not None:
        return _APPS
    _APPS = _fetch_apps()
    return _APPS


def _fetch_apps() -> list[dict]:
    if ROOT and exists("/run/test-apps.json"):
        return json.loads(read("/run/test-apps.json")).get("apps", [])
    arch = "arm64" if os.uname().machine == "aarch64" else "x86"
    try:
        with urllib.request.urlopen(f"{REPO}/app/apps_{arch}.json", timeout=20) as r:
            return json.load(r).get("apps", [])
    except (OSError, ValueError):
        return []


def install_command_for(addon: str) -> str | None:
    """The BUA install command of an add-on folder: its own <dir>/<dir>.sh
    first, else any script in that folder."""
    apps = bua_apps()
    for app in apps:
        if f"/main/{addon}/{addon}.sh" in app.get("install", ""):
            return app["install"]
    for app in apps:
        if f"/main/{addon}/" in app.get("install", ""):
            return app["install"]
    return None


_REINSTALLED: dict[str, str] = {}


def reinstall(addon: str) -> str:
    """Reinstalls an add-on from BUA, once per run (several fixes can need it)."""
    if addon in _REINSTALLED:
        return _REINSTALLED[addon] + " (already done in this run)"
    _REINSTALLED[addon] = result = _reinstall(addon)
    return result


def _reinstall(addon: str) -> str:
    cmd = install_command_for(addon)
    if not cmd:
        return f"FAILED: {addon} is not in the BUA app list; reinstall it by hand"
    log(f"reinstalling {addon}: {cmd}")
    if ROOT:
        return f"reinstalled {addon} (test, not run)"
    rc = subprocess.run(["bash", "-c", cmd], pass_fds=bua_fds()).returncode
    return f"reinstalled {addon}" if rc == 0 else f"FAILED: reinstalling {addon} exited {rc}"


def entry_point_names() -> set[str]:
    """batocera-launch emulators registered by add-ons (user site-packages)."""
    names = set()
    site = P(user_site())
    try:
        dists = [d for d in os.listdir(site) if d.endswith(".dist-info")]
    except OSError:
        return names
    for d in dists:
        text = read(f"{user_site()}/{d}/entry_points.txt")
        section = None
        for line in text.splitlines():
            line = line.strip()
            if line.startswith("["):
                section = line.strip("[]")
            elif section == "batocera_launch.emulators" and "=" in line:
                names.add(line.split("=", 1)[0].strip())
    return names


def addon_generators() -> dict[str, str]:
    """configgen generators shipped by add-ons: emulator name -> add-on."""
    found = {}
    try:
        addons = sorted(os.listdir(P(ADDONS)))
    except OSError:
        return found
    for a in addons:
        gdir = P(f"{ADDONS}/{a}/generator")
        if os.path.isdir(gdir):
            for g in os.listdir(gdir):
                if os.path.isfile(os.path.join(gdir, g, f"{g}Generator.py")):
                    found[g] = a
    return found


@check
def check_launcher_type() -> list[Finding]:
    major = batocera_major()
    if not major:
        return []
    gens = addon_generators()
    found = []
    if major >= 44:
        eps = entry_point_names()
        for emu, addon in sorted(gens.items()):
            if emu in eps:
                continue

            def fix(_b: Backup, addon=addon) -> str:
                return reinstall(addon)

            found.append(Finding(f"launcher-{addon}", f"{addon} was set up for Batocera 43, this is {major}",
                                 f"Batocera {major} starts emulators with batocera-launch, but {addon} only "
                                 "has a configgen generator (Batocera 43 and earlier), so its games do not "
                                 f"start. Fix: reinstall {addon} from BUA, which sets it up for this version.",
                                 fix, restart_es=True))
    elif gens:
        hook = f"{user_site()}/usercustomize.py"
        if "add-ons" not in read(hook):
            def fix(b: Backup) -> str:
                try:
                    with urllib.request.urlopen(f"{REPO}/app/usercustomize.py", timeout=20) as r:
                        text = r.read().decode()
                except OSError as e:
                    return f"FAILED: could not download the BUA Python hook ({e})"
                os.makedirs(os.path.dirname(P(hook)), exist_ok=True)
                b.write(hook, text)
                return "BUA Python hook installed"

            found.append(Finding("launcher-hook", "BUA Python hook missing: add-on emulators cannot start",
                                 f"Add-ons with their own emulators ({', '.join(sorted(set(gens.values())))}) need "
                                 "BUA's usercustomize.py so configgen finds them. Fix: install it.", fix))
    return found


@check
def check_dead_entry_points() -> list[Finding]:
    found = []
    site = user_site()
    try:
        dists = sorted(d for d in os.listdir(P(site)) if d.startswith("batocera_launch_") and d.endswith(".dist-info"))
    except OSError:
        return found
    for d in dists:
        pkg = d.split("-", 1)[0]
        if os.path.isdir(P(f"{site}/{pkg}")):
            continue

        def fix(b: Backup, d=d) -> str:
            b.remove(f"{site}/{d}")
            return f"removed {d}"

        found.append(Finding(f"ep-{pkg}", f"batocera-launch registration without its code: {pkg}",
                             f"{d} registers an emulator whose code ({pkg}) is gone; launching it fails. "
                             "Fix: remove the registration.", fix, restart_es=True))
    return found


# ---------------------------------------------------------------- ES configs

def system_emulators() -> set[str]:
    try:
        tree = ET.parse(P(ES_SYSTEMS))
    except (OSError, ET.ParseError):
        return set()
    return {e.get("name", "") for e in tree.iter("emulator")}


_PROBE_44 = """
import sys
from importlib.metadata import entry_points
names = set(entry_points(group='batocera_launch.emulators').names)
for n in sys.argv[1:]:
    print(n, n in names)
"""
_PROBE_43 = """
import sys
from configgen.generators.importer import get_generator
for n in sys.argv[1:]:
    try:
        get_generator(n, n)
        print(n, True)
    except Exception:
        print(n, False)
"""


def launchable_set(names: set[str], major: int) -> set[str]:
    """The emulators Batocera's own launcher can start: batocera-launch's
    entry points (44+) or configgen's generators (43 and earlier), with the
    user's site-packages and BUA's hook loaded as when EmulationStation
    launches a game."""
    if ROOT:   # test root: what the add-ons there provide
        provided = entry_point_names() if major >= 44 else set(addon_generators())
        return {n for n in names if n in provided or n in read("/run/test-system-emulators").split()}
    env = dict(os.environ, HOME=HOME)
    try:
        p = subprocess.run(["python3", "-c", _PROBE_44 if major >= 44 else _PROBE_43, *sorted(names)],
                           capture_output=True, text=True, timeout=60, env=env, cwd="/")
    except (OSError, subprocess.SubprocessError):
        return set(names)   # can't tell: report nothing
    ok = {l.split()[0] for l in p.stdout.splitlines() if l.endswith(" True")}
    if p.returncode != 0 or not p.stdout:
        return set(names)
    return ok


@check
def check_es_configs() -> list[Finding]:
    major = batocera_major()
    shipped = system_emulators()
    if not major or not shipped:
        return []   # can't tell what Batocera itself provides
    found = []
    try:
        files = sorted(f for f in os.listdir(P(ES_USER)) if f.endswith(".cfg")
                       and (f.startswith("es_features_") or f.startswith("es_systems_")))
    except OSError:
        return found
    wanted = set()
    for f in files:
        try:
            wanted |= {e.get("name", "") for e in ET.parse(P(f"{ES_USER}/{f}")).iter("emulator")}
        except ET.ParseError:
            pass
    ok = shipped | launchable_set(wanted - shipped, major)

    def launchable(emu: str) -> bool:
        return emu in ok

    for f in files:
        path = f"{ES_USER}/{f}"
        if f.startswith("es_features_") and f.endswith(".cfg"):
            try:
                emus = [e.get("name", "") for e in ET.parse(P(path)).iter("emulator")]
            except ET.ParseError:
                continue
            if emus and not any(launchable(e) for e in emus):
                def fix(b: Backup, path=path) -> str:
                    b.remove(path)
                    return f"removed {os.path.basename(path)}"
                found.append(Finding(f"es-{f}", f"ES options for a removed emulator: {f}",
                                     f"{f} adds ES options for {', '.join(emus)}, which nothing can launch "
                                     "(its add-on is gone). Fix: remove the file.", fix, restart_es=True))
        elif f.startswith("es_systems_") and f.endswith(".cfg"):
            try:
                tree = ET.parse(P(path))
            except ET.ParseError:
                continue
            dead = []
            for system in tree.iter("system"):
                emus = system.find("emulators")
                if emus is None:
                    continue
                for e in emus.findall("emulator"):
                    if not launchable(e.get("name", "")):
                        dead.append(e.get("name", ""))
            if not dead:
                continue

            def fix(b: Backup, path=path, dead=dead) -> str:
                tree = ET.parse(P(path))
                for emus in tree.iter("emulators"):
                    for e in list(emus.findall("emulator")):
                        if e.get("name") in dead:
                            emus.remove(e)
                b.save(path)
                tree.write(P(path), encoding="UTF-8", xml_declaration=True)
                log(f"changed {path}")
                return f"{os.path.basename(path)}: removed {', '.join(dead)}"

            found.append(Finding(f"es-{f}", f"ES lists emulators nothing can launch: {', '.join(dead)}",
                                 f"{f} offers {', '.join(dead)}, whose add-on is gone or not set up for "
                                 "this Batocera; choosing it makes games fail to start. Fix: remove those "
                                 "entries (the rest of the file stays).", fix, restart_es=True))
    return found


# ---------------------------------------------------------------- leftovers

def exec_target(line: str) -> str:
    """The program a command line runs (skipping env, bash, sh)."""
    try:
        words = shlex.split(line, comments=True)
    except ValueError:
        return ""
    while words and (words[0] in ("env", "bash", "sh", "nohup", "exec") or re.match(r"^\w+=", words[0])):
        words.pop(0)
    return words[0] if words else ""


@check
def check_custom_sh() -> list[Finding]:
    text = read(CUSTOM_SH)
    dead = [l for l in text.splitlines()
            if exec_target(l).startswith("/userdata/") and not exists(exec_target(l))]
    if not dead:
        return []

    def fix(b: Backup) -> str:
        keep = [l for l in read(CUSTOM_SH).splitlines() if l not in dead]
        b.write(CUSTOM_SH, "\n".join(keep) + "\n")
        return f"custom.sh: removed {len(dead)} line(s)"

    return [Finding("custom-sh", f"custom.sh runs {len(dead)} file(s) that are gone",
                    "At every boot custom.sh runs: " + "; ".join(dead[:5])
                    + (" ..." if len(dead) > 5 else "") + ". Fix: remove those lines.", fix)]


@check
def check_desktop_entries() -> list[Finding]:
    candidates = []
    for d in (APPLICATIONS,):
        try:
            candidates += [f"{d}/{n}" for n in os.listdir(P(d)) if n.endswith(".desktop")]
        except OSError:
            pass
    try:
        for c in os.listdir(P(CONFIGS)):
            sub = f"{CONFIGS}/{c}"
            if os.path.isdir(P(sub)):
                candidates += [f"{sub}/{n}" for n in os.listdir(P(sub)) if n.endswith(".desktop")]
    except OSError:
        pass
    dead = []
    for path in sorted(candidates):
        m = re.search(r"^Exec=(.*)$", read(path), re.M)
        target = exec_target(m.group(1)) if m else ""
        if target.startswith("/userdata/") and not exists(target):
            dead.append(path)
    if not dead:
        return []

    def fix(b: Backup) -> str:
        for path in dead:
            b.remove(path)
            # its boot-time restore script, if it has one
            restore = os.path.join(os.path.dirname(path), "restore_desktop_entry.sh")
            if path.startswith(CONFIGS) and exists(restore):
                b.remove(restore)
        return f"removed {len(dead)} menu entr{'y' if len(dead) == 1 else 'ies'}"

    names = ", ".join(os.path.basename(p) for p in dead[:4]) + (" ..." if len(dead) > 4 else "")
    return [Finding("desktop-entries", f"F1 menu entries for removed apps: {names}",
                    "These Applications entries start programs that are gone: " + ", ".join(dead)
                    + ". Fix: remove them (and their boot-time restore scripts).", fix)]


@check
def check_ports() -> list[Finding]:
    found = []
    try:
        scripts = sorted(n for n in os.listdir(P(PORTS)) if n.endswith(".sh"))
    except OSError:
        return found
    dead = [n for n in scripts if missing_addons(read(f"{PORTS}/{n}"))]
    if not dead:
        return found

    def fix(b: Backup) -> str:
        for n in dead:
            b.remove(f"{PORTS}/{n}")
            if exists(f"{PORTS}/{n}.keys"):
                b.remove(f"{PORTS}/{n}.keys")
        gamelist = f"{PORTS}/gamelist.xml"
        try:
            tree = ET.parse(P(gamelist))
            root = tree.getroot()
            gone = [g for g in root.findall("game")
                    if os.path.basename((g.findtext("path") or "").strip()) in dead]
            if gone:
                for g in gone:
                    root.remove(g)
                b.save(gamelist)
                tree.write(P(gamelist), encoding="UTF-8", xml_declaration=True)
                log(f"changed {gamelist}")
        except (OSError, ET.ParseError):
            pass
        return f"removed {len(dead)} Ports entr{'y' if len(dead) == 1 else 'ies'}"

    found.append(Finding("ports", f"Ports entries for removed add-ons: {', '.join(dead[:3])}"
                         + (" ..." if len(dead) > 3 else ""),
                         "These Ports entries start add-ons that are no longer installed: " + ", ".join(dead)
                         + ". Fix: remove them, their controller mappings and their gamelist entries.",
                         fix, reload_games=True))
    return found


@check
def check_disk_space() -> list[Finding]:
    try:
        st = os.statvfs(P(USERDATA))
    except OSError:
        return []
    free = st.f_bavail * st.f_frsize / 1024 ** 3
    if free >= 2:
        return []
    return [Finding("disk", f"Only {free:.1f} GB free on /userdata",
                    "Add-ons fail to install or update with little space. Nothing to fix automatically: "
                    "remove games or add-ons you do not use.", None, on=False)]



# ---------------------------------------------------------------- after a Batocera update

def site_dirs() -> list[str]:
    base = f"{HOME}/.local/lib"
    try:
        return sorted(f"{base}/{d}/site-packages" for d in os.listdir(P(base))
                      if d.startswith("python3") and os.path.isdir(P(f"{base}/{d}/site-packages")))
    except OSError:
        return []


@check
def check_old_python() -> list[Finding]:
    current = user_site()
    found = []
    for site in site_dirs():
        if site == current:
            continue
        try:
            names = sorted(os.listdir(P(site)))
        except OSError:
            continue
        bua = [n for n in names if n == "usercustomize.py" or n.startswith("batocera_launch_")]
        if not bua:
            continue
        addons = sorted({n[len("batocera_launch_"):] for n in bua
                         if n.startswith("batocera_launch_") and not n.endswith(".dist-info")})
        old = site.split("/")[-2]

        def fix(b: Backup, site=site, bua=bua, addons=addons) -> str:
            results = [reinstall(a) for a in addons]
            hook = f"{current}/usercustomize.py"
            if "usercustomize.py" in bua and batocera_major() <= 43 and not exists(hook):
                os.makedirs(os.path.dirname(P(hook)), exist_ok=True)
                b.write(hook, read(f"{site}/usercustomize.py"))
                results.append("BUA Python hook moved to the current Python")
            for n in bua:
                b.remove(f"{site}/{n}")
            return "; ".join(results + [f"removed the {old} copies"])

        found.append(Finding(f"oldpy-{old}", f"Add-on code left under the old Python ({old})",
                             f"Batocera now uses {current.split('/')[-2]}, so what add-ons put under {old} is "
                             f"ignored: {', '.join(bua)}. Emulators from "
                             f"{', '.join(addons) if addons else 'BUA add-ons'} stop working. Fix: reinstall "
                             f"{', '.join(addons) if addons else 'nothing'}"
                             + (" and move the BUA Python hook" if "usercustomize.py" in bua else "")
                             + f", then remove the {old} copies.", fix, restart_es=True))
    return found


@check
def check_custom_sh_runs() -> list[Finding]:
    """Batocera 43+ no longer runs custom.sh (it moves it to a service once).
    BUA's custom_service_handler runs it; the BUA menu installs the handler
    when it is missing, but does not switch it back on once it is off."""
    major = batocera_major()
    lines = [l for l in read(CUSTOM_SH).splitlines() if l.strip() and not l.strip().startswith("#")]
    if major < 43 or not lines:
        return []
    handler = f"{SERVICES}/custom_service_handler"
    present = exists(handler)
    if present and "custom_service_handler" in enabled_services():
        return []

    def fix(b: Backup) -> str:
        if not exists(handler):
            try:
                with urllib.request.urlopen(f"{REPO}/app/custom_service_handler", timeout=20) as r:
                    text = r.read().decode()
            except OSError as e:
                return f"FAILED: could not download BUA's custom_service_handler ({e})"
            os.makedirs(P(SERVICES), exist_ok=True)
            b.write(handler, text)
            os.chmod(P(handler), 0o755)
        if "custom_service_handler" not in enabled_services():
            set_enabled(b, enabled_services() + ["custom_service_handler"])
        return ("switched on" if present else "installed and switched on") \
            + " custom_service_handler (custom.sh runs from the next boot)"

    if present:
        why = ("BUA's custom_service_handler, which runs it, is switched off (in System Settings > "
               "Services, or by a batocera.conf change), and BUA does not switch it back on. "
               "Fix: switch it on.")
    else:
        why = ("BUA's custom_service_handler, which runs it, is missing. The BUA menu downloads it each "
               "time it starts, so that download failed (check the network). Fix: download it and switch it on.")
    return [Finding("custom-sh-runs", f"custom.sh is not run at boot ({len(lines)} line(s))",
                    f"Batocera {major} no longer runs custom.sh by itself. {why} Until then, add-ons that "
                    "restore their menu entries or settings at boot from custom.sh do nothing.", fix)]


# BUA's own system services. The BUA menu installs these at launch when they
# are missing, but never switches them back on once they are off.
#   symlink_manager: links add-ons' bin/, lib/ and .dep files into /usr at
#     boot and keeps them linked (its start never returns)
#   bua_window_rules: gives add-on windows labwc rules on Wayland
BUA_SERVICES = {
    "symlink_manager": ("app/symlinks.sh", True),
    "bua_window_rules": ("app/bua_window_rules", False),
}


def start_detached(path: str) -> None:
    """Starts a service whose start keeps running (as BUA's installer does)."""
    if ROOT:
        log(f"TEST, not run: bash {path} start &")
        return
    try:
        subprocess.Popen(["bash", P(path), "start"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True, cwd="/")
    except OSError as e:
        log(f"could not start {path}: {e}")


def service_running(name: str) -> bool:
    if ROOT:
        return exists(f"/run/test-running-{name}")
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
        except OSError:
            continue
        if "start" in args and any(os.path.basename(a) == name for a in args):
            return True
    return False


def unlinked_addon_files() -> list[str]:
    """Add-on bin/, lib/ and .dep files that symlink_manager should have linked."""
    missing = []
    try:
        addons = sorted(os.listdir(P(ADDONS)))
    except OSError:
        return missing
    for a in addons:
        for folder, target in (("bin", "/usr/bin"), ("lib", "/usr/lib")):
            d = f"{ADDONS}/{a}/{folder}"
            if os.path.isdir(P(d)):
                for n in os.listdir(P(d)):
                    if os.path.isfile(P(f"{d}/{n}")) and not exists(f"{target}/{n}"):
                        missing.append(f"{target}/{n}")
    dep = f"{ADDONS}/.dep"
    if os.path.isdir(P(dep)):
        for n in os.listdir(P(dep)):
            target = "/usr/lib" if "lib" in n else "/usr/bin"
            if os.path.isfile(P(f"{dep}/{n}")) and not exists(f"{target}/{n}"):
                missing.append(f"{target}/{n}")
    return missing


@check
def check_bua_services() -> list[Finding]:
    found = []
    enabled = enabled_services()
    for name, (src, keeps_running) in BUA_SERVICES.items():
        if name == "bua_window_rules" and not (exists("/usr/share/labwc/rc.xml") or pgrep("labwc")):
            continue   # window rules are for Wayland (labwc) only
        path = f"{SERVICES}/{name}"
        present, on = exists(path), name in enabled
        running = service_running(name) if keeps_running and present else True
        if present and on and running:
            continue
        unlinked = unlinked_addon_files() if name == "symlink_manager" else []
        if name == "symlink_manager":
            impact = ("Add-ons' own commands and libraries (bin/, lib/ and the shared .dep folder) are not "
                      "linked into /usr" + (f": {len(unlinked)} are missing now (e.g. {', '.join(unlinked[:3])})"
                                            if unlinked else " after a reboot") + ", so those add-ons fail.")
        else:
            impact = "On Wayland, add-on windows open small and without a title bar."
        if not present:
            state = "missing (the BUA menu normally puts it back when it starts, so that failed)"
        elif not on:
            state = "switched off (in System Settings > Services, or by a batocera.conf change), and BUA does not switch it back on"
        else:
            state = "switched on but not running"

        def fix(b: Backup, name=name, src=src, keeps_running=keeps_running, path=path) -> str:
            did = []
            if not exists(path):
                try:
                    with urllib.request.urlopen(f"{REPO}/{src}", timeout=20) as r:
                        text = r.read().decode()
                except OSError as e:
                    return f"FAILED: could not download {name} ({e})"
                os.makedirs(P(SERVICES), exist_ok=True)
                b.write(path, text)
                os.chmod(P(path), 0o755)
                did.append("downloaded")
            if name not in enabled_services():
                set_enabled(b, enabled_services() + [name])
                did.append("switched on")
            if keeps_running:
                if not service_running(name):
                    start_detached(path)
            else:
                run(["bash", P(path), "start"])
            did.append("started")
            return f"{name}: {', '.join(did)}"

        found.append(Finding(f"bua-svc-{name}", f"BUA's {name} service is {state.split(' (')[0].split(',')[0]}",
                             f"BUA's {name} service is {state}. {impact} Fix: "
                             + ("download it, " if not present else "") + ("switch it on and " if not on else "")
                             + "start it.", fix))
    return found


# ---------------------------------------------------------------- broken files

def owner_from_cfg(name: str) -> str | None:
    """es_systems_quiver.cfg -> an add-on folder named like it, if BUA has one."""
    m = re.match(r"es_(?:systems|features)_(.+)\.cfg$", name)
    if not m:
        return None
    key = m.group(1)
    for cand in (key, key.replace("_", "-"), key + "launcher"):
        if install_command_for(cand):
            return cand
    return None


@check
def check_broken_es_xml() -> list[Finding]:
    found = []
    try:
        files = sorted(f for f in os.listdir(P(ES_USER)) if f.endswith(".cfg")
                       and (f.startswith("es_systems_") or f.startswith("es_features_")))
    except OSError:
        return found
    for f in files:
        path = f"{ES_USER}/{f}"
        try:
            ET.parse(P(path))
            continue
        except ET.ParseError as e:
            error = str(e)
        owner = owner_from_cfg(f)

        def fix(b: Backup, path=path, owner=owner) -> str:
            b.remove(path)
            return f"set aside {os.path.basename(path)}" + (f"; {reinstall(owner)}" if owner else "")

        found.append(Finding(f"xml-{f}", f"Broken ES config file: {f}",
                             f"{f} is not valid XML ({error}), so EmulationStation drops what it adds "
                             "and can fail to start. Fix: set it aside (it stays in the backup)"
                             + (f" and reinstall {owner}, which writes a good one." if owner else
                                ". Reinstall the add-on it belongs to, to get it back."),
                             fix, restart_es=True))
    return found


def keys_files() -> list[str]:
    found = []
    for d in (PORTS, f"{CONFIGS}/evmapy"):
        try:
            found += [f"{d}/{n}" for n in os.listdir(P(d)) if n.endswith(".keys")]
        except OSError:
            pass
    try:
        for system in os.listdir(P("/userdata/roms")):
            d = f"/userdata/roms/{system}"
            if d == PORTS or not os.path.isdir(P(d)):
                continue
            with os.scandir(P(d)) as it:
                found += [f"{d}/{e.name}" for e in it if e.name.endswith(".keys") and e.is_file()]
    except OSError:
        pass
    return sorted(found)


@check
def check_broken_keys() -> list[Finding]:
    found = []
    for path in keys_files():
        try:
            json.loads(read(path) or "{}")
            continue
        except ValueError as e:
            error = str(e)
        script = path[:-len(".keys")]
        refs = [r for r in ADDON_REF.findall(read(script)) if addon_exists(r)] if exists(script) else []
        owner = next((r for r in refs if install_command_for(r)), None)
        name = os.path.basename(path)

        if owner:
            def fix(b: Backup, path=path, owner=owner) -> str:
                b.remove(path)
                return reinstall(owner)
            detail = f"Fix: reinstall {owner}, which writes it again."
        else:
            def fix(b: Backup, path=path) -> str:
                b.remove(path)
                return f"removed {os.path.basename(path)} (default controls apply)"
            detail = "Fix: remove it, so the game uses default controls (ticked only if you choose)."
        found.append(Finding(f"keys-{path}", f"Broken controller mapping: {name}",
                             f"{path} is not valid JSON ({error}), so its controller mapping, including "
                             f"Hotkey+Start to close, does nothing. {detail}", fix, on=bool(owner)))
    return found


# ---------------------------------------------------------------- BUA's install list

HISTORY = "/userdata/system/add-ons/bua_history.json"


def _addon_dirs_of(cmd: str) -> list[str]:
    """Add-on folders an install script names literally."""
    m = re.search(r"https://\S+?\.sh", cmd)
    if not m:
        return []
    if ROOT:
        text = read(f"/run/test-scripts/{os.path.basename(m.group(0))}")
    else:
        try:
            with urllib.request.urlopen(m.group(0), timeout=15) as r:
                text = r.read().decode(errors="replace")
        except OSError:
            return []
    return sorted({d for d in ADDON_REF.findall(text) if "$" not in d and "{" not in d})


@check
def check_installed_missing() -> list[Finding]:
    try:
        history = json.loads(read(HISTORY) or "{}")
    except ValueError:
        return []
    installed = [n for n, entries in history.items()
                 if isinstance(entries, list) and any(e.get("success") for e in entries if isinstance(e, dict))]
    apps = {a.get("name"): a for a in bua_apps()}
    todo = [(n, apps[n]["install"]) for n in installed if n in apps and apps[n].get("install")]
    if not todo:
        return []
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(8) as pool:
        dirs = list(pool.map(lambda t: _addon_dirs_of(t[1]), todo))
    found = []
    for (name, cmd), ds in zip(todo, dirs):
        if not ds or any(addon_exists(d) for d in ds):
            continue

        def fix(_b: Backup, name=name, cmd=cmd) -> str:
            log(f"reinstalling {name}: {cmd}")
            if ROOT:
                return f"reinstalled {name} (test, not run)"
            rc = subprocess.run(["bash", "-c", cmd], pass_fds=bua_fds()).returncode
            return f"reinstalled {name}" if rc == 0 else f"FAILED: reinstalling {name} exited {rc}"

        found.append(Finding(f"missing-{name}", f"Installed, but its files are gone: {name}",
                             f"BUA lists {name} as installed, but {', '.join(ds)} in add-ons is missing. "
                             "Fix: reinstall it (ticked only if you choose; it downloads it again). "
                             "If you do not want it, uninstall it in the Updater instead.",
                             fix, on=False))
    return found


# ---------------------------------------------------------------- clean-ups

def conf_key(line: str) -> str | None:
    s = line.strip()
    if not s or s.startswith("#") or "=" not in s:
        return None
    return s.split("=", 1)[0].strip()


@check
def check_duplicates() -> list[Finding]:
    found = []
    lines = read(BATOCERA_CONF).splitlines()
    seen, extra, values = set(), 0, {}
    for l in lines:
        k = conf_key(l)
        if k is None:
            continue
        if l.strip() in seen:
            extra += 1
        seen.add(l.strip())
        values.setdefault(k, set()).add(l.split("=", 1)[1].strip())
    conflicts = sorted(k for k, v in values.items() if len(v) > 1)
    if extra:
        def fix(b: Backup) -> str:
            out, kept = [], set()
            for l in read(BATOCERA_CONF).splitlines():
                if conf_key(l) is not None and l.strip() in kept:
                    continue
                kept.add(l.strip())
                out.append(l)
            b.write(BATOCERA_CONF, "\n".join(out) + "\n")
            return f"batocera.conf: removed {extra} repeated line(s)"
        found.append(Finding("dup-conf", f"batocera.conf has {extra} repeated line(s)",
                             "The same setting is written more than once (usually from reinstalling an "
                             "add-on). Fix: keep one copy of each.", fix))
    if conflicts:
        found.append(Finding("conflict-conf", f"batocera.conf sets {len(conflicts)} setting(s) twice, differently",
                             "These are set more than once with different values, so which one applies is "
                             f"unclear: {', '.join(conflicts[:8])}" + (" ..." if len(conflicts) > 8 else "")
                             + ". Set them again in EmulationStation, which writes one value.", None, on=False))
    cmds, dup = set(), 0
    for l in read(CUSTOM_SH).splitlines():
        s = l.strip()
        if not s or s.startswith("#") or s in ("fi", "done", "esac", "}", "then", "else", "do"):
            continue
        dup += s in cmds
        cmds.add(s)
    if dup:
        def fix(b: Backup) -> str:
            out, kept = [], set()
            for l in read(CUSTOM_SH).splitlines():
                s = l.strip()
                if s and not s.startswith("#") and s not in ("fi", "done", "esac", "}", "then", "else", "do"):
                    if s in kept:
                        continue
                    kept.add(s)
                out.append(l)
            b.write(CUSTOM_SH, "\n".join(out) + "\n")
            return f"custom.sh: removed {dup} repeated line(s)"
        found.append(Finding("dup-custom", f"custom.sh runs {dup} line(s) more than once",
                             "The same boot command is in custom.sh more than once (usually from "
                             "reinstalling an add-on), so it runs twice. Fix: keep the first.", fix))
    return found


LINK_DIRS = ("/usr/bin", "/usr/lib", "/usr/share/applications")


@check
def check_dangling_links() -> list[Finding]:
    dead = []
    for d in LINK_DIRS:
        try:
            entries = os.listdir(P(d))
        except OSError:
            continue
        for n in entries:
            path = f"{d}/{n}"
            if not os.path.islink(P(path)):
                continue
            target = os.readlink(P(path))
            if target.startswith("/userdata/") and not exists(target):
                dead.append(path)
    if not dead:
        return []

    def fix(b: Backup) -> str:
        for path in dead:
            b.remove(path)
        return f"removed {len(dead)} broken link(s)"

    return [Finding("dead-links", f"{len(dead)} system link(s) point into removed add-ons",
                    "These point to files under /userdata that are gone: " + ", ".join(dead[:6])
                    + (" ..." if len(dead) > 6 else "") + ". Fix: remove them.", fix)]


def tree_size(path: str) -> int:
    p = P(path)
    if os.path.islink(p) or not os.path.isdir(p):
        try:
            return os.lstat(p).st_size
        except OSError:
            return 0
    total = 0
    for root, _dirs, files in os.walk(p):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit in ("B", "KB") else f"{n:.1f} {unit}"
        n /= 1024
    return f"{n:.1f} GB"


@check
def check_temp_leftovers() -> list[Finding]:
    now = datetime.datetime.now().timestamp()
    old = []
    try:
        for n in os.listdir(P("/userdata/tmp")):
            path = f"/userdata/tmp/{n}"
            if now - os.lstat(P(path)).st_mtime > 24 * 3600:
                old.append(path)
    except OSError:
        pass
    try:
        for a in os.listdir(P(ADDONS)):
            d = f"{ADDONS}/{a}"
            if not os.path.isdir(P(d)) or os.path.islink(P(d)):
                continue
            for n in os.listdir(P(d)):
                path = f"{d}/{n}"
                if (n == "squashfs-root" or n.endswith((".tmp", ".part"))) \
                        and now - os.lstat(P(path)).st_mtime > 3600:
                    old.append(path)
    except OSError:
        pass
    sizes = {p: tree_size(p) for p in old}
    total = sum(sizes.values())
    if not old or total < 1024 * 1024:
        return []

    def fix(b: Backup) -> str:
        for p in old:
            b.remove(p, keep_copy=False)
        return f"deleted {len(old)} leftover(s), {human(total)} freed"

    biggest = sorted(old, key=lambda p: -sizes[p])[:5]
    return [Finding("temp", f"{human(total)} of leftover downloads and extracts",
                    "Left by interrupted or finished installs: "
                    + ", ".join(f"{p} ({human(sizes[p])})" for p in biggest) + (" ..." if len(old) > 5 else "")
                    + ". Fix: delete them (not backed up: they are only temporary files).", fix)]


# ---------------------------------------------------------------- connection and Docker

@check
def check_connection() -> list[Finding]:
    if ROOT and not exists("/run/test-offline"):
        return []
    bad = []
    for url in ("https://github.com", "https://raw.githubusercontent.com", "https://api.github.com"):
        if ROOT:
            bad.append(url)
            continue
        try:
            urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=10).close()
        except urllib.error.HTTPError:
            pass   # reached it; an error page is still a connection
        except OSError:
            bad.append(url)
    if not bad:
        return []
    return [Finding("network", "GitHub can't be reached: add-ons can't install or update",
                    "BUA downloads every add-on from GitHub, but these did not answer: " + ", ".join(bad)
                    + ". Check the network (and the date and time: a wrong clock breaks secure "
                    "connections), then run BUA Doctor again. Nothing to fix automatically.", None, on=False)]


DOCKER_CONTAINERS = "/userdata/system/var/lib/containers/docker/containers"


@check
def check_docker() -> list[Finding]:
    try:
        containers = [c for c in os.listdir(P(DOCKER_CONTAINERS)) if not c.startswith(".")]
    except OSError:
        containers = []
    svc = exists(f"{SERVICES}/docker")
    if not containers and not svc:
        return []
    if containers and not svc:
        return [Finding("docker-missing", f"{len(containers)} Docker container(s), but Docker is not installed",
                        "Docker add-ons (Jellyfin, Arr-In-One, the Webtops...) left containers behind, but "
                        "Docker's service is gone, so none of them start. Fix: reinstall Docker.",
                        lambda _b: reinstall("docker"))]
    if "docker" not in enabled_services():
        def fix(b: Backup) -> str:
            set_enabled(b, enabled_services() + ["docker"])
            run(["bash", P(f"{SERVICES}/docker"), "start"], timeout=120)
            return "Docker switched on and started"
        return [Finding("docker-off", "Docker is switched off",
                        "Docker is installed but its service is not switched on, so Docker add-ons do "
                        "not start at boot. Fix: switch it on and start it.", fix)]
    if not pgrep("dockerd"):
        def fix(_b: Backup) -> str:
            run(["bash", P(f"{SERVICES}/docker"), "start"], timeout=120)
            return "Docker started" if pgrep("dockerd") else "FAILED: Docker did not start; see its log"
        return [Finding("docker-down", "Docker is not running",
                        "Docker is switched on but not running, so Docker add-ons are unreachable. "
                        "Fix: start it.", fix)]
    return []

# ---------------------------------------------------------------- UI

def dialog(*args: str) -> tuple[int, str]:
    """Through bash, so the BUA menu's dialog function is used when present."""
    p = subprocess.run(["bash", "-c", 'dialog --stdout "$@"', "dialog", *args],
                       stdout=subprocess.PIPE, text=True, pass_fds=bua_fds())
    return p.returncode, p.stdout.strip()


def scan() -> list[Finding]:
    found = []
    for c in CHECKS:
        try:
            found += c()
        except Exception as e:   # one broken check must not stop the others
            log(f"check {c.__name__} failed: {e!r}")
    return found


def apply(findings: list[Finding]) -> list[str]:
    backup = Backup()
    results = []
    for f in findings:
        if not f.fix:
            continue
        try:
            r = f.fix(backup)
        except Exception as e:
            r = f"FAILED: {e!r}"
        log(f"fix {f.key}: {r}")
        backup.fixed(f.title, r)
        results.append(f"{f.title}\n  -> {r}")
    if any(f.restart_es for f in findings):
        run(["killall", "-9", "emulationstation"])
    elif any(f.reload_games for f in findings):
        run(["curl", "-s", "http://127.0.0.1:1234/reloadgames"])
    if backup.used:
        results.append(f"Backups of everything changed: {backup.dir}")
    return results


# ---------------------------------------------------------------- undo

def undo_runs() -> list[tuple[str, dict]]:
    """Runs that can be undone, newest first."""
    runs = []
    try:
        stamps = sorted(os.listdir(P(BACKUPS)), reverse=True)
    except OSError:
        return runs
    for st in stamps:
        try:
            m = json.loads(read(f"{BACKUPS}/{st}/manifest.json"))
        except ValueError:
            continue
        if not m.get("undone") and (m.get("saved") or m.get("created")):
            runs.append((st, m))
    return runs


def run_label(stamp: str, m: dict) -> str:
    try:
        when = datetime.datetime.strptime(stamp, "%Y%m%d-%H%M%S").strftime("%Y-%m-%d %H:%M")
    except ValueError:
        when = stamp
    n = len(m.get("fixes", []))
    return f"{when}: {n} fix{'es' if n != 1 else ''}"


def undo(stamp: str) -> list[str]:
    """Puts back every file the run saved and removes what it created."""
    base = P(f"{BACKUPS}/{stamp}")
    m = json.loads(read(f"{BACKUPS}/{stamp}/manifest.json"))
    done = []
    for path in m.get("created", []):
        dst = P(path)
        if os.path.isdir(dst) and not os.path.islink(dst):
            shutil.rmtree(dst)
        elif os.path.lexists(dst):
            os.remove(dst)
        done.append(f"removed {path}")
    for path in m.get("saved", []):
        src = os.path.join(base, "files", path.lstrip("/"))
        dst = P(path)
        if not os.path.lexists(src):
            done.append(f"FAILED: no copy of {path}")
            continue
        if os.path.isdir(dst) and not os.path.islink(dst):
            shutil.rmtree(dst)
        elif os.path.lexists(dst):
            os.remove(dst)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isdir(src) and not os.path.islink(src):
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst, follow_symlinks=False)
        done.append(f"put back {path}")
    m["undone"] = f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}"
    with open(os.path.join(base, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(m, f, indent=1)
    for line in done:
        log(f"undo {stamp}: {line}")
    return done


UNDO_NOTE = ("Files are back as they were. Services that were started or stopped, and add-ons that "
             "were reinstalled, are not changed back: restart Batocera to apply the old settings.")


def ui_undo() -> int:
    runs = undo_runs()
    items = []
    for st, m in runs:
        items += [st, run_label(st, m).replace("|", "/")]
    rc, st = dialog("--title", "BUA Doctor: undo", "--menu", "Which run do you want to undo?",
                    "18", "70", str(min(len(runs), 10)), *items)
    m = dict(runs).get(st)
    if rc != 0 or m is None:
        return 0
    fixes = "\n".join(f"* {f}" for f in m.get("fixes", [])) or "(no fixes recorded)"
    rc, _ = dialog("--title", "BUA Doctor: undo", "--yesno",
                   f"Undo the run of {run_label(st, m)}?\n\n{fixes}\n\n{UNDO_NOTE}", "22", "90")
    if rc != 0:
        return 0
    done = undo(st)
    dialog("--title", "BUA Doctor: undone", "--msgbox",
           f"{len(done)} file(s) restored or removed.\n\n{UNDO_NOTE}\n\nLog: {LOG}", "14", "80")
    return 0


# ---------------------------------------------------------------- main

def main() -> int:
    log(f"BUA Doctor {VERSION} started: {' '.join(sys.argv[1:])}")
    if "--list-undo" in sys.argv:
        for st, m in undo_runs():
            print(f"{st}  {run_label(st, m)}")
            for f in m.get("fixes", []):
                print(f"    {f}")
        return 0
    if "--undo" in sys.argv:
        i = sys.argv.index("--undo")
        st = sys.argv[i + 1] if i + 1 < len(sys.argv) else ""
        if st not in dict(undo_runs()):
            print(f"No run {st!r} to undo (see --list-undo)")
            return 1
        for line in undo(st):
            print(line)
        print(UNDO_NOTE)
        return 0
    if "--scan" in sys.argv:
        found = scan()
        for f in found:
            print(f"[{'x' if f.on else ' '}] {f.key}: {f.title}\n    {f.detail}")
        print(f"{len(found)} problem(s) found" if found else "No problems found")
        return 1 if found else 0
    if "--fix-all" in sys.argv:
        found = [f for f in scan() if f.on and f.fix]
        for r in apply(found):
            print(r)
        print(f"{len(found)} fix(es) applied" if found else "Nothing to fix")
        return 0

    if undo_runs():
        rc, choice = dialog("--title", "BUA Doctor", "--menu", "What do you want to do?", "12", "70", "2",
                            "check", "Check for problems and fix them",
                            "undo", "Undo a previous run")
        if rc != 0 or not choice:
            return 0
        if choice == "undo":
            return ui_undo()

    dialog("--title", "BUA Doctor", "--infobox", "Checking your add-ons...", "5", "50")
    found = scan()
    if not found:
        dialog("--title", "BUA Doctor", "--msgbox", "No problems found. Your add-ons look healthy.", "7", "55")
        return 0
    fixable = [f for f in found if f.fix]
    report = "\n\n".join(f"* {f.title}\n{f.detail}" for f in found)
    dialog("--title", f"BUA Doctor: {len(found)} problem(s)", "--msgbox", report, "24", "90")
    if not fixable:
        return 0
    items = []
    for i, f in enumerate(fixable):
        items += [str(i + 1), f.title, "on" if f.on else "off"]
    rc, out = dialog("--title", "BUA Doctor", "--checklist",
                     "Fix these? Everything changed is backed up first, and can be undone from BUA Doctor.",
                     "20", "90", str(len(fixable)), *items)
    if rc != 0 or not out:
        return 0
    chosen = [fixable[int(t) - 1] for t in shlex.split(out) if t.isdigit() and 0 < int(t) <= len(fixable)]
    dialog("--title", "BUA Doctor", "--infobox", "Fixing...", "5", "40")
    results = apply(chosen)
    dialog("--title", "BUA Doctor: done", "--msgbox", "\n\n".join(results) + f"\n\nLog: {LOG}", "24", "90")
    return 0


if __name__ == "__main__":
    sys.exit(main())
