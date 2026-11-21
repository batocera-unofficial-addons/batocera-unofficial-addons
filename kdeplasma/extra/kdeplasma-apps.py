#!/usr/bin/env python3
"""Batocera's F1 > Applications inside the KDE Plasma Desktop.

Those apps (emulator settings, xterm, add-ons...) live on Batocera's side,
which the Plasma container cannot see. So:

  kdeplasma-apps.py menu <plasma home>
      Before Plasma starts: makes a "Batocera" folder in Plasma's app menu
      with one entry per F1 app (and its icon). Rebuilt every start, so new
      add-ons appear and removed ones go.

  kdeplasma-apps.py serve <request fifo> <container root>
      While Plasma runs (on Batocera's side, as root, like F1): a menu entry
      writes its app's name into the fifo; this starts that app with its
      window shown inside Plasma (KWin's Wayland and Xwayland). Only apps in
      F1's list can be started, never an arbitrary command.

Root terminals (xterm, and entries that open one) are left out: anything
running in Plasma could ask for one, or type into it, and so get root on
Batocera. To have them anyway, create the file
/userdata/system/configs/kdeplasma/allow-root-terminal (Plasma itself cannot:
/userdata/system is read-only inside it).

Runs with Batocera's python, from kdeplasma-launch.sh.
"""
import configparser
import glob
import os
import re
import shlex
import shutil
import subprocess
import sys

APPS_DIR = "/usr/share/applications"
CATEGORY = "batocera.linux"
LOG = "/userdata/system/logs/kdeplasma-apps.log"
# Inside the container
CLIENT = "/usr/local/bin/batocera-app"
FIFO_IN_CONTAINER = "/host-run/kdeplasma-apps.fifo"
# Batocera side: tool wrappers for the apps started here
HOST_BIN = "/run/kdeplasma-hostbin"
ALLOW_ROOT_TERMINAL = "/userdata/system/configs/kdeplasma/allow-root-terminal"
TERMINALS = {"xterm", "uxterm", "urxvt", "rxvt", "lxterminal", "xfce4-terminal",
             "konsole", "gnome-terminal", "alacritty", "kitty", "foot", "st"}


def opens_root_terminal(desktop, entry):
    """True for a terminal (a root shell, as these apps run as root)."""
    if desktop == "xterm.desktop" or "TerminalEmulator" in entry.get("Categories", "").split(";"):
        return True
    if entry.get("Terminal", "").lower() == "true":
        return True
    try:
        args = shlex.split(entry["Exec"])
    except ValueError:
        return True
    return any(os.path.basename(a) in TERMINALS for a in args)


def read_entry(path):
    """The [Desktop Entry] of a .desktop file, or None if it is not an F1 app
    that Plasma may start."""
    parser = configparser.RawConfigParser(strict=False, interpolation=None)
    parser.optionxform = str
    try:
        parser.read(path, encoding="utf-8")
        entry = dict(parser["Desktop Entry"])
    except (configparser.Error, KeyError, UnicodeDecodeError):
        return None
    categories = entry.get("Categories", "").split(";")
    if CATEGORY not in categories or entry.get("NoDisplay", "").lower() == "true":
        return None
    if entry.get("Type", "Application") != "Application" or not entry.get("Exec"):
        return None
    if opens_root_terminal(os.path.basename(path), entry) and not os.path.exists(ALLOW_ROOT_TERMINAL):
        return None
    return entry


def f1_apps():
    """{desktop file name: entry} for every app in F1 > Applications."""
    apps = {}
    for path in sorted(glob.glob(os.path.join(APPS_DIR, "*.desktop"))):
        entry = read_entry(path)
        if entry:
            apps[os.path.basename(path)] = entry
    return apps


def nice_name(name):
    """F1 shows tool names like "pcsx2-config"; make them read as titles."""
    m = re.fullmatch(r"(.+?)(-emu)?-config", name)
    if m:
        return m.group(1).replace("-", " ").title() + " Settings"
    return name[:1].upper() + name[1:]


def find_icon(icon):
    """A file for the entry's icon: its path, or a lookup by name."""
    if not icon:
        return None
    if icon.startswith("/"):
        return icon if os.path.isfile(icon) else None
    for pattern in (f"/usr/share/pixmaps/{icon}.*", f"/usr/share/icons/batocera/{icon}.*",
                    f"/usr/share/icons/*/*/apps/{icon}.*", f"/usr/share/icons/*/*/*/{icon}.*"):
        found = sorted(glob.glob(pattern))
        if found:
            return found[0]
    return None


def make_menu(home):
    apps_dir = os.path.join(home, ".local/share/applications/batocera")
    icons_dir = os.path.join(home, ".local/share/icons/batocera-apps")
    for d in (apps_dir, icons_dir):
        shutil.rmtree(d, ignore_errors=True)
        os.makedirs(d)
    for desktop, entry in f1_apps().items():
        app_id = desktop[:-len(".desktop")]
        icon = entry.get("Icon", "application-x-executable")
        icon_file = find_icon(icon)
        if icon_file:
            ext = os.path.splitext(icon_file)[1]
            shutil.copyfile(icon_file, os.path.join(icons_dir, app_id + ext))
            icon = f"/home/plasma/.local/share/icons/batocera-apps/{app_id}{ext}"
        with open(os.path.join(apps_dir, desktop), "w") as f:
            f.write("[Desktop Entry]\nType=Application\n"
                    f"Name={nice_name(entry.get('Name', app_id))}\n"
                    f"Comment=Batocera (F1 > Applications)\n"
                    f"Icon={icon}\n"
                    f"Exec={CLIENT} {desktop}\n"
                    "Terminal=false\nCategories=X-Batocera;\n")

    # A "Batocera" folder in Plasma's app menu for them
    os.makedirs(os.path.join(home, ".local/share/desktop-directories"), exist_ok=True)
    with open(os.path.join(home, ".local/share/desktop-directories/batocera.directory"), "w") as f:
        f.write("[Desktop Entry]\nType=Directory\nName=Batocera\nIcon=applications-games\n")
    os.makedirs(os.path.join(home, ".config/menus/applications-merged"), exist_ok=True)
    with open(os.path.join(home, ".config/menus/applications-merged/batocera.menu"), "w") as f:
        f.write('<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"\n'
                ' "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">\n'
                "<Menu>\n  <Name>Applications</Name>\n  <Menu>\n    <Name>Batocera</Name>\n"
                "    <Directory>batocera.directory</Directory>\n"
                "    <Include><Category>X-Batocera</Category></Include>\n  </Menu>\n</Menu>\n")


def make_client(root):
    """The command the menu entries run inside the container."""
    path = root + CLIENT
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("#!/bin/sh\n# Asks Batocera to start one of its F1 apps (kdeplasma-apps.py serve)\n"
                f'[ -p {FIFO_IN_CONTAINER} ] && printf "%s\\n" "$1" > {FIFO_IN_CONTAINER}\n')
    os.chmod(path, 0o755)


def newest(pattern):
    found = sorted(glob.glob(pattern), key=os.path.getmtime)
    return found[-1] if found else None


def start_app(desktop, root, log):
    entry = read_entry(os.path.join(APPS_DIR, desktop))
    if not entry:
        print(f"refused: {desktop} is not in F1 > Applications (or is a root terminal)", file=log, flush=True)
        return
    # Field codes (%f, %U...) are for files; F1 starts the apps without any
    args = [a for a in shlex.split(entry["Exec"]) if not re.fullmatch(r"%[a-zA-Z%]", a)]
    env = dict(os.environ)
    # Show the window inside Plasma: KWin's Wayland socket and its Xwayland
    runtime = os.path.join(root, "run/user/1000")
    wayland = newest(os.path.join(runtime, "wayland-[0-9]"))
    xsock = newest(os.path.join(root, "tmp/.X11-unix/X[0-9]*"))
    xauth = newest(os.path.join(runtime, "xauth_*"))
    if wayland:
        env["WAYLAND_DISPLAY"] = wayland
    if xsock:
        env["DISPLAY"] = ":" + os.path.basename(xsock)[1:]
    if xauth:
        env["XAUTHORITY"] = xauth
    # Apps started through batocera-launch (RPCS3, shadPS4 settings...) read
    # the screen mode with wlr-randr, which only labwc answers. A wlr-randr
    # that always asks labwc, first on the PATH, keeps that working while the
    # app's window still opens inside Plasma.
    env["PATH"] = HOST_BIN + ":" + env.get("PATH", "/usr/bin:/bin:/usr/sbin:/sbin")
    print(f"starting {desktop}: {args}", file=log, flush=True)
    try:
        subprocess.Popen(args, env=env, cwd=env.get("HOME", "/userdata/system"),
                         stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                         start_new_session=True, close_fds=True)
    except OSError as e:
        print(f"failed to start {desktop}: {e}", file=log, flush=True)


def make_host_bin():
    """Batocera-side tools that must talk to labwc, not to Plasma's KWin."""
    os.makedirs(HOST_BIN, exist_ok=True)
    wrapper = os.path.join(HOST_BIN, "wlr-randr")
    with open(wrapper, "w") as f:
        f.write("#!/bin/sh\n# The screen belongs to labwc (see kdeplasma-apps.py)\n"
                "WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/var/run exec /usr/bin/wlr-randr \"$@\"\n")
    os.chmod(wrapper, 0o755)


def serve(fifo, root):
    make_host_bin()
    if os.path.exists(fifo):
        os.unlink(fifo)
    os.mkfifo(fifo)
    os.chmod(fifo, 0o622)  # the plasma user may write requests, not read them
    with open(LOG, "a") as log:
        while True:
            with open(fifo) as requests:  # blocks until a menu entry writes
                for line in requests:
                    name = line.strip()
                    if re.fullmatch(r"[A-Za-z0-9._+-]+\.desktop", name):
                        start_app(name, root, log)
                    elif name:
                        print(f"refused: bad request {name!r}", file=log, flush=True)


if __name__ == "__main__":
    if sys.argv[1] == "menu":
        home = sys.argv[2]
        make_client(os.path.dirname(os.path.dirname(home.rstrip("/"))))
        # The menu goes in plasma's home: write it as plasma, never as root,
        # so a link a program in Plasma put there cannot redirect the writes.
        # Relative paths: plasma cannot reach its home through the add-on's
        # folder, which only root may open.
        os.chdir(home)
        if os.getuid() == 0:
            os.setgroups([])
            os.setgid(1000)
            os.setuid(1000)
        make_menu(".")
    elif sys.argv[1] == "serve":
        serve(sys.argv[2], sys.argv[3])
