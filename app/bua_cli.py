#!/usr/bin/env python3
"""bua: command-line package manager for Batocera Unofficial Add-ons.

Installed by the BUA installer to /userdata/system/add-ons/bua/bin/bua; the
symlink_manager service links it into /usr/bin. It runs the same install and
uninstall scripts as the BUA app and shares its install history, so apps
installed from either one show up in both.

The app list comes from app/apps_x86.json or app/apps_arm64.json, which a
GitHub workflow builds from the BUA app's tables.
"""
import argparse
import difflib
import json
import os
import platform
import re
import signal
import subprocess
import sys
import tempfile
from datetime import datetime

REPO_URL = "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main"
INSTALL_CMD = "curl -L install.batoaddons.app | bash"
BUA_UNINSTALL_URL = f"{REPO_URL}/app/uninstall.sh"

ADDONS_DIR = "/userdata/system/add-ons"
BUA_DIR = f"{ADDONS_DIR}/bua"
HISTORY_FILE = f"{ADDONS_DIR}/bua_history.json"

APPS_JSON = {
    "x86_64": "apps_x86.json",
    "aarch64": "apps_arm64.json",
}

# Apps the others depend on are removed last by "remove --all".
REMOVE_LAST = ["Docker"]

# "curl [options] <url> | bash" or "| sh", the form almost every app uses
CURL_PIPE = re.compile(r"^\s*curl\s+(?:-\S+\s+)*(\S+)\s*\|\s*(bash|sh)\s*$")


class BuaError(Exception):
    pass


# ------------------------------
# App list
# ------------------------------

def load_apps() -> dict:
    """Fetch the app list for this device's architecture.

    A copy is kept in BUA_DIR so the app list still works offline.
    """
    arch = platform.machine()
    if arch not in APPS_JSON:
        raise BuaError(f"Unsupported architecture: {arch}")
    json_name = APPS_JSON[arch]
    cache = f"{BUA_DIR}/{json_name}"
    os.makedirs(BUA_DIR, exist_ok=True)

    tmp = f"{cache}.tmp"
    result = subprocess.run(
        ["curl", "-fsSL", "-o", tmp, f"{REPO_URL}/app/{json_name}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    downloaded = False
    if result.returncode == 0:
        try:
            with open(tmp, encoding="utf-8") as f:
                json.load(f)
            os.replace(tmp, cache)
            downloaded = True
        except ValueError:
            pass
    if os.path.exists(tmp):
        os.remove(tmp)
    if not downloaded and os.path.exists(cache):
        print("Could not download the app list, using the saved copy.", file=sys.stderr)

    try:
        with open(cache, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        raise BuaError("Could not download the app list and no saved copy exists.")
    return data


def find_app(apps: list, name: str) -> dict:
    """Match an app by its exact name, ignoring case."""
    for app in apps:
        if app["name"].lower() == name.lower():
            return app
    names = [a["name"] for a in apps]
    lowered = {n.lower(): n for n in names}
    close = difflib.get_close_matches(name.lower(), lowered, n=3, cutoff=0.6)
    hint = ""
    if close:
        hint = " Did you mean: " + ", ".join(f'"{lowered[c]}"' for c in close) + "?"
    raise BuaError(f'No app named "{name}".{hint} Run "bua list" to see every app.')


# ------------------------------
# Install history (shared with the BUA app)
# ------------------------------

def load_history() -> dict:
    try:
        with open(HISTORY_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_history(history: dict):
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, indent=2)


def mark_installed(name: str, success: bool):
    history = load_history()
    history.setdefault(name, []).append({
        "date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "success": success,
    })
    save_history(history)


def mark_uninstalled(name: str):
    history = load_history()
    if name in history:
        del history[name]
        save_history(history)


def installed_names(apps: list) -> set:
    """Apps the BUA app counts as installed: a successful install in the
    history, or a folder in add-ons named after the app."""
    history = load_history()
    found = {n for n, entries in history.items() if any(e.get("success") for e in entries)}
    try:
        items = set(os.listdir(ADDONS_DIR))
    except OSError:
        items = set()
    for app in apps:
        name = app["name"]
        for folder in (name, name.replace(" ", "_"), name.replace(" ", "-")):
            if folder in items:
                found.add(name)
                break
    return found


# ------------------------------
# Running scripts
# ------------------------------

def run_command(cmd: str, extra_args: list) -> int:
    """Run an install or uninstall command from the app list.

    "curl <url> | bash" commands are downloaded first, so a missing script is
    reported instead of running nothing, and extra arguments reach the script.
    Returns the script's exit code, or None when the script doesn't exist.
    """
    match = CURL_PIPE.match(cmd)
    if not match:
        return subprocess.run(["bash", "-c", cmd]).returncode

    url, shell = match.groups()
    fd, script = tempfile.mkstemp(prefix="bua-", suffix=".sh")
    os.close(fd)
    try:
        result = subprocess.run(["curl", "-fsL", "-o", script, url])
        if result.returncode != 0:
            return None
        # Only bash scripts take --ignore-warning, as in the BUA app.
        args = extra_args if shell == "bash" else []
        return subprocess.run([shell, script, *args]).returncode
    finally:
        os.remove(script)


def confirm(question: str, ignore_warning: bool) -> bool:
    if ignore_warning:
        return True
    try:
        answer = input(f"{question} [y/N] ")
    except EOFError:
        print("\nNo answer given; add --ignore-warning to go ahead without asking.")
        return False
    return answer.strip().lower() in ("y", "yes")


def install_app(app: dict) -> bool:
    print(f"==> Installing {app['name']}")
    code = run_command(app["install"], [])
    if code is None:
        print(f"Could not download the install script for {app['name']}.")
        return False
    mark_installed(app["name"], code == 0)
    if code != 0:
        print(f"{app['name']}: install script failed (exit code {code}).")
        return False
    print(f"{app['name']} installed.")
    return True


def remove_app(app: dict, ignore_warning: bool) -> bool:
    print(f"==> Removing {app['name']}")
    if not app.get("uninstall"):
        print(f"{app['name']} has no uninstall script.")
        return False
    args = ["--ignore-warning"] if ignore_warning else []
    code = run_command(app["uninstall"], args)
    if code is None:
        print(f"{app['name']} has no uninstall script.")
        return False
    if code != 0:
        print(f"{app['name']} was not removed (exit code {code}).")
        return False
    mark_uninstalled(app["name"])
    print(f"{app['name']} removed.")
    return True


# ------------------------------
# Commands
# ------------------------------

def cmd_list(args) -> int:
    apps = load_apps()["apps"]
    if args.filter:
        installed = installed_names(apps)
        want = args.filter == "installed"
        apps = [a for a in apps if (a["name"] in installed) == want]
    if not apps:
        print("No apps.")
        return 0
    width = max(len(a["name"]) for a in apps)
    for app in apps:
        print(f"{app['name']:<{width}}  {app['description']}".rstrip())
    return 0


def cmd_add(args) -> int:
    apps = load_apps()["apps"]
    chosen = [find_app(apps, n) for n in args.apps]
    failed = [a["name"] for a in chosen if not install_app(a)]
    return report(failed, "install")


def cmd_remove(args) -> int:
    apps = load_apps()["apps"]
    if args.all:
        if args.apps:
            raise BuaError("Give app names or --all, not both.")
        return remove_all(apps, args.ignore_warning)
    if not args.apps:
        raise BuaError('Name at least one app to remove, or use --all. See "bua remove --help".')

    chosen = [find_app(apps, n) for n in args.apps]
    installed = installed_names(apps)
    failed = []
    for app in chosen:
        if app["name"] not in installed:
            print(f"{app['name']} is not installed, skipping.")
            continue
        if not remove_app(app, args.ignore_warning):
            failed.append(app["name"])
    return report(failed, "remove")


def remove_all(apps: list, ignore_warning: bool) -> int:
    """Remove every installed app, asking first unless ignore_warning."""
    installed = installed_names(apps)
    chosen = [a for a in apps if a["name"] in installed]
    chosen.sort(key=lambda a: a["name"] in REMOVE_LAST)
    if not chosen:
        print("No apps are installed.")
        return 0

    if not ignore_warning:
        print("This removes every installed app:")
        for app in chosen:
            print(f"  {app['name']}")
        if not confirm("Remove them all?", False):
            print("Nothing was removed.")
            return 1

    failed = [a["name"] for a in chosen if not remove_app(a, True)]
    return report(failed, "remove")


def cmd_update(args) -> int:
    print("==> Updating BUA")
    code = subprocess.run(["bash", "-c", INSTALL_CMD]).returncode
    if code != 0:
        print(f"The BUA installer failed (exit code {code}).")
        return 1
    changelog = load_apps().get("changelog", "").strip()
    if changelog:
        print("\nWhat's new:\n" + changelog)
    return 0


def cmd_uninstall(args) -> int:
    if not confirm("This removes every installed app and BUA itself. Continue?", args.ignore_warning):
        print("Nothing was removed.")
        return 1

    apps = load_apps()["apps"]
    installed = installed_names(apps)
    chosen = [a for a in apps if a["name"] in installed]
    chosen.sort(key=lambda a: a["name"] in REMOVE_LAST)
    failed = [a["name"] for a in chosen if not remove_app(a, True)]
    if failed:
        # uninstall.sh finds what is left on the device and asks about it.
        print("These apps could not be removed: " + ", ".join(failed))

    print("==> Removing BUA")
    script_args = ["--ignore-warning"] if args.ignore_warning else []
    code = run_command(f"curl -L {BUA_UNINSTALL_URL} | bash", script_args)
    if code is None:
        print("Could not download the BUA uninstall script.")
        return 1
    if code != 0:
        print(f"The BUA uninstall script failed (exit code {code}).")
        return 1
    return 0


def report(failed: list, verb: str) -> int:
    if failed:
        print(f"\nCould not {verb}: " + ", ".join(failed))
        return 1
    return 0


# ------------------------------
# Command line
# ------------------------------

EPILOG = """\
App names are matched exactly, ignoring case. Quote names that have spaces:
  bua add "Java Runtime" firefox
  bua remove VLC "Arch KDE (Webtop)" --ignore-warning
"""


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="bua",
        description="Install and remove Batocera Unofficial Add-ons from the command line.",
        epilog=EPILOG,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    sub = parser.add_subparsers(dest="command", metavar="<command>")

    p = sub.add_parser("list", help="list every app with its description")
    p.add_argument("filter", nargs="?", choices=["installed", "uninstalled"],
                   help="only installed or only not installed apps")
    p.set_defaults(func=cmd_list)

    p = sub.add_parser("add", help="install one or more apps")
    p.add_argument("apps", nargs="+", metavar="app")
    p.set_defaults(func=cmd_add)

    p = sub.add_parser("remove", help="uninstall one or more apps, or all of them")
    p.add_argument("apps", nargs="*", metavar="app")
    p.add_argument("--all", action="store_true",
                   help="remove every installed app (asks first)")
    p.add_argument("--ignore-warning", action="store_true",
                   help="answer yes to every question")
    p.set_defaults(func=cmd_remove)

    p = sub.add_parser("update", help="update BUA and show what's new")
    p.set_defaults(func=cmd_update)

    p = sub.add_parser("uninstall", help="remove every app and BUA itself (asks first)")
    p.add_argument("--ignore-warning", action="store_true",
                   help="don't ask anything")
    p.set_defaults(func=cmd_uninstall)

    return parser


def main() -> int:
    # Keep our lines in order with the scripts' output when piped to a file.
    sys.stdout.reconfigure(line_buffering=True)
    # Exit quietly when the output is cut short, as in "bua list | head".
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    parser = build_parser()
    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        return 0
    try:
        return args.func(args)
    except BuaError as e:
        print(f"bua: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print()
        return 130


if __name__ == "__main__":
    sys.exit(main())
