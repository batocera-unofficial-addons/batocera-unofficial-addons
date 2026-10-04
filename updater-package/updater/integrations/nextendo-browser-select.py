#!/usr/bin/env python3

from pathlib import Path
import json
import os
import shlex
import shutil
import subprocess
import sys

CONFIG = Path("/userdata/system/configs/bua/nextendo-browser.json")

URL = sys.argv[1] if len(sys.argv) > 1 else ""

if not URL.startswith(("http://", "https://")):
    raise SystemExit(2)


def add_browser(items, name, command):
    if not command:
        return

    command = [str(x) for x in command if str(x).strip()]

    if not command:
        return

    key = tuple(command)

    if any(tuple(x["command"]) == key for x in items):
        return

    items.append({
        "name": name.strip() or command[0],
        "command": command,
    })


def command_exists(command):
    if not command:
        return False

    exe = command[0]

    if exe.startswith("/"):
        return Path(exe).is_file() and os.access(exe, os.X_OK)

    return shutil.which(exe) is not None


def clean_desktop_exec(value):
    try:
        parts = shlex.split(value)
    except Exception:
        return None

    cleaned = []

    field_codes = {
        "%f", "%F", "%u", "%U",
        "%d", "%D", "%n", "%N",
        "%i", "%c", "%k", "%v", "%m",
    }

    for part in parts:
        if part in field_codes:
            continue

        # Remove embedded desktop field codes.
        for code in field_codes:
            part = part.replace(code, "")

        part = part.strip()

        if part:
            cleaned.append(part)

    return cleaned or None


def parse_desktop_file(path):
    try:
        text = path.read_text(
            encoding="utf-8",
            errors="ignore",
        )
    except Exception:
        return None

    in_entry = False
    values = {}

    for raw in text.splitlines():
        line = raw.strip()

        if line == "[Desktop Entry]":
            in_entry = True
            continue

        if line.startswith("[") and line.endswith("]"):
            if in_entry:
                break
            continue

        if not in_entry or not line or line.startswith("#"):
            continue

        if "=" not in line:
            continue

        key, value = line.split("=", 1)

        if key in {
            "Name",
            "GenericName",
            "Exec",
            "Categories",
            "MimeType",
            "NoDisplay",
            "Hidden",
            "Type",
        }:
            values[key] = value.strip()

    if values.get("Type", "Application") != "Application":
        return None

    if values.get("Hidden", "").lower() == "true":
        return None

    name = values.get("Name", path.stem)
    generic = values.get("GenericName", "")
    categories = values.get("Categories", "")
    mimetype = values.get("MimeType", "")
    execline = values.get("Exec", "")

    browserish = (
        "WebBrowser" in categories
        or "x-scheme-handler/http" in mimetype
        or "x-scheme-handler/https" in mimetype
        or "web browser" in generic.lower()
    )

    if not browserish or not execline:
        return None

    command = clean_desktop_exec(execline)

    if not command or not command_exists(command):
        return None

    return {
        "name": name,
        "command": command,
    }


def detect_desktop_browsers(browsers):
    roots = [
        Path("/usr/share/applications"),
        Path("/userdata/system/.local/share/applications"),
        Path("/userdata/system/share/applications"),
        Path("/userdata/system/add-ons"),
        Path("/userdata/system/.local/share/flatpak/exports/share/applications"),
        Path("/userdata/saves/flatpak/data/.local/share/flatpak/exports/share/applications"),
    ]

    seen_files = set()

    for root in roots:
        if not root.is_dir():
            continue

        try:
            files = root.rglob("*.desktop")
        except Exception:
            continue

        for path in files:
            try:
                resolved = str(path.resolve())
            except Exception:
                resolved = str(path)

            if resolved in seen_files:
                continue

            seen_files.add(resolved)

            browser = parse_desktop_file(path)

            if browser:
                add_browser(
                    browsers,
                    browser["name"],
                    browser["command"],
                )


def detect_browsers():
    browsers = []

    # Known/common AppImage locations.
    candidates = [
        ("Firefox", "/userdata/system/add-ons/firefox/Firefox.AppImage"),
        ("LibreWolf", "/userdata/system/add-ons/librewolf/LibreWolf.AppImage"),
        ("Floorp", "/userdata/system/add-ons/floorp/Floorp.AppImage"),
        ("Chromium", "/userdata/system/add-ons/chromium/Chromium.AppImage"),
        ("Brave", "/userdata/system/add-ons/brave/Brave.AppImage"),
        ("Google Chrome", "/userdata/system/add-ons/chrome/Chrome.AppImage"),
        ("Vivaldi", "/userdata/system/add-ons/vivaldi/Vivaldi.AppImage"),
        ("Opera", "/userdata/system/add-ons/opera/Opera.AppImage"),
    ]

    for name, value in candidates:
        p = Path(value)

        if p.is_file() and os.access(p, os.X_OK):
            add_browser(browsers, name, [str(p)])

    # Discover browser AppImages in common user-controlled locations.
    appimage_roots = [
        Path("/userdata/system/add-ons"),
        Path("/userdata/roms/ports"),
        Path("/userdata/roms/windows"),
    ]

    browser_tokens = {
        "firefox": "Firefox",
        "librewolf": "LibreWolf",
        "floorp": "Floorp",
        "chromium": "Chromium",
        "chrome": "Google Chrome",
        "brave": "Brave",
        "vivaldi": "Vivaldi",
        "opera": "Opera",
        "browser": "Web Browser",
    }

    for root in appimage_roots:
        if not root.is_dir():
            continue

        try:
            files = root.rglob("*.AppImage")
        except Exception:
            continue

        for p in files:
            low = p.name.lower()

            for token, display in browser_tokens.items():
                if token in low and os.access(p, os.X_OK):
                    add_browser(
                        browsers,
                        display,
                        [str(p)],
                    )
                    break

    # Native executables available through PATH.
    native = [
        ("Firefox", "firefox"),
        ("LibreWolf", "librewolf"),
        ("Floorp", "floorp"),
        ("Chromium", "chromium"),
        ("Chromium", "chromium-browser"),
        ("Google Chrome", "google-chrome"),
        ("Google Chrome", "google-chrome-stable"),
        ("Brave", "brave-browser"),
        ("Vivaldi", "vivaldi"),
        ("Opera", "opera"),
        ("Microsoft Edge", "microsoft-edge"),
    ]

    for name, exe in native:
        found = shutil.which(exe)

        if found:
            add_browser(
                browsers,
                name,
                [found],
            )

    # Explicit common Flatpak browser IDs.
    flatpaks = [
        ("Firefox", "org.mozilla.firefox"),
        ("Chromium", "org.chromium.Chromium"),
        ("Google Chrome", "com.google.Chrome"),
        ("Brave", "com.brave.Browser"),
        ("LibreWolf", "io.gitlab.librewolf-community"),
        ("Vivaldi", "com.vivaldi.Vivaldi"),
        ("Microsoft Edge", "com.microsoft.Edge"),
    ]

    if shutil.which("flatpak"):
        try:
            installed = subprocess.check_output(
                ["flatpak", "list", "--columns=application"],
                text=True,
                stderr=subprocess.DEVNULL,
            ).splitlines()

            installed = {
                x.strip()
                for x in installed
                if x.strip()
            }

            for name, appid in flatpaks:
                if appid in installed:
                    add_browser(
                        browsers,
                        name + " (Flatpak)",
                        ["flatpak", "run", appid],
                    )
        except Exception:
            pass

    # Finally, discover browsers registered with the desktop.
    detect_desktop_browsers(browsers)

    return browsers


def load_saved(browsers):
    try:
        data = json.loads(
            CONFIG.read_text(encoding="utf-8")
        )

        command = data.get("command")

        if not isinstance(command, list):
            return None

        for browser in browsers:
            if browser["command"] == command:
                return browser

    except Exception:
        pass

    return None


def save_browser(browser):
    CONFIG.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    CONFIG.write_text(
        json.dumps(browser, indent=2) + "\n",
        encoding="utf-8",
    )


def choose_with_pygame(browsers):
    import pygame

    os.environ.setdefault("DISPLAY", ":0")
    os.environ.setdefault(
        "XAUTHORITY",
        "/.Xauthority",
    )

    pygame.init()
    pygame.joystick.init()

    screen = pygame.display.set_mode((760, 500))
    pygame.display.set_caption(
        "NexTendo Browser Selection"
    )

    font = pygame.font.Font(None, 38)
    small = pygame.font.Font(None, 28)

    selected = 0
    offset = 0
    visible_rows = 6

    clock = pygame.time.Clock()

    while True:
        if selected < offset:
            offset = selected

        if selected >= offset + visible_rows:
            offset = selected - visible_rows + 1

        screen.fill((24, 24, 24))

        title = font.render(
            "Choose browser for NexTendo sign-in",
            True,
            (240, 240, 240),
        )
        screen.blit(title, (40, 35))

        subtitle = small.render(
            "Use Up/Down and Enter/A",
            True,
            (180, 180, 180),
        )
        screen.blit(subtitle, (40, 80))

        y = 135

        visible = browsers[
            offset:offset + visible_rows
        ]

        for row, browser in enumerate(visible):
            index = offset + row

            if index == selected:
                pygame.draw.rect(
                    screen,
                    (70, 100, 170),
                    (30, y - 8, 700, 48),
                    border_radius=8,
                )

            txt = small.render(
                browser["name"],
                True,
                (255, 255, 255),
            )

            screen.blit(txt, (50, y))
            y += 55

        pygame.display.flip()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                raise SystemExit(1)

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    selected = (
                        selected - 1
                    ) % len(browsers)

                elif event.key == pygame.K_DOWN:
                    selected = (
                        selected + 1
                    ) % len(browsers)

                elif event.key in (
                    pygame.K_RETURN,
                    pygame.K_KP_ENTER,
                    pygame.K_SPACE,
                ):
                    pygame.quit()
                    return browsers[selected]

                elif event.key == pygame.K_ESCAPE:
                    pygame.quit()
                    raise SystemExit(1)

            if event.type == pygame.JOYHATMOTION:
                if event.value[1] > 0:
                    selected = (
                        selected - 1
                    ) % len(browsers)

                elif event.value[1] < 0:
                    selected = (
                        selected + 1
                    ) % len(browsers)

            if event.type == pygame.JOYBUTTONDOWN:
                if event.button in (0, 1):
                    pygame.quit()
                    return browsers[selected]

        clock.tick(30)


def launch(browser):
    log = open(
        "/tmp/nextendo-browser.log",
        "ab",
        buffering=0,
    )

    env = os.environ.copy()

    # DISPLAY, XAUTHORITY and XDG_RUNTIME_DIR are resolved by
    # the xdg-open wrapper. Preserve those inherited values here.

    # Emulator-launched processes can run in a context where
    # AppImage FUSE mounting is not permitted. Avoid fusermount.
    env["APPIMAGE_EXTRACT_AND_RUN"] = "1"

    proc = subprocess.Popen(
        browser["command"] + [URL],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=log,
        start_new_session=True,
        env=env,
    )

    # The selector itself is launched in the background by xdg-open,
    # so it is safe to wait here for the OAuth browser to close.
    #
    # Batocera/Openbox may otherwise return focus to EmulationStation
    # instead of the running Ryujinx window.
    try:
        proc.wait()
    except Exception:
        pass

    try:
        result = subprocess.run(
            [
                "xdotool",
                "search",
                "--onlyvisible",
                "--name",
                "^Ryujinx",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=env,
            check=False,
        )

        windows = [
            line.strip()
            for line in result.stdout.splitlines()
            if line.strip().isdigit()
        ]

        if windows:
            window = windows[-1]

            subprocess.run(
                [
                    "xdotool",
                    "windowraise",
                    window,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                check=False,
            )

            # windowactivate can leave EmulationStation as the active
            # window on Batocera. Direct X input focus reliably returns
            # control to Ryujinx; Ryujinx may then redirect focus to its
            # own modal ContentDialogOverlayWindow.
            subprocess.run(
                [
                    "xdotool",
                    "windowfocus",
                    "--sync",
                    window,
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=env,
                check=False,
            )
    except Exception as exc:
        try:
            log.write(
                (
                    "[Nextendo] Ryujinx focus restore failed: "
                    + str(exc)
                    + "\n"
                ).encode("utf-8", "replace")
            )
        except Exception:
            pass


browsers = detect_browsers()

if not browsers:
    print(
        "[Nextendo] No registered web browser detected.",
        file=sys.stderr,
    )
    raise SystemExit(1)

browser = load_saved(browsers)

if browser is None:
    if len(browsers) == 1:
        browser = browsers[0]
    else:
        browser = choose_with_pygame(browsers)

    save_browser(browser)

print(
    f"[Nextendo] Browser: {browser['name']}"
)

launch(browser)
