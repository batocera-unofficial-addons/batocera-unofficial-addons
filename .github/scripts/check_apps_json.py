#!/usr/bin/env python3
"""Check app/apps_x86.json and app/apps_arm64.json, the app lists that the BUA
menu and the bua command read.

The files are edited by hand, so this catches mistakes before they reach
devices. Every app needs an install command, an uninstaller, a description
and a category; anything missing fails the check.
"""
import json
import os
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

APP_LISTS = ["app/apps_x86.json", "app/apps_arm64.json"]

# The categories the menu has a screen for (get_top_level() in the menu files).
# An app in any other category can't be reached from the menu.
CATEGORIES = {
    "Games",
    "Windows Freeware",
    "Game Utilities",
    "System Utilities",
    "Developer Tools",
    "Docker Menu",
}

# Apps with their own item on the menu's main screen, so no category
NO_CATEGORY = {"Custom Wine"}

# Apps that had no working uninstaller when this check was added. Don't add to
# this list: write the uninstaller (or fix the "uninstall" entry) and remove
# the app from here. The check fails if a listed app has a working one.
KNOWN_MISSING_UNINSTALL = {
    "app/apps_x86.json": {
        # No uninstall script in the repo
        "AM2R",
        "Android",
        "EGGNOGG+",
        "Gamescope",
        "Heroic",
        "Overlay Remove",
        "Raspberry Pi Imager",
        "Sandtrix",
        "SCP Containment Breach",
        "Secret Maryo Chronicles",
        "SHRUBNAUT",
        "Sonic 3D in 2D",
        "Sonic Time Twisted",
        "Streets of Rage Remake",
        "Stremio",
        "Super Crate Box",
        "Unreal Tournament",
        "Winconfig (Windows Game Fix)",
        "Wine Dependencies x64",
        "Wine Manager",
        "Zero-K",
        # Only an uninstaller for an older installer exists
        "F1",
        "Itch.io",
        "Minecraft",
        "Steam",
        # Installed from outside the repo
        "iso2zar",
        "npsget",
        "RGSX",
    },
    "app/apps_arm64.json": {
        # No uninstall script in the repo
        "Overlay Remove",
        "Raspberry Pi Imager",
        # Points at an -arm64 name; the add-on's uninstaller has another name
        "Amazon Luna",
        "Greenlight",
        "Sunshine",
        # Only an uninstaller for an older installer exists
        "F1",
        # Installed from outside the repo
        "iso2zar",
        "npsget",
        "RGSX",
    },
}

# A script in this repo, in any of the URL forms the app lists use
REPO_SCRIPT = re.compile(
    r"batocera-unofficial-addons/batocera-unofficial-addons/"
    r"(?:raw/refs/heads/main|raw/main|main)/(\S+?\.sh)(?=\s|$)"
)


def repo_script(command: str):
    match = REPO_SCRIPT.search(command)
    return match.group(1) if match else None


def uninstall_problem(uninstall):
    """Why the uninstall entry doesn't work, or None if it does."""
    if not uninstall:
        return "has no uninstall command"
    script = repo_script(uninstall)
    if script and not (REPO_ROOT / script).is_file():
        return f"uninstall script {script} is not in the repo"
    return None


def check(rel: str) -> tuple[list[str], list[str], int]:
    """Return the errors and warnings for one app list, and its app count."""
    errors: list[str] = []
    warnings: list[str] = []
    known_missing = KNOWN_MISSING_UNINSTALL.get(rel, set())
    try:
        data = json.loads((REPO_ROOT / rel).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        return [f"{rel}: not valid JSON: {e}"], [], 0

    if not isinstance(data, dict) or not isinstance(data.get("apps"), list):
        return [f'{rel}: must be an object with an "apps" list'], [], 0
    if not isinstance(data.get("changelog", ""), str):
        errors.append(f'{rel}: "changelog" must be a string')

    seen: dict[str, str] = {}
    for i, app in enumerate(data["apps"]):
        if not isinstance(app, dict):
            errors.append(f"{rel}: entry {i} is not an object")
            continue
        name = app.get("name")
        if not isinstance(name, str) or not name.strip():
            errors.append(f'{rel}: entry {i} has no "name"')
            continue
        where = f'{rel}: "{name}"'

        # The bua command matches names ignoring case
        if name.lower() in seen:
            errors.append(f'{where} is listed twice (also as "{seen[name.lower()]}")')
        seen[name.lower()] = name

        install = app.get("install")
        if not isinstance(install, str) or not install.strip():
            errors.append(f'{where} has no "install" command')
        else:
            script = repo_script(install)
            if script and not (REPO_ROOT / script).is_file():
                errors.append(f"{where}: install script {script} is not in the repo")

        uninstall = app.get("uninstall")
        if uninstall is not None and not isinstance(uninstall, str):
            errors.append(f'{where}: "uninstall" must be a string or null')
        else:
            problem = uninstall_problem(uninstall)
            if name in known_missing:
                if problem:
                    warnings.append(f"{where} {problem} (known, listed in check_apps_json.py)")
                else:
                    errors.append(
                        f"{where} has a working uninstaller now; "
                        "remove it from KNOWN_MISSING_UNINSTALL in check_apps_json.py"
                    )
            elif problem:
                errors.append(f"{where} {problem}")

        description = app.get("description", "")
        if not isinstance(description, str):
            errors.append(f'{where}: "description" must be a string')
        elif not description.strip():
            errors.append(f"{where} has no description")

        categories = app.get("categories", [])
        if not isinstance(categories, list) or not all(isinstance(c, str) for c in categories):
            errors.append(f'{where}: "categories" must be a list of names')
            continue
        for category in categories:
            if category not in CATEGORIES:
                errors.append(
                    f'{where}: unknown category "{category}" '
                    f"(use one of: {', '.join(sorted(CATEGORIES))})"
                )
        if not categories and name not in NO_CATEGORY:
            errors.append(f"{where} is not in any category")

    for name in sorted(known_missing - set(seen.values())):
        errors.append(
            f'{rel}: "{name}" is in KNOWN_MISSING_UNINSTALL but not in the app list; '
            "remove it from check_apps_json.py"
        )

    return errors, warnings, len(data["apps"])


def summary_section(rel: str, errors: list[str], warnings: list[str], count: int) -> str:
    """One app list's part of the job summary, in Markdown."""
    if errors:
        lines = [f"### ❌ {rel}: {len(errors)} problem(s)", ""]
        lines += [f"- {e.removeprefix(rel + ': ')}" for e in errors]
    else:
        lines = [f"### ✅ {rel}: OK ({count} apps)"]
    if warnings:
        lines += ["", f"<details><summary>{len(warnings)} known gap(s)</summary>", ""]
        lines += [f"- {w.removeprefix(rel + ': ')}" for w in warnings]
        lines += ["", "</details>"]
    return "\n".join(lines) + "\n\n"


def main() -> int:
    failed = False
    summary = "## App list check\n\n"
    for rel in APP_LISTS:
        errors, warnings, count = check(rel)
        # ::warning:: and ::error:: lines show up as annotations on GitHub
        for w in warnings:
            print(f"::warning::{w}")
        for e in errors:
            print(f"::error::{e}")
        if errors:
            failed = True
        else:
            print(f"{rel}: OK ({count} apps)")
        summary += summary_section(rel, errors, warnings, count)

    # GitHub shows this file on the run's summary page
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write(summary)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
