#!/usr/bin/env python3
"""
Add Non-Steam Games — Pygame UI with controller support.
Flow: Scanning → Scan results (Cancel+OK) → Exe picker per dir (Cancel+OK) → Final confirm (Cancel+OK).
"""

import os
import sys

LOG = "/tmp/add-non-steam-game.log"
def _log(msg):
    try:
        with open(LOG, "a") as f:
            f.write(f"{msg}\n")
    except Exception:
        pass
# Clear log at start of each run for fresh debug
try:
    open(LOG, "w").close()
except Exception:
    pass
import subprocess
import binascii
import urllib.request

# Pygame
import pygame

# Paths
STEAM_DIR = "/userdata/system/add-ons/steam"
STEAM_APPS = f"{STEAM_DIR}/.local/share/Steam/steamapps"
GAMES_DIR = f"{STEAM_DIR}/non-steam-games"
ROMS_ROOT = "/userdata/.roms_base" if os.path.isdir("/userdata/.roms_base") else "/userdata/roms"
ROMS_DIR = f"{ROMS_ROOT}/steam"
GAMELIST = f"{ROMS_DIR}/gamelist.xml"

# Controller (Xbox/Steam Deck layout)
BTN_A, BTN_B, BTN_X, BTN_Y = 0, 1, 2, 3
BTN_LB, BTN_RB, BTN_BACK, BTN_START = 4, 5, 6, 7

# Colors
BG = (20, 22, 28)
CARD = (35, 40, 52)
ACCENT = (59, 130, 246)
FG = (248, 250, 252)
FG_DIM = (148, 163, 184)

os.makedirs(GAMES_DIR, exist_ok=True)
os.makedirs(ROMS_DIR, exist_ok=True)
os.makedirs(f"{ROMS_DIR}/images", exist_ok=True)


def clean_exit(code=0):
    """Same pattern as BUA installer (bua_installerarm64.py): normal exit returns to ES."""
    try:
        pygame.event.set_grab(False)
        pygame.display.quit()
        pygame.quit()
    except Exception:
        pass
    try:
        subprocess.run(["killall", "emulationstation"], timeout=2, capture_output=True)
    except Exception:
        pass
    sys.exit(code)


def detect_proton():
    common = f"{STEAM_APPS}/common"
    if not os.path.isdir(common):
        return "Proton - Experimental"
    # Prefer Proton 10/9 (better controller support than Experimental for some games)
    for pname in ("Proton 10.0", "Proton 9.0"):
        ppath = os.path.join(common, pname, "proton")
        if os.path.isfile(ppath) and os.access(ppath, os.X_OK):
            return pname
    exp_path = os.path.join(common, "Proton - Experimental", "proton")
    if os.path.isfile(exp_path) and os.access(exp_path, os.X_OK):
        return "Proton - Experimental"
    best, best_ver = "", 0
    for name in sorted(os.listdir(common)):
        if name.startswith("Proton"):
            proton = os.path.join(common, name, "proton")
            if os.path.isfile(proton) and os.access(proton, os.X_OK):
                import re
                m = re.search(r"[\d.]+", name)
                ver = m.group(0) if m else ""
                if ver:
                    parts = ver.split(".")
                    int_ver = int(parts[0]) * 1000 + (int(parts[1]) if len(parts) > 1 else 0)
                    if int_ver > best_ver:
                        best_ver, best = int_ver, name
    return best or "Proton - Experimental"


def generate_shortcut_id(exe_path):
    return binascii.crc32(exe_path.encode()) & 0xFFFFFFFF | 0x80000000


def scan_games():
    """Return list of (game_name, [exe_paths]) for folders with .exe not yet added."""
    games = []
    for name in sorted(os.listdir(GAMES_DIR)):
        d = os.path.join(GAMES_DIR, name)
        if not os.path.isdir(d):
            continue
        exes = sorted([os.path.join(d, f) for f in os.listdir(d) if f.lower().endswith(".exe")])
        if not exes:
            continue
        slug = "".join(c if c.isalnum() or c in "_-" else "_" for c in name)[:80]
        skip = False
        for exe in exes:
            sid = generate_shortcut_id(exe)
            if os.path.isfile(f"{ROMS_DIR}/{sid}_{slug}.sh"):
                skip = True
                break
        if skip:
            continue
        games.append((name, exes))
    return games


# Steam Deck controller SDL mapping (Xbox layout) — helps Proton/Wine games recognize controller
# Source: SDL gamecontrollerdb, Steam Deck GUID 03000000de2800000512000011010000
SDL_STEAM_DECK_MAP = (
    "03000000de2800000512000011010000,Steam Deck Controller,a:b0,b:b1,back:b6,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,dpup:h0.1,"
    "guide:b10,leftshoulder:b4,leftstick:b8,lefttrigger:a2,leftx:a0,lefty:a1,rightshoulder:b5,rightstick:b9,righttrigger:a5,"
    "rightx:a3,righty:a4,start:b7,x:b2,y:b3,platform:Linux"
)


def create_launcher(game_name, exe_path, shortcut_id, slug, proton_name):
    start_dir = os.path.dirname(exe_path)
    sh_file = f"{ROMS_DIR}/{shortcut_id}_{slug}.sh"
    content = f"""#!/bin/bash
export DISPLAY=:0.0
export RIM_ALLOW_ROOT=1
export HOME={STEAM_DIR}
ulimit -H -n 819200 && ulimit -S -n 819200

# Steam Deck controller: allow detection (Steam blacklists 28de:1205 via SDL_GAMECONTROLLER_IGNORE_DEVICES)
unset SDL_GAMECONTROLLER_IGNORE_DEVICES
# SDL mapping for Proton/Wine (no Steam Input)
export SDL_GAMECONTROLLERCONFIG="{SDL_STEAM_DECK_MAP}"

STEAM_DIR="{STEAM_DIR}"
STEAM_APPS="${{STEAM_DIR}}/.local/share/Steam/steamapps"
COMPAT_DATA="${{STEAM_APPS}}/compatdata/{shortcut_id}"
export STEAM_COMPAT_DATA_PATH="$COMPAT_DATA"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${{STEAM_DIR}}/.local/share/Steam"
export STEAM_COMPAT_APP_ID={shortcut_id}
PROTON_PATH="${{STEAM_APPS}}/common/{proton_name}/proton"

if [ ! -d "$COMPAT_DATA/pfx" ]; then
  mkdir -p "$COMPAT_DATA"
  "$PROTON_PATH" run wineboot -u
fi

cd "{start_dir}" || exit 1
"$PROTON_PATH" run "{exe_path}" &
PID=$!
wait $PID

pkill -f proton 2>/dev/null || true
pkill -f steam 2>/dev/null || true
pkill -f steamwebhelper 2>/dev/null || true
"""
    with open(sh_file, "w") as f:
        f.write(content)
    os.chmod(sh_file, 0o755)
    keys_file = f"{sh_file}.keys"
    with open(keys_file, "w") as f:
        f.write('''{
    "actions_player1": [
        {
            "trigger": ["hotkey", "start"],
            "type": "exec",
            "target": "/userdata/system/add-ons/steam/extra/force-exit-non-steam-game.sh",
            "description": "Exit game, release input, restart ES"
        }
    ]
}
''')


def add_gamelist_entry(game_name, shortcut_id, slug):
    sh_basename = f"{shortcut_id}_{slug}.sh"
    with open(GAMELIST, "r") as f:
        content = f.read()
    if f"<path>./{sh_basename}</path>" in content:
        return
    entry = f"""  <game>
    <path>./{sh_basename}</path>
    <name>{game_name}</name>
    <genre>Non-Steam</genre>
    <lang>en</lang>
  </game>
</gameList>
"""
    content = content.replace("</gameList>", entry)
    with open(GAMELIST, "w") as f:
        f.write(content)


def ensure_gamelist():
    if not os.path.isfile(GAMELIST):
        with open(GAMELIST, "w") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n<gameList>\n</gameList>\n')


def reload_es():
    try:
        urllib.request.urlopen("http://127.0.0.1:1234/reloadgames", timeout=5)
    except Exception:
        pass


# --- Pygame UI ---
# Wayland: wrapper sets DISPLAY=:0 + SDL_VIDEODRIVER=x11 for XWayland
import os as _os
_os.environ.setdefault("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1")
try:
    _log(f"DISPLAY={_os.environ.get('DISPLAY')} SDL_VIDEODRIVER={_os.environ.get('SDL_VIDEODRIVER')}")
    pygame.init()
    _log("pygame.init OK")
    pygame.mouse.set_visible(True)
    display_info = pygame.display.Info()
    w, h = display_info.current_w, display_info.current_h
    _log(f"display_info: {w}x{h}")
    if w < 320 or h < 240:
        modes = pygame.display.list_modes()
        if modes and modes != -1:
            w, h = modes[0]
            _log(f"fallback from list_modes: {w}x{h}")
        else:
            w, h = 1280, 720
            _log(f"fallback default: {w}x{h}")
    try:
        screen = pygame.display.set_mode((w, h), pygame.FULLSCREEN)
        _log(f"set_mode FULLSCREEN {w}x{h} OK")
    except pygame.error as e:
        _log(f"set_mode FULLSCREEN failed: {e}")
        try:
            screen = pygame.display.set_mode((1280, 720), pygame.FULLSCREEN)
            _log("set_mode 1280x720 FULLSCREEN OK")
        except pygame.error as e2:
            _log(f"set_mode 1280x720 FULLSCREEN failed: {e2}")
            screen = pygame.display.set_mode((1280, 720))
            _log("set_mode 1280x720 windowed OK")
except Exception as e:
    _log(f"init error: {e}")
    import traceback
    _log(traceback.format_exc())
    raise

# Show loading splash immediately (like BUA) — user sees something while rest loads
def _show_loading_splash():
    screen.fill(BG)
    font = pygame.font.Font(None, 72)
    text = font.render("Loading...", True, FG)
    text_rect = text.get_rect(center=(screen.get_width() // 2, screen.get_height() // 2))
    screen.blit(text, text_rect)
    pygame.display.flip()

_show_loading_splash()

pygame.event.set_grab(True)  # Grab input so we get controller/keys, not ES
W, H = screen.get_size()
UI_SCALE = max(1.0, min(W / 1280.0, H / 720.0))

def S(n):
    return int(round(n * UI_SCALE))

FONT = pygame.font.Font(None, S(36))
FONT_BIG = pygame.font.Font(None, S(48))

SCREENS = []


def push_screen(s):
    SCREENS.append(s)


def pop_screen():
    if SCREENS:
        SCREENS.pop()
    if not SCREENS:
        clean_exit(0)


def draw_text(surf, text, font, color, pos):
    img = font.render(str(text), True, color)
    surf.blit(img, pos)




class BaseScreen:
    def handle(self, events):
        pass

    def draw(self):
        pass


class ScanningScreen(BaseScreen):
    """Step 1: Scanning... Cancel only, no OK yet."""
    def __init__(self):
        self.done = False

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
                clean_exit(0)
            if e.type == pygame.JOYBUTTONDOWN and e.button in (BTN_B, BTN_BACK):
                clean_exit(0)
        if not self.done:
            self.done = True
            games = scan_games()
            if not games:
                SCREENS.pop()
                push_screen(NoGamesScreen())
            else:
                SCREENS.pop()
                push_screen(ScanResultsScreen(games))

    def draw(self):
        screen.fill(BG)
        draw_text(screen, "Add Non-Steam Games", FONT_BIG, FG, (S(50), S(80)))
        draw_text(screen, "Scanning for games...", FONT, FG_DIM, (S(50), S(180)))
        draw_text(screen, "B/Back = Cancel   A/Start = OK   Left/Right = switch", FONT, FG_DIM, (S(50), S(240)))
        btn_rect = pygame.Rect(S(50), H - S(80), S(140), S(50))
        pygame.draw.rect(screen, ACCENT, btn_rect, border_radius=8)
        draw_text(screen, "Cancel", FONT, FG, (btn_rect.x + S(20), btn_rect.y + S(12)))


class NoGamesScreen(BaseScreen):
    def handle(self, events):
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.MOUSEBUTTONDOWN and e.button == 1 and cancel_r.collidepoint(pygame.mouse.get_pos()):
                clean_exit(0)
            if e.type == pygame.KEYDOWN and e.key in (pygame.K_ESCAPE, pygame.K_RETURN, pygame.K_KP_ENTER):
                clean_exit(0)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_B, BTN_BACK, BTN_START):
                    clean_exit(0)

    def draw(self):
        screen.fill(BG)
        draw_text(screen, "No New Games Found", FONT_BIG, FG, (S(50), S(80)))
        draw_text(screen, f"No .exe files in: {GAMES_DIR}", FONT, FG_DIM, (S(50), S(180)))
        draw_text(screen, "1. Create a folder for each game", FONT, FG_DIM, (S(50), S(240)))
        draw_text(screen, "2. Place .exe and game files inside", FONT, FG_DIM, (S(50), S(280)))
        draw_text(screen, "3. Run this app again", FONT, FG_DIM, (S(50), S(320)))
        btn_rect = pygame.Rect(S(50), H - S(80), S(140), S(50))
        pygame.draw.rect(screen, ACCENT, btn_rect, border_radius=8)
        draw_text(screen, "OK", FONT, FG, (btn_rect.x + S(45), btn_rect.y + S(12)))


class ScanResultsScreen(BaseScreen):
    """Step 2: List of directories, Cancel + OK. Left/Right switches highlight, A/Enter activates."""
    def __init__(self, games):
        self.games = games
        self.focus = 1  # 0=Cancel, 1=OK (default OK so A/Enter proceeds)

    def handle(self, events):
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.MOUSEBUTTONDOWN and e.button == 1:
                pos = pygame.mouse.get_pos()
                if cancel_r.collidepoint(pos):
                    clean_exit(0)
                elif ok_r.collidepoint(pos):
                    push_screen(ExePickerScreen(self.games, 0, []))
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    clean_exit(0)
                if e.key == pygame.K_LEFT:
                    self.focus = 0
                if e.key == pygame.K_RIGHT:
                    self.focus = 1
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        push_screen(ExePickerScreen(self.games, 0, []))
            if e.type == pygame.JOYHATMOTION:
                x, _ = e.value
                if x == -1:
                    self.focus = 0
                if x == 1:
                    self.focus = 1
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_B, BTN_BACK):
                    clean_exit(0)
                if e.button in (BTN_A, BTN_START):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        push_screen(ExePickerScreen(self.games, 0, []))

    def draw(self):
        screen.fill(BG)
        draw_text(screen, "Found directories with .exe files:", FONT_BIG, FG, (S(50), S(60)))
        for i, (name, _) in enumerate(self.games[:12]):
            draw_text(screen, f"  • {name}", FONT, FG_DIM, (S(70), S(120) + i * S(40)))
        draw_text(screen, "Left/Right: switch   A/Enter: select", FONT, FG_DIM, (S(50), H - S(140)))
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        pygame.draw.rect(screen, ACCENT if self.focus == 0 else CARD, cancel_r, border_radius=8)
        pygame.draw.rect(screen, ACCENT if self.focus == 1 else CARD, ok_r, border_radius=8)
        draw_text(screen, "Cancel", FONT, FG, (cancel_r.x + S(25), cancel_r.y + S(12)))
        draw_text(screen, "OK", FONT, FG, (ok_r.x + S(35), ok_r.y + S(12)))


class ExePickerScreen(BaseScreen):
    """Step 3: Per-directory exe choice. Up/Down=exe, Left/Right=buttons, A/Enter=activate."""
    def __init__(self, games, idx, resolved):
        self.games = games
        self.idx = idx
        self.resolved = resolved  # [(name, exe_path, shortcut_id, slug), ...]
        self.sel = 0
        self.focus = 1  # 0=Cancel, 1=OK
        self.game_name, self.exes = games[idx]

    def _do_ok(self):
        exe = self.exes[self.sel]
        slug = "".join(c if c.isalnum() or c in "_-" else "_" for c in self.game_name)[:80]
        sid = generate_shortcut_id(exe)
        new_resolved = self.resolved + [(self.game_name, exe, sid, slug)]
        if self.idx + 1 >= len(self.games):
            push_screen(FinalConfirmScreen(new_resolved))
        else:
            push_screen(ExePickerScreen(self.games, self.idx + 1, new_resolved))

    def handle(self, events):
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.MOUSEBUTTONDOWN and e.button == 1:
                pos = pygame.mouse.get_pos()
                if cancel_r.collidepoint(pos):
                    clean_exit(0)
                elif ok_r.collidepoint(pos):
                    self._do_ok()
                else:
                    # Click on exe list to select
                    for i in range(len(self.exes)):
                        r = pygame.Rect(S(70), S(140) + i * S(45), W - S(140), S(40))
                        if r.collidepoint(pos):
                            self.sel = i
                            break
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    clean_exit(0)
                if e.key in (pygame.K_UP, pygame.K_w):
                    self.sel = (self.sel - 1) % len(self.exes)
                if e.key in (pygame.K_DOWN, pygame.K_s):
                    self.sel = (self.sel + 1) % len(self.exes)
                if e.key == pygame.K_LEFT:
                    self.focus = 0
                if e.key == pygame.K_RIGHT:
                    self.focus = 1
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        self._do_ok()
            if e.type == pygame.JOYHATMOTION:
                x, y = e.value
                if y == 1:
                    self.sel = (self.sel - 1) % len(self.exes)
                if y == -1:
                    self.sel = (self.sel + 1) % len(self.exes)
                if x == -1:
                    self.focus = 0
                if x == 1:
                    self.focus = 1
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_B, BTN_BACK):
                    clean_exit(0)
                if e.button in (BTN_A, BTN_START):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        self._do_ok()

    def draw(self):
        screen.fill(BG)
        draw_text(screen, f"{self.game_name} — choose .exe:", FONT_BIG, FG, (S(50), S(60)))
        for i, exe in enumerate(self.exes):
            base = os.path.basename(exe)
            color = ACCENT if i == self.sel else FG_DIM
            draw_text(screen, f"  {'●' if i == self.sel else '○'} {base}", FONT, color, (S(70), S(140) + i * S(45)))
        draw_text(screen, "Up/Down: exe   Left/Right: buttons   A/Enter: select", FONT, FG_DIM, (S(50), H - S(140)))
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        pygame.draw.rect(screen, ACCENT if self.focus == 0 else CARD, cancel_r, border_radius=8)
        pygame.draw.rect(screen, ACCENT if self.focus == 1 else CARD, ok_r, border_radius=8)
        draw_text(screen, "Cancel", FONT, FG, (cancel_r.x + S(25), cancel_r.y + S(12)))
        draw_text(screen, "OK", FONT, FG, (ok_r.x + S(35), ok_r.y + S(12)))


class FinalConfirmScreen(BaseScreen):
    """Step 4: Final confirmation. Left/Right=buttons, A/Enter=activate."""
    def __init__(self, resolved):
        self.resolved = resolved
        self.focus = 1  # 0=Cancel, 1=OK

    def handle(self, events):
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.MOUSEBUTTONDOWN and e.button == 1:
                pos = pygame.mouse.get_pos()
                if cancel_r.collidepoint(pos):
                    clean_exit(0)
                elif ok_r.collidepoint(pos):
                    self.do_add()
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    clean_exit(0)
                if e.key == pygame.K_LEFT:
                    self.focus = 0
                if e.key == pygame.K_RIGHT:
                    self.focus = 1
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        self.do_add()
            if e.type == pygame.JOYHATMOTION:
                x, _ = e.value
                if x == -1:
                    self.focus = 0
                if x == 1:
                    self.focus = 1
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_B, BTN_BACK):
                    clean_exit(0)
                if e.button in (BTN_A, BTN_START):
                    if self.focus == 0:
                        clean_exit(0)
                    else:
                        self.do_add()

    def do_add(self):
        ensure_gamelist()
        proton = detect_proton()
        for name, exe_path, shortcut_id, slug in self.resolved:
            create_launcher(name, exe_path, shortcut_id, slug, proton)
            add_gamelist_entry(name, shortcut_id, slug)
        reload_es()
        clean_exit(0)

    def draw(self):
        screen.fill(BG)
        draw_text(screen, "Add these games to your ES Steam library?", FONT_BIG, FG, (S(50), S(60)))
        for i, (name, exe_path, _, _) in enumerate(self.resolved[:10]):
            base = os.path.basename(exe_path)
            draw_text(screen, f"  • {name} ({base})", FONT, FG_DIM, (S(70), S(140) + i * S(40)))
        draw_text(screen, "Left/Right: switch   A/Enter: select", FONT, FG_DIM, (S(50), H - S(140)))
        cancel_r = pygame.Rect(S(50), H - S(80), S(140), S(50))
        ok_r = pygame.Rect(S(210), H - S(80), S(100), S(50))
        pygame.draw.rect(screen, ACCENT if self.focus == 0 else CARD, cancel_r, border_radius=8)
        pygame.draw.rect(screen, ACCENT if self.focus == 1 else CARD, ok_r, border_radius=8)
        draw_text(screen, "Cancel", FONT, FG, (cancel_r.x + S(25), cancel_r.y + S(12)))
        draw_text(screen, "OK", FONT, FG, (ok_r.x + S(35), ok_r.y + S(12)))


def main():
    if pygame.joystick.get_count() > 0:
        pygame.joystick.Joystick(0).init()
    push_screen(ScanningScreen())

    while True:
        events = pygame.event.get()
        if SCREENS:
            SCREENS[-1].handle(events)
        if SCREENS:
            SCREENS[-1].draw()
        pygame.display.flip()
        pygame.time.Clock().tick(60)


if __name__ == "__main__":
    main()
