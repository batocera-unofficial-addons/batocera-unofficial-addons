#!/usr/bin/env python3
"""The Native X11 Desktop's panel: the bar along the bottom of the screen with
the app menu, pinned apps, open windows, volume, network, clock and a button
back to EmulationStation.

Runs inside the Native X11 Desktop's own Openbox session (started by
native-x11-desktop-session.sh), with GTK 3 on X11. Open windows come from
`wmctrl`.

  native-x11-desktop-panel.py              run the panel
  native-x11-desktop-panel.py --wallpaper  choose a wallpaper (desktop menu)
  native-x11-desktop-panel.py --theme      open the theme picker and exit

Right-click an app in the app menu to pin it to the taskbar or add it to the
desktop.
"""
import importlib.util
import os
import re
import shlex
import shutil
import signal
import struct
import subprocess
import sys
import time

import warnings

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
# Gio.DesktopAppInfo works on Batocera's GLib; its newer name is not on older ones
warnings.filterwarnings("ignore", category=DeprecationWarning)
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402

INSTALL = "/userdata/system/add-ons/native-x11-desktop"
CONF = "/userdata/system/configs/native-x11-desktop"
PINNED_FILE = os.path.join(CONF, "pinned")
DESKTOP = "/userdata/system/Desktop"  # the icons on the wallpaper (native-x11-desktop-desktop.py)
DEFAULT_PINS = ["pcmanfm.desktop", "Firefox.desktop", "xterm.desktop"]
# Entries that do nothing useful here
HIDDEN = {
    "pcmanfm-desktop-pref.desktop", "xinput_calibrator.desktop",
    "yad-settings.desktop", "yad-icon-browser.desktop",
    "org.freedesktop.Xwayland.desktop",
}
TERMINAL = ["xterm", "-fs", "14", "-fg", "white", "-bg", "black", "-fa", "Monospace", "-en", "UTF-8", "-sb", "-rightbar"]
CATEGORIES = ["All", "Games", "Emulator settings", "Add-ons", "System"]

PANEL_HEIGHT = 56
PANEL_MARGIN = 10

# ---- theme engine (loaded via importlib because the filename has hyphens) ----
_spec = importlib.util.spec_from_file_location(
    "theme", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "native-x11-desktop-theme.py"))
_theme_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_theme_mod)


def _hex_to_rgb(h):
    """'#aabbcc' -> (170, 187, 204)"""
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def _rgba(hexcol, alpha):
    r, g, b = _hex_to_rgb(hexcol)
    return f"rgba({r}, {g}, {b}, {alpha})"


def _build_css(palette):
    """Build the full panel CSS from a palette dict.

    The theme module generates the core widget CSS; this wraps it with the
    panel-specific class overrides that the old hardcoded blob provided.
    """
    acc = palette.get("P_ACC", "#4f9bff")
    acc_h = palette.get("P_ACC_H", "#64a8ff")
    fg = palette.get("P_FG", "#e8edf5")
    fg_dim = palette.get("P_FG_DIM", "#9aa6b8")
    base = palette.get("P_BASE", "#0b0f17")
    base1 = palette.get("P_BASE1", "#141b28")

    return f"""
window.ld-panel {{ background: transparent; }}
window.ld-popup {{ background: transparent; }}
label {{ color: {fg}; }}
.ld-bar {{
  background: {_rgba(base1, 0.88)}; border: 1px solid rgba(255, 255, 255, 0.10);
  border-radius: 14px; padding: 4px 6px;
}}
.ld-bar button, .ld-card button {{
  background: transparent; background-image: none; border: none; box-shadow: none;
  text-shadow: none; -gtk-icon-shadow: none; color: {fg};
  border-radius: 10px; padding: 4px 10px; min-height: 30px; outline-color: {acc};
}}
.ld-bar button:hover, .ld-card button:hover, .ld-card button:focus {{ background: rgba(255, 255, 255, 0.09); }}
.ld-bar button.ld-start {{ background: {acc}; font-weight: 600; }}
.ld-bar button.ld-start:hover {{ background: {acc_h}; }}
.ld-bar button.ld-start label, .ld-bar button.ld-start image {{ color: #ffffff; }}
button.ld-apply {{ background: {acc}; font-weight: 600; }}
button.ld-apply label {{ color: #ffffff; }}
button.ld-es {{ background: rgba(255, 181, 71, 0.15); }}
button.ld-es:hover {{ background: rgba(255, 181, 71, 0.26); }}
button.ld-es label {{ color: #ffb547; font-weight: 600; }}
.ld-bar button.ld-task.ld-active {{ background: {_rgba(acc, 0.24)}; }}
.ld-sep {{ background: rgba(255, 255, 255, 0.12); min-width: 1px; margin: 8px 4px; }}
.ld-dim {{ color: {fg_dim}; font-size: 9pt; }}
.ld-card {{
  background: {_rgba(base1, 0.96)}; border: 1px solid rgba(255, 255, 255, 0.10);
  border-radius: 16px; padding: 14px;
}}
.ld-card entry {{
  background: rgba(255, 255, 255, 0.06); background-image: none; color: {fg};
  border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 10px; padding: 6px 10px;
  box-shadow: none; caret-color: {fg};
}}
.ld-card entry image {{ color: {fg_dim}; }}
.ld-card button.ld-cat {{
  border: 1px solid rgba(255, 255, 255, 0.12); border-radius: 999px; padding: 2px 12px; min-height: 24px;
}}
.ld-card button.ld-cat label {{ color: {fg_dim}; }}
.ld-card button.ld-cat.ld-on {{ background: {fg}; }}
.ld-card button.ld-cat.ld-on label {{ color: {base}; }}
.ld-card flowboxchild {{ padding: 0; background: transparent; }}
.ld-card button.ld-app {{ padding: 8px 4px; }}
.ld-card button.ld-app label {{ font-size: 9.5pt; }}
.ld-foot {{ border-top: 1px solid rgba(255, 255, 255, 0.10); padding-top: 10px; }}
.ld-card button.ld-warn label {{ color: #ff6b6b; font-weight: 600; }}
.ld-card scrolledwindow, .ld-card viewport {{ background: transparent; border: none; }}
scale trough {{ background: rgba(255, 255, 255, 0.15); min-height: 6px; border-radius: 3px; border: none; }}
scale highlight {{ background: {acc}; border-radius: 3px; border: none; }}
scale slider {{ background: {fg}; border: none; min-width: 16px; min-height: 16px; border-radius: 8px; }}
.ld-title {{ font-weight: 600; }}
"""


_palette = _theme_mod.load_palette()
CSS = _build_css(_palette).encode()


def run(args, timeout=2):
    """Runs a command, returning (exit status, output); never raises."""
    try:
        p = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return p.returncode, p.stdout
    except (OSError, subprocess.SubprocessError):
        return 1, ""


def spawn(argv):
    """Starts a program on its own (not a child of the panel), in /userdata."""
    try:
        subprocess.Popen(["/bin/sh", "-c", 'cd /userdata && "$@" >/dev/null 2>&1 &', "sh"] + argv).wait()
    except OSError as e:
        print(f"panel: could not start {argv}: {e}", file=sys.stderr)


def exit_desktop():
    """Back to EmulationStation: runs the exit script."""
    spawn([INSTALL + "/native-x11-desktop-exit.sh"])


def get_screen_size():
    """Get the screen width and height."""
    screen = Gdk.Screen.get_default()
    return screen.get_width(), screen.get_height()


def icon_image(icon, size):
    """An icon at exactly `size` pixels, from an icon name or an app's icon.
    Icons that are missing or fail to load fall back to a generic one."""
    if isinstance(icon, str) and icon.endswith("-symbolic"):
        # Drawn in the text color, so they show on the dark panel
        img = Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.BUTTON)
        img.set_pixel_size(size)
        return img
    theme = Gtk.IconTheme.get_default()
    if isinstance(icon, str):
        icon = Gio.ThemedIcon.new(icon)
    pixbuf = None
    for gicon in (icon, Gio.ThemedIcon.new("application-x-executable")):
        if gicon is None:
            continue
        info = theme.lookup_by_gicon(gicon, size, Gtk.IconLookupFlags.FORCE_SIZE)
        if info:
            try:
                pixbuf = info.load_icon()
            except GLib.Error:
                pixbuf = None
        if pixbuf:
            break
    return Gtk.Image.new_from_pixbuf(pixbuf) if pixbuf else Gtk.Image()


# ---------------------------------------------------------------- apps

class App:
    """One entry of the app menu, from a .desktop file."""

    def __init__(self, info, path):
        self.info = info
        self.id = os.path.basename(path)
        self.path = path
        self.name = self.pretty_name(info.get_display_name() or self.id)
        self.gicon = info.get_icon()
        cats = (info.get_categories() or "").split(";")
        cmd = info.get_commandline() or ""
        if path.startswith("/userdata") or "/userdata/" in cmd:
            self.category = "Add-ons"
        elif self.id.endswith("-config.desktop") and "batocera.linux" in cats:
            self.category = "Emulator settings"
        elif "Game" in cats:
            self.category = "Games"
        else:
            self.category = "System"
        wm = (info.get_string("StartupWMClass") or "").lower()
        try:
            exe = os.path.basename(shlex.split(cmd)[0]).lower() if cmd.strip() else ""
        except ValueError:
            exe = ""
        # Names a window's WM_CLASS may have, best match first
        self.keys = [k for k in (self.id[:-8].lower(), wm, exe) if k]

    @staticmethod
    def pretty_name(name):
        # Batocera's settings entries are named like "duckstation-emu-config"
        m = re.fullmatch(r"([a-z0-9-]+?)(-emu)?-config", name)
        if m:
            return " ".join(w.capitalize() for w in m.group(1).split("-")) + " settings"
        return {"File Manager PCManFM": "File Manager"}.get(name, name)

    def launch(self):
        cmd = self.info.get_commandline() or ""
        # Drop the file/URL placeholders: started from the menu, there are none
        cmd = re.sub(r"\s%[fFuUdDnNickvm]", "", cmd).replace("%%", "%")
        try:
            argv = shlex.split(cmd)
        except ValueError:
            return
        if not argv:
            return
        if self.info.get_boolean("Terminal"):
            argv = TERMINAL + ["-e"] + argv
        spawn(argv)


def load_apps():
    apps = {}
    for info in Gio.AppInfo.get_all():
        if not isinstance(info, Gio.DesktopAppInfo) or not info.should_show():
            continue
        path = info.get_filename() or ""
        app = App(info, path)
        if app.id not in HIDDEN:
            apps[app.id] = app
    # Add-ons keep a copy of their entry in /userdata (BUA puts it back in
    # /usr/share/applications at boot); show those even before that
    configs = "/userdata/system/configs"
    for d in sorted(os.listdir(configs)) if os.path.isdir(configs) else []:
        folder = os.path.join(configs, d)
        if d == "native-x11-desktop" or not os.path.isdir(folder):
            continue
        for f in os.listdir(folder):
            if f.endswith(".desktop") and f not in apps:
                info = Gio.DesktopAppInfo.new_from_filename(os.path.join(folder, f))
                if info and info.should_show():
                    apps[f] = App(info, os.path.join(folder, f))
    return apps


def add_to_desktop(app):
    """An icon on the desktop: a link to the app's entry, in the Desktop
    folder that native-x11-desktop-desktop.py shows."""
    os.makedirs(DESKTOP, exist_ok=True)
    link = os.path.join(DESKTOP, app.id)
    if not os.path.lexists(link):
        os.symlink(app.path, link)


def read_pins():
    try:
        with open(PINNED_FILE) as f:
            return [line.strip() for line in f if line.strip()]
    except OSError:
        return list(DEFAULT_PINS)


def write_pins(pins):
    os.makedirs(CONF, exist_ok=True)
    with open(PINNED_FILE, "w") as f:
        f.write("\n".join(pins) + "\n")


# ---------------------------------------------------------------- window management (X11 / wmctrl)

def get_windows():
    """Get list of open windows using wmctrl."""
    try:
        out = subprocess.check_output(["wmctrl", "-lx"], text=True, stderr=subprocess.DEVNULL)
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []
    windows = []
    for line in out.strip().splitlines():
        parts = line.split(None, 4)
        if len(parts) < 5:
            continue
        wid = parts[0]       # 0x01234567
        # parts[1] is desktop number
        wm_class = parts[2]  # instance.Class
        # parts[3] is hostname
        title = parts[4]
        # Skip our own windows
        if "native-x11-desktop" in title.lower() or "native-x11-desktop" in wm_class.lower():
            continue
        windows.append({"id": wid, "class": wm_class, "title": title})
    return windows


def get_active_window():
    """Get the window id of the currently focused window."""
    try:
        out = subprocess.check_output(["xprop", "-root", "_NET_ACTIVE_WINDOW"],
                                      text=True, stderr=subprocess.DEVNULL)
        # Output like: _NET_ACTIVE_WINDOW(WINDOW): window id # 0x1234567
        for part in out.split():
            if part.startswith("0x"):
                return part
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return None


def focus_window(wid):
    """Focus/activate a window by id."""
    subprocess.run(["wmctrl", "-i", "-a", wid], stderr=subprocess.DEVNULL)


def minimize_window(wid):
    """Minimize a window by id."""
    subprocess.run(["wmctrl", "-i", "-r", wid, "-b", "add,hidden"], stderr=subprocess.DEVNULL)


def maximize_window(wid):
    """Toggle maximize on a window by id."""
    subprocess.run(["wmctrl", "-i", "-r", wid, "-b", "toggle,maximized_vert,maximized_horz"],
                    stderr=subprocess.DEVNULL)


def close_window(wid):
    """Close a window by id."""
    subprocess.run(["wmctrl", "-i", "-c", wid], stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------- audio (PulseAudio / pactl)

def get_volume():
    """Get current volume percentage and mute status."""
    vol, muted = 50, False
    try:
        out = subprocess.check_output(["pactl", "get-sink-volume", "@DEFAULT_SINK@"],
                                      text=True, stderr=subprocess.DEVNULL)
        m = re.search(r'(\d+)%', out)
        if m:
            vol = int(m.group(1))
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    try:
        out = subprocess.check_output(["pactl", "get-sink-mute", "@DEFAULT_SINK@"],
                                      text=True, stderr=subprocess.DEVNULL)
        muted = "yes" in out.lower()
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return vol, muted


def set_volume(pct):
    """Set volume to a percentage."""
    subprocess.run(["pactl", "set-sink-volume", "@DEFAULT_SINK@", f"{int(pct)}%"],
                    stderr=subprocess.DEVNULL)


def toggle_mute():
    """Toggle mute on the default sink."""
    subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle"],
                    stderr=subprocess.DEVNULL)


# ---------------------------------------------------------------- popups

class Popup(Gtk.Window):
    """A popup window positioned near the panel.
    Clicking outside the card, or Escape, closes it."""

    def __init__(self, panel, card_width, align_right=False):
        super().__init__(type=Gtk.WindowType.TOPLEVEL)
        self.panel = panel
        self.align_right = align_right
        self.set_type_hint(Gdk.WindowTypeHint.POPUP_MENU)
        self.set_decorated(False)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.get_style_context().add_class("ld-popup")
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self.card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        self.card.get_style_context().add_class("ld-card")
        self.card.set_size_request(card_width, -1)
        self.add(self.card)

        self.connect("focus-out-event", self.on_focus_out)
        self.connect("key-press-event", self.on_key)

    def on_focus_out(self, _w, _event):
        self.hide()
        return False

    def on_key(self, _w, event):
        if event.keyval == Gdk.KEY_Escape:
            self.hide()
            return True
        return False

    def position_popup(self):
        """Position the popup above the panel."""
        sw, sh = get_screen_size()
        self.show_all()
        alloc = self.get_allocation()
        popup_w = alloc.width
        popup_h = alloc.height
        # Place above the panel
        y = sh - PANEL_HEIGHT - PANEL_MARGIN - popup_h - 8
        if y < 0:
            y = 0
        if self.align_right:
            x = sw - PANEL_MARGIN - popup_w
        else:
            x = PANEL_MARGIN
        self.move(x, y)

    def toggle(self):
        if self.get_visible():
            self.hide()
        else:
            self.panel.close_popups()
            self.refresh()
            self.position_popup()
            self.show_all()
            self.present()

    def refresh(self):
        pass


class AppMenu(Popup):
    def __init__(self, panel):
        super().__init__(panel, card_width=640, align_right=False)
        self.category = "All"
        self.apps = {}
        self.confirm = None

        self.search = Gtk.SearchEntry(placeholder_text="Type to search apps")
        self.search.connect("search-changed", lambda *_: self.fill())
        self.search.connect("activate", self.launch_first)
        self.card.pack_start(self.search, False, False, 0)

        self.cats = Gtk.Box(spacing=6)
        self.card.pack_start(self.cats, False, False, 0)

        self.grid = Gtk.FlowBox(homogeneous=True, min_children_per_line=5, max_children_per_line=5,
                                selection_mode=Gtk.SelectionMode.NONE, row_spacing=2, column_spacing=2)
        scroll = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        scroll.set_size_request(600, 400)
        scroll.add(self.grid)
        self.card.pack_start(scroll, True, True, 0)

        foot = Gtk.Box(spacing=6, homogeneous=True)
        foot.get_style_context().add_class("ld-foot")
        es = Gtk.Button(label="EmulationStation")
        es.get_style_context().add_class("ld-es")
        es.connect("clicked", lambda *_: exit_desktop())
        foot.pack_start(es, True, True, 0)
        theme_btn = Gtk.Button(label="Theme")
        theme_btn.connect("clicked", self.on_theme_button)
        foot.pack_start(theme_btn, True, True, 0)
        self.power = {}
        for key, label, cmd in (("reboot", "Restart", ["batocera-es-swissknife", "--reboot"]),
                                ("shutdown", "Shut down", ["batocera-es-swissknife", "--shutdown"])):
            b = Gtk.Button(label=label)
            b.connect("clicked", self.on_power, key, label, cmd)
            self.power[key] = b
            foot.pack_start(b, True, True, 0)
        self.card.pack_start(foot, False, False, 0)

    def refresh(self):
        self.apps = load_apps()
        self.search.set_text("")
        self.reset_power()
        self.fill()
        self.search.grab_focus()

    def reset_power(self):
        self.confirm = None
        for key, label in (("reboot", "Restart"), ("shutdown", "Shut down")):
            self.power[key].set_label(label)
            self.power[key].get_style_context().remove_class("ld-warn")

    def on_power(self, button, key, label, cmd):
        # Asks once more before restarting or shutting down
        if self.confirm != key:
            self.reset_power()
            self.confirm = key
            button.set_label(f"Click again: {label.lower()}")
            button.get_style_context().add_class("ld-warn")
            GLib.timeout_add_seconds(4, lambda: (self.reset_power() if self.confirm == key else None) and False)
            return
        spawn(cmd)

    def set_category(self, _b, cat):
        self.category = cat
        self.fill()

    def visible_apps(self):
        text = self.search.get_text().strip().lower()
        apps = sorted(self.apps.values(), key=lambda a: a.name.lower())
        if text:
            return [a for a in apps if text in a.name.lower() or any(text in k for k in a.keys)]
        if self.category == "All":
            return apps
        return [a for a in apps if a.category == self.category]

    def fill(self):
        for child in self.cats.get_children():
            self.cats.remove(child)
        present = {a.category for a in self.apps.values()}
        for cat in CATEGORIES:
            if cat != "All" and cat not in present:
                continue
            b = Gtk.Button(label=cat)
            b.get_style_context().add_class("ld-cat")
            if cat == self.category and not self.search.get_text():
                b.get_style_context().add_class("ld-on")
            b.connect("clicked", self.set_category, cat)
            self.cats.pack_start(b, False, False, 0)
        for child in self.grid.get_children():
            self.grid.remove(child)
        for app in self.visible_apps():
            self.grid.add(self.app_button(app))
        self.cats.show_all()
        self.grid.show_all()

    def app_button(self, app):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        box.pack_start(icon_image(app.gicon, 44), False, False, 0)
        label = Gtk.Label(label=app.name, max_width_chars=12, justify=Gtk.Justification.CENTER)
        label.set_line_wrap(True)
        label.set_lines(2)
        label.set_ellipsize(3)  # Pango END
        box.pack_start(label, False, False, 0)
        b = Gtk.Button()
        b.add(box)
        b.set_tooltip_text(app.name)
        b.get_style_context().add_class("ld-app")
        b.connect("clicked", self.on_app, app)
        b.connect("button-press-event", self.on_app_menu, app)
        return b

    def on_app(self, _b, app):
        self.hide()
        app.launch()

    def launch_first(self, _entry):
        apps = self.visible_apps()
        if apps:
            self.on_app(None, apps[0])

    def on_theme_button(self, *_):
        # The theme picker is its own window, like the original desktop's
        # "Desktop Palette"; it tells the panel to reload when applied
        self.hide()
        spawn([sys.executable, os.path.abspath(__file__), "--theme"])

    def on_app_menu(self, button, event, app):
        if event.button != 3:
            return False
        pins = read_pins()
        menu = Gtk.Menu()
        item = Gtk.MenuItem(label="Unpin from the taskbar" if app.id in pins else "Pin to the taskbar")
        item.connect("activate", lambda *_: self.panel.toggle_pin(app.id))
        menu.append(item)
        link = os.path.join(DESKTOP, app.id)
        if os.path.lexists(link):
            item = Gtk.MenuItem(label="Remove from the desktop")
            item.connect("activate", lambda *_: os.remove(link))
        else:
            item = Gtk.MenuItem(label="Add to the desktop")
            item.connect("activate", lambda *_: add_to_desktop(app))
        menu.append(item)
        menu.show_all()
        menu.attach_to_widget(button, None)
        menu.popup_at_pointer(event)
        return True


class VolumePopup(Popup):
    def __init__(self, panel):
        super().__init__(panel, card_width=280, align_right=True)
        head = Gtk.Box(spacing=8)
        self.title = Gtk.Label(label="Volume", xalign=0)
        self.title.get_style_context().add_class("ld-title")
        head.pack_start(self.title, True, True, 0)
        self.mute = Gtk.Button(label="Mute")
        self.mute.connect("clicked", self.on_mute)
        head.pack_end(self.mute, False, False, 0)
        self.card.pack_start(head, False, False, 0)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 5)
        self.scale.set_draw_value(False)
        self.scale.connect("value-changed", self.on_scale)
        self.card.pack_start(self.scale, False, False, 0)
        self.updating = False

    def refresh(self):
        vol, muted = get_volume()
        self.updating = True
        self.scale.set_value(vol)
        self.updating = False
        self.show_state(vol, muted)

    def show_state(self, vol, muted):
        self.title.set_text(f"Volume {vol}%" + (" (muted)" if muted else ""))
        self.mute.set_label("Unmute" if muted else "Mute")

    def on_scale(self, scale):
        if self.updating:
            return
        vol = int(scale.get_value())
        set_volume(vol)
        # Unmute when adjusting volume
        subprocess.run(["pactl", "set-sink-mute", "@DEFAULT_SINK@", "0"], stderr=subprocess.DEVNULL)
        self.show_state(vol, False)
        self.panel.update_volume_icon()

    def on_mute(self, _b):
        toggle_mute()
        self.refresh()
        self.panel.update_volume_icon()


# ---------------------------------------------------------------- panel

class Panel(Gtk.Window):
    def __init__(self):
        super().__init__(title="Native X11 Desktop panel")
        self.set_type_hint(Gdk.WindowTypeHint.DOCK)
        self.set_decorated(False)
        self.stick()  # visible on all workspaces
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_skip_pager_hint(True)
        self.get_style_context().add_class("ld-panel")
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        # Position and size the panel at the bottom of the screen
        sw, sh = get_screen_size()
        self.move(PANEL_MARGIN, sh - PANEL_HEIGHT - PANEL_MARGIN)
        self.resize(sw - 2 * PANEL_MARGIN, PANEL_HEIGHT)
        self.connect("realize", self.on_realize)

        bar = Gtk.Box(spacing=4)
        bar.get_style_context().add_class("ld-bar")
        self.add(bar)

        start = Gtk.Button()
        sbox = Gtk.Box(spacing=8)
        sbox.pack_start(icon_image("view-app-grid-symbolic", 18), False, False, 0)
        sbox.pack_start(Gtk.Label(label="Apps"), False, False, 0)
        start.add(sbox)
        start.get_style_context().add_class("ld-start")
        start.connect("clicked", lambda *_: self.menu.toggle())
        bar.pack_start(start, False, False, 0)
        bar.pack_start(self.separator(), False, False, 0)

        self.pins_box = Gtk.Box(spacing=2)
        bar.pack_start(self.pins_box, False, False, 0)
        bar.pack_start(self.separator(), False, False, 0)

        self.tasks_box = Gtk.Box(spacing=4)
        bar.pack_start(self.tasks_box, True, True, 0)

        self.vol_button = Gtk.Button()
        self.vol_button.set_tooltip_text("Volume")
        self.vol_button.connect("clicked", lambda *_: self.volume.toggle())
        bar.pack_start(self.vol_button, False, False, 0)

        self.net_button = Gtk.Button()
        bar.pack_start(self.net_button, False, False, 0)

        clock = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        clock.set_valign(Gtk.Align.CENTER)
        clock.set_margin_start(6)
        clock.set_margin_end(8)
        self.time_label = Gtk.Label(xalign=1)
        self.date_label = Gtk.Label(xalign=1)
        self.date_label.get_style_context().add_class("ld-dim")
        clock.pack_start(self.time_label, False, False, 0)
        clock.pack_start(self.date_label, False, False, 0)
        bar.pack_start(clock, False, False, 0)

        es = Gtk.Button(label="EmulationStation")
        es.set_tooltip_text("Close the desktop and go back to EmulationStation")
        es.get_style_context().add_class("ld-es")
        es.connect("clicked", lambda *_: exit_desktop())
        bar.pack_start(es, False, False, 0)

        self.menu = AppMenu(self)
        self.volume = VolumePopup(self)
        self.windows = []
        self.task_buttons = {}
        self.apps = load_apps()
        # 12-hour clock where that is the custom (Batocera's language, set in ES)
        _, lang = run(["batocera-settings-get", "system.language"])
        self.twelve_hour = (lang.strip() or "en_US") in ("en_US", "en_CA", "en_AU", "en_PH", "en_IN")

        self.fill_pins()
        self.update_volume_icon()
        self.update_network()
        self.tick()
        self.update_windows()
        GLib.timeout_add_seconds(1, self.tick)
        GLib.timeout_add(1000, self.update_windows)
        GLib.timeout_add_seconds(5, lambda: self.update_volume_icon() or True)
        GLib.timeout_add_seconds(20, lambda: self.update_network() or True)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, self.on_menu_key)
        # Sent by the standalone theme picker (desktop right-click menu)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR2, self.on_theme_signal)
        self.connect("destroy", Gtk.main_quit)

    def on_realize(self, _widget):
        """Set _NET_WM_STRUT_PARTIAL to reserve space at the bottom of the screen."""
        self.set_strut()

    def set_strut(self):
        """Reserve space at the bottom so other windows don't overlap the panel."""
        gdk_win = self.get_window()
        if not gdk_win:
            return
        atom_strut = Gdk.Atom.intern("_NET_WM_STRUT_PARTIAL", False)
        atom_cardinal = Gdk.Atom.intern("CARDINAL", False)
        sw, sh = get_screen_size()
        alloc = self.get_allocation()
        bottom = sh - alloc.y
        # _NET_WM_STRUT_PARTIAL: left, right, top, bottom,
        #   left_start_y, left_end_y, right_start_y, right_end_y,
        #   top_start_x, top_end_x, bottom_start_x, bottom_end_x
        data = struct.pack("12I", 0, 0, 0, bottom, 0, 0, 0, 0, 0, 0, 0, sw)
        gdk_win.property_change(atom_strut, atom_cardinal, 32,
                                Gdk.PropMode.REPLACE, data)

    @staticmethod
    def separator():
        s = Gtk.Box()
        s.get_style_context().add_class("ld-sep")
        return s

    def close_popups(self):
        self.menu.hide()
        self.volume.hide()

    def reload_theme(self):
        """Reload CSS from the current palette and re-apply it."""
        screen = Gdk.Screen.get_default()
        # Remove old provider
        if hasattr(self, '_css_provider'):
            Gtk.StyleContext.remove_provider_for_screen(screen, self._css_provider)
        self._css_provider = Gtk.CssProvider()
        self._css_provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(screen, self._css_provider,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

    def on_theme_signal(self):
        """The theme was changed outside the panel: load it and re-apply."""
        global _palette, CSS
        _palette = _theme_mod.load_palette()
        CSS = _build_css(_palette).encode()
        self.reload_theme()
        return True

    def on_menu_key(self):
        # Super key, or X on a controller (sent by Openbox's keybind)
        self.menu.toggle()
        return True

    # Pinned apps
    def fill_pins(self):
        for child in self.pins_box.get_children():
            self.pins_box.remove(child)
        self.apps = load_apps()
        for app_id in read_pins():
            app = self.apps.get(app_id)
            if not app:
                continue
            b = Gtk.Button()
            b.add(icon_image(app.gicon, 24))
            b.set_tooltip_text(app.name)
            b.connect("clicked", lambda _b, a=app: (self.close_popups(), a.launch()))
            b.connect("button-press-event", self.on_pin_menu, app)
            self.pins_box.pack_start(b, False, False, 0)
        self.pins_box.show_all()

    def on_pin_menu(self, button, event, app):
        if event.button != 3:
            return False
        menu = Gtk.Menu()
        item = Gtk.MenuItem(label="Unpin from the taskbar")
        item.connect("activate", lambda *_: self.toggle_pin(app.id))
        menu.append(item)
        menu.show_all()
        menu.attach_to_widget(button, None)
        menu.popup_at_pointer(event)
        return True

    def toggle_pin(self, app_id):
        pins = read_pins()
        if app_id in pins:
            pins.remove(app_id)
        else:
            pins.append(app_id)
        write_pins(pins)
        self.fill_pins()

    # Open windows
    def icon_for(self, wm_class):
        # The app whose file name matches wins, then its window class, then
        # the program it runs (several entries may run xterm, say)
        # wm_class from wmctrl is "instance.Class", try both parts
        parts = wm_class.split(".")
        keys_to_try = [p.lower() for p in parts if p]
        for key in keys_to_try:
            for rank in range(3):
                for app in self.apps.values():
                    if len(app.keys) > rank and app.keys[rank] == key:
                        return app.gicon
        return (keys_to_try[0] if keys_to_try else "") or "application-x-executable"

    def update_windows(self):
        raw_windows = get_windows()
        # Build a comparable list of tuples
        window_tuples = [(w["id"], w["class"], w["title"]) for w in raw_windows]
        old_tuples = [(w["id"], w["class"], w["title"]) for w in self.windows] if self.windows else []

        if window_tuples != old_tuples:
            self.windows = raw_windows
            for child in self.tasks_box.get_children():
                self.tasks_box.remove(child)
            self.task_buttons = {}
            for w in raw_windows:
                b = Gtk.Button()
                box = Gtk.Box(spacing=8)
                box.pack_start(icon_image(self.icon_for(w["class"]), 20), False, False, 0)
                label = Gtk.Label(label=w["title"] or w["class"], max_width_chars=22, xalign=0)
                label.set_ellipsize(3)
                box.pack_start(label, False, False, 0)
                b.add(box)
                b.set_tooltip_text(w["title"] or w["class"])
                b.get_style_context().add_class("ld-task")
                b.connect("clicked", self.on_task, w["id"])
                b.connect("button-press-event", self.on_task_menu, w["id"])
                self.tasks_box.pack_start(b, False, False, 0)
                self.task_buttons[w["id"]] = b
            self.tasks_box.show_all()

        # Highlight the focused window
        active = get_active_window()
        for wid, b in self.task_buttons.items():
            # Compare window ids (normalize hex format)
            is_active = False
            if active:
                try:
                    is_active = int(wid, 16) == int(active, 16)
                except ValueError:
                    is_active = wid == active
            ctx = b.get_style_context()
            (ctx.add_class if is_active else ctx.remove_class)("ld-active")
        return True

    def on_task(self, _b, wid):
        self.close_popups()
        active = get_active_window()
        is_active = False
        if active:
            try:
                is_active = int(wid, 16) == int(active, 16)
            except ValueError:
                is_active = wid == active
        if is_active:
            minimize_window(wid)
        else:
            focus_window(wid)
        GLib.timeout_add(150, lambda: self.update_windows() and False)

    def on_task_menu(self, button, event, wid):
        if event.button != 3:
            return False
        menu = Gtk.Menu()
        for label, action in (("Minimize", lambda: minimize_window(wid)),
                              ("Maximize", lambda: maximize_window(wid)),
                              ("Close", lambda: close_window(wid))):
            item = Gtk.MenuItem(label=label)
            item.connect("activate", lambda _i, a=action: a())
            menu.append(item)
        menu.show_all()
        menu.attach_to_widget(button, None)
        menu.popup_at_pointer(event)
        return True

    # Volume, network, clock
    def update_volume_icon(self):
        vol, muted = get_volume()
        if muted or vol == 0:
            name = "audio-volume-muted-symbolic"
        elif vol < 34:
            name = "audio-volume-low-symbolic"
        elif vol < 67:
            name = "audio-volume-medium-symbolic"
        else:
            name = "audio-volume-high-symbolic"
        child = self.vol_button.get_child()
        if child:
            self.vol_button.remove(child)
        self.vol_button.add(icon_image(name, 18))
        self.vol_button.set_tooltip_text(f"Volume {vol}%" + (" (muted)" if muted else ""))
        self.vol_button.show_all()

    def update_network(self):
        _, out = run(["ip", "-4", "route", "get", "1.1.1.1"])
        dev = re.search(r"\bdev (\S+)", out)
        src = re.search(r"\bsrc (\S+)", out)
        if dev and src:
            wireless = os.path.isdir(f"/sys/class/net/{dev.group(1)}/wireless")
            name = "network-wireless-symbolic" if wireless else "network-wired-symbolic"
            tip = f"{'Wi-Fi' if wireless else 'Wired'}: connected ({src.group(1)})"
        else:
            name, tip = "network-offline-symbolic", "Not connected"
        child = self.net_button.get_child()
        if child:
            self.net_button.remove(child)
        self.net_button.add(icon_image(name, 18))
        self.net_button.set_tooltip_text(tip)
        self.net_button.show_all()

    def tick(self):
        now = time.localtime()
        if self.twelve_hour:
            self.time_label.set_text(time.strftime("%I:%M %p", now).lstrip("0"))
        else:
            self.time_label.set_text(time.strftime("%H:%M", now))
        self.date_label.set_text(time.strftime("%a %b %d", now).replace(" 0", " "))
        return True


# ---------------------------------------------------------------- wallpaper

def choose_wallpaper():
    dialog = Gtk.FileChooserDialog(title="Choose a wallpaper", action=Gtk.FileChooserAction.OPEN)
    dialog.add_buttons("Use the default", 1, "Cancel", Gtk.ResponseType.CANCEL, "Use this picture", Gtk.ResponseType.OK)
    dialog.set_default_size(900, 600)
    pictures = Gtk.FileFilter()
    pictures.set_name("Pictures")
    for mime in ("image/png", "image/jpeg", "image/webp", "image/bmp", "image/gif"):
        pictures.add_mime_type(mime)
    dialog.add_filter(pictures)
    start = "/userdata/screenshots" if os.path.isdir("/userdata/screenshots") else "/userdata"
    dialog.set_current_folder(start)
    response = dialog.run()
    chosen = dialog.get_filename()
    dialog.destroy()
    if response not in (Gtk.ResponseType.OK, 1):
        return
    os.makedirs(CONF, exist_ok=True)
    for f in os.listdir(CONF):
        if f.startswith("wallpaper."):
            os.remove(os.path.join(CONF, f))
    if response == Gtk.ResponseType.OK and chosen:
        ext = os.path.splitext(chosen)[1].lower() or ".png"
        shutil.copyfile(chosen, os.path.join(CONF, "wallpaper" + ext))
    # native-x11-desktop-desktop.py watches CONF and shows the new wallpaper


def notify_panel():
    """Tell the running panel to reload its theme (SIGUSR2).

    Only the panel itself is signalled: a python3 process whose last argument
    is this script, with no options. The picker and wallpaper windows run the
    same script with --theme/--wallpaper and have no SIGUSR2 handler, so a
    signal would kill them.
    """
    script = os.path.basename(os.path.abspath(__file__))
    me = os.getpid()
    for pid in os.listdir("/proc"):
        if not pid.isdigit() or int(pid) == me:
            continue
        try:
            with open(f"/proc/{pid}/cmdline", "rb") as f:
                args = f.read().split(b"\0")
        except OSError:
            continue
        args = [a.decode(errors="replace") for a in args if a]
        if len(args) >= 2 and os.path.basename(args[-1]) == script \
                and not any(a.startswith("--") for a in args[1:]):
            try:
                os.kill(int(pid), signal.SIGUSR2)
            except OSError:
                pass


def theme_picker_window():
    """The theme window: app menu > Theme, or desktop right-click > Change theme.

    Like the original desktop's "Desktop Palette" window: one list of colour
    palettes (the current one first, each with its colour), and Apply /
    Cancel. Apply saves the palette, draws its wallpaper (the desktop picks it
    up from CONF) and tells the running panel to reload its colours.
    """
    win = Gtk.Window(title="Desktop Theme")
    win.set_default_size(380, -1)
    win.set_resizable(False)
    win.set_position(Gtk.WindowPosition.CENTER)
    visual = win.get_screen().get_rgba_visual()
    if visual:
        win.set_visual(visual)
    win.connect("destroy", Gtk.main_quit)
    win.connect("key-press-event",
                lambda _w, e: e.keyval == Gdk.KEY_Escape and (win.destroy() or True))

    card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    card.get_style_context().add_class("ld-card")
    for side in ("top", "bottom", "start", "end"):
        getattr(card, f"set_margin_{side}")(18)

    title = Gtk.Label(label="Desktop Theme", xalign=0)
    title.get_style_context().add_class("ld-title")
    card.pack_start(title, False, False, 0)

    # Palettes: name, label, accent colour. The current one first.
    store = Gtk.ListStore(str, str, str)
    current = _theme_mod.get_current_palette()
    names = _theme_mod.list_palettes()
    if current in names:
        names.remove(current)
        names.insert(0, current)
    for name in names:
        acc = _theme_mod.load_palette(name).get("P_ACC", "#4f9bff")
        label = name.replace("-", " ").title() + ("  (current)" if name == current else "")
        store.append([name, label, acc])

    row = Gtk.Box(spacing=10)
    row.pack_start(Gtk.Label(label="Colour palette:"), False, False, 0)
    combo = Gtk.ComboBox(model=store)
    swatch = Gtk.CellRendererText()
    swatch.set_fixed_size(24, -1)
    combo.pack_start(swatch, False)
    combo.add_attribute(swatch, "background", 2)
    text = Gtk.CellRendererText()
    combo.pack_start(text, True)
    combo.add_attribute(text, "text", 1)
    combo.set_active(0)
    row.pack_start(combo, True, True, 0)
    card.pack_start(row, False, False, 0)

    def on_apply(*_):
        it = combo.get_active_iter()
        if it is None:
            return
        name = store[it][0]
        _theme_mod.set_current_palette(name)
        _theme_mod.generate_wallpaper()
        notify_panel()
        win.destroy()

    buttons = Gtk.Box(spacing=8)
    buttons.set_halign(Gtk.Align.END)
    cancel = Gtk.Button(label="Cancel")
    cancel.connect("clicked", lambda *_: win.destroy())
    apply_btn = Gtk.Button(label="Apply")
    apply_btn.get_style_context().add_class("ld-apply")
    apply_btn.connect("clicked", on_apply)
    buttons.pack_start(cancel, False, False, 0)
    buttons.pack_start(apply_btn, False, False, 0)
    card.pack_start(buttons, False, False, 0)

    win.add(card)
    win.show_all()
    combo.grab_focus()
    Gtk.main()


def main():
    css = Gtk.CssProvider()
    css.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    settings = Gtk.Settings.get_default()
    if settings:
        settings.set_property("gtk-application-prefer-dark-theme", True)
    if "--wallpaper" in sys.argv:
        choose_wallpaper()
        return
    if "--theme" in sys.argv:
        theme_picker_window()
        return
    panel = Panel()
    panel._css_provider = css  # so reload_theme() can remove it later
    panel.show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
