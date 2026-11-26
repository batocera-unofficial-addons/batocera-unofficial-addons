#!/usr/bin/env python3
"""The Native Wayland Desktop's desktop: the wallpaper, with icons on it for what is
in the Desktop folder (/userdata/system/Desktop): apps, folders and files.

Double-click an icon to open it, and drag it to move it (it snaps to a grid
and stays there, saved in icons.json); right-click an icon or the wallpaper
for more. Apps are added from the app menu (right-click > Add to the
desktop) or by putting a .desktop file or a link in the folder. The first
time, the folder gets links to ROMs, BIOS, Saves and Screenshots and a few
apps.

Runs inside the Native Wayland Desktop's labwc (native-wayland-desktop-session.sh), on
gtk-layer-shell's background layer, behind every window.
"""
import json
import os
import re
import shlex
import subprocess
import sys
import warnings

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
warnings.filterwarnings("ignore", category=DeprecationWarning)
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, GtkLayerShell  # noqa: E402

INSTALL = os.path.dirname(os.path.abspath(__file__))
CONF = "/userdata/system/configs/native-wayland-desktop"
DESKTOP = "/userdata/system/Desktop"
DEFAULT_WALLPAPER = os.path.join(INSTALL, "wallpaper.png")
POSITIONS = os.path.join(CONF, "icons.json")  # where each icon was dragged to
PANEL_ROOM = 80          # the panel along the bottom
ITEM_W, ITEM_H = 104, 104
CELL_W, CELL_H = ITEM_W + 8, ITEM_H + 8  # one space of the icon grid
MARGIN = 16
DRAG_START = 8           # pixels the mouse moves before a press becomes a drag
TERMINAL = ["xterm", "-fs", "14", "-fg", "white", "-bg", "black", "-fa", "Monospace", "-en", "UTF-8", "-sb", "-rightbar"]

# Theme engine
import importlib.util
_spec = importlib.util.spec_from_file_location("theme", os.path.join(INSTALL, "native-wayland-desktop-theme.py"))
_theme_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_theme_mod)
_palette = _theme_mod.load_palette()
CSS = _theme_mod.build_desktop_css(_palette).encode()


def spawn(argv):
    """Starts a program on its own (not a child of this one), in /userdata."""
    try:
        subprocess.Popen(["/bin/sh", "-c", 'cd /userdata && "$@" >/dev/null 2>&1 &', "sh"] + argv).wait()
    except OSError as e:
        print(f"desktop: could not start {argv}: {e}", file=sys.stderr)


def wallpaper_path():
    # User-set custom wallpaper takes priority
    custom = _theme_mod.has_custom_wallpaper(CONF)
    if custom:
        return custom
    # Generate themed wallpaper from SVG template
    themed = _theme_mod.generate_wallpaper()
    if themed and os.path.exists(themed):
        return themed
    return DEFAULT_WALLPAPER


def find_desktop_file(name):
    for d in ("/usr/share/applications",) + tuple(
            os.path.join("/userdata/system/configs", c) for c in sorted(os.listdir("/userdata/system/configs"))):
        path = os.path.join(d, name)
        if os.path.isfile(path):
            return path
    return None


def first_run():
    """A starting set of icons, made once: Batocera's folders and a few apps.
    Removing them later is kept (the folder is never filled again)."""
    if os.path.lexists(DESKTOP):
        return
    os.makedirs(DESKTOP)
    for name, target in (("ROMs", "/userdata/roms"), ("BIOS", "/userdata/bios"),
                         ("Saves", "/userdata/saves"), ("Screenshots", "/userdata/screenshots")):
        if os.path.isdir(target):
            os.symlink(target, os.path.join(DESKTOP, name))
    for app in ("pcmanfm.desktop", "Firefox.desktop", "xterm.desktop"):
        path = find_desktop_file(app)
        if path:
            os.symlink(path, os.path.join(DESKTOP, app))


def icon_pixbuf(gicon, size):
    theme = Gtk.IconTheme.get_default()
    for g in (gicon, Gio.ThemedIcon.new("text-x-generic")):
        if g is None:
            continue
        info = theme.lookup_by_gicon(g, size, Gtk.IconLookupFlags.FORCE_SIZE)
        if info:
            try:
                return info.load_icon()
            except GLib.Error:
                pass
    return None


class Item:
    """One icon: an app (.desktop file), a folder or a file."""

    def __init__(self, path):
        self.path = path
        self.app = None
        base = os.path.basename(path)
        if base.endswith(".desktop"):
            self.app = Gio.DesktopAppInfo.new_from_filename(path)
        if self.app:
            self.name = pretty_name(self.app.get_display_name() or base[:-8])
            self.gicon = self.app.get_icon()
        else:
            self.name = base
            try:
                info = Gio.File.new_for_path(path).query_info("standard::icon", Gio.FileQueryInfoFlags.NONE, None)
                self.gicon = info.get_icon()
            except GLib.Error:
                self.gicon = Gio.ThemedIcon.new("folder" if os.path.isdir(path) else "text-x-generic")
        # Links and app entries can be removed from the desktop without
        # touching anything else; real files and folders are left alone
        self.removable = os.path.islink(path) or base.endswith(".desktop")

    def open(self):
        if self.app:
            cmd = re.sub(r"\s%[fFuUdDnNickvm]", "", self.app.get_commandline() or "").replace("%%", "%")
            try:
                argv = shlex.split(cmd)
            except ValueError:
                return
            if argv:
                if self.app.get_boolean("Terminal"):
                    argv = TERMINAL + ["-e"] + argv
                spawn(argv)
        elif os.path.isdir(self.path):
            spawn(["pcmanfm", os.path.realpath(self.path)])
        else:
            try:
                Gio.AppInfo.launch_default_for_uri(Gio.File.new_for_path(self.path).get_uri(), None)
            except GLib.Error:
                # No app set for this kind of file: show it in the file manager
                spawn(["pcmanfm", os.path.dirname(os.path.realpath(self.path))])


def pretty_name(name):
    m = re.fullmatch(r"([a-z0-9-]+?)(-emu)?-config", name)
    if m:
        return " ".join(w.capitalize() for w in m.group(1).split("-")) + " settings"
    return {"File Manager PCManFM": "File Manager"}.get(name, name)


class Desktop(Gtk.Window):
    """The wallpaper with the icons on a grid. Icons can be dragged to any
    space on it; they snap into the nearest one, and the places are saved
    in POSITIONS. New icons take the first free space down the left."""

    def __init__(self):
        super().__init__(title="Native Wayland Desktop wallpaper")
        self.get_style_context().add_class("ld-desktop")
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BACKGROUND)
        GtkLayerShell.set_namespace(self, "native-wayland-desktop-desktop")
        for edge in (GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT,
                     GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)  # the whole screen, under the panel too

        overlay = Gtk.Overlay()
        self.add(overlay)
        self.background = Gtk.Image()
        overlay.add(self.background)

        # The icons sit in a Gtk.Fixed; clicks on empty space reach the
        # EventBox around it (the wallpaper)
        events = Gtk.EventBox(visible_window=False)
        events.connect("button-press-event", self.on_wallpaper_click)
        self.fixed = Gtk.Fixed()
        events.add(self.fixed)
        overlay.add_overlay(events)

        self.icons = {}         # file name -> icon widget
        self.cells = {}         # file name -> (column, row)
        self.selected = None
        self.drag = None        # the icon being pressed or dragged
        self.size = (0, 0)
        self.cols = self.rows = 1
        self.connect("size-allocate", self.on_size)
        self.monitors = []
        for folder in (DESKTOP, CONF):
            os.makedirs(folder, exist_ok=True)
            mon = Gio.File.new_for_path(folder).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            mon.set_rate_limit(500)
            mon.connect("changed", self.on_folder_changed)
            self.monitors.append(mon)
        self.reload_pending = False
        self.connect("destroy", Gtk.main_quit)

    # Size: the grid's columns and rows, and the wallpaper
    def on_size(self, _w, alloc):
        size = (alloc.width, alloc.height)
        if size != self.size:
            self.size = size
            self.cols = max(1, (alloc.width - MARGIN) // CELL_W)
            self.rows = max(1, (alloc.height - PANEL_ROOM - MARGIN) // CELL_H)
            GLib.idle_add(self.set_wallpaper)
            GLib.idle_add(self.fill)

    # Wallpaper, scaled to cover the screen like swaybg's "fill"
    def set_wallpaper(self):
        w, h = self.size
        if not w or not h:
            return False
        try:
            pix = GdkPixbuf.Pixbuf.new_from_file(wallpaper_path())
        except GLib.Error:
            pix = GdkPixbuf.Pixbuf.new_from_file(DEFAULT_WALLPAPER)
        scale = max(w / pix.get_width(), h / pix.get_height())
        sw, sh = max(w, round(pix.get_width() * scale)), max(h, round(pix.get_height() * scale))
        pix = pix.scale_simple(sw, sh, GdkPixbuf.InterpType.BILINEAR)
        pix = pix.new_subpixbuf((sw - w) // 2, (sh - h) // 2, w, h)
        self.background.set_from_pixbuf(pix)
        return False

    def on_folder_changed(self, _mon, changed, _other, _event):
        # The icon places are saved in CONF too: that is this program's own
        # write, not a new wallpaper (reloading would save again, and again)
        if changed and (changed.get_basename() or "").startswith(os.path.basename(POSITIONS)):
            return
        # Several changes come at once; reload once they settle
        if not self.reload_pending:
            self.reload_pending = True
            GLib.timeout_add(300, self.reload)

    def reload(self):
        self.reload_pending = False
        self.fill()
        self.set_wallpaper()  # "Change wallpaper" saves a new one in CONF
        return False

    # Icons
    def items(self):
        try:
            names = os.listdir(DESKTOP)
        except OSError:
            return []
        items = []
        for name in names:
            if name.startswith("."):
                continue
            path = os.path.join(DESKTOP, name)
            if os.path.islink(path) and not os.path.exists(path):
                continue  # a link to something removed
            item = Item(path)
            if item.app is None and name.endswith(".desktop"):
                continue
            items.append(item)
        # Folders first, then apps, then files, each by name
        def order(i):
            return (0 if (i.app is None and os.path.isdir(i.path)) else 1 if i.app else 2, i.name.lower())
        return sorted(items, key=order)

    @staticmethod
    def cell_xy(cell):
        col, row = cell
        return MARGIN + col * CELL_W, MARGIN + row * CELL_H

    def free_cell(self, taken):
        # Down the left first, like a new desktop
        for col in range(self.cols):
            for row in range(self.rows):
                if (col, row) not in taken:
                    return (col, row)
        return (self.cols - 1, self.rows - 1)

    def fill(self, arrange=False):
        if not self.size[0]:
            return False
        saved = {} if arrange else load_positions()
        for widget in self.icons.values():
            self.fixed.remove(widget)
        self.icons, self.cells = {}, {}
        self.selected = self.drag = None
        items = self.items()
        taken = set()
        # Icons with a saved place keep it (if it is still on screen and free)
        for item in items:
            name = os.path.basename(item.path)
            cell = saved.get(name)
            if cell and 0 <= cell[0] < self.cols and 0 <= cell[1] < self.rows and tuple(cell) not in taken:
                self.cells[name] = tuple(cell)
                taken.add(tuple(cell))
        for item in items:
            name = os.path.basename(item.path)
            if name not in self.cells:
                self.cells[name] = self.free_cell(taken)
                taken.add(self.cells[name])
            widget = self.make_icon(item)
            self.icons[name] = widget
            self.fixed.put(widget, *self.cell_xy(self.cells[name]))
        self.fixed.show_all()
        if self.cells != saved:
            save_positions(self.cells)
        return False

    def make_icon(self, item):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.set_size_request(ITEM_W, ITEM_H)
        pix = icon_pixbuf(item.gicon, 48)
        image = Gtk.Image.new_from_pixbuf(pix) if pix else Gtk.Image()
        image.set_margin_top(8)
        box.pack_start(image, False, False, 0)
        label = Gtk.Label(label=item.name, max_width_chars=12, justify=Gtk.Justification.CENTER)
        label.set_line_wrap(True)
        label.set_lines(2)
        label.set_ellipsize(3)
        box.pack_start(label, False, False, 0)
        widget = Gtk.EventBox()  # a window of its own, so it can be styled and dragged
        widget.get_style_context().add_class("ld-icon")
        widget.add(box)
        widget.item = item
        widget.set_tooltip_text(item.name)
        widget.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK
                          | Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        widget.connect("button-press-event", self.on_icon_press)
        widget.connect("motion-notify-event", self.on_icon_motion)
        widget.connect("button-release-event", self.on_icon_release)
        widget.connect("enter-notify-event", lambda w, _e: w.get_style_context().add_class("ld-hover"))
        widget.connect("leave-notify-event", lambda w, _e: w.get_style_context().remove_class("ld-hover"))
        return widget

    def select(self, widget):
        if self.selected is not None:
            self.selected.get_style_context().remove_class("ld-selected")
        self.selected = widget
        if widget is not None:
            widget.get_style_context().add_class("ld-selected")

    def on_icon_press(self, widget, event):
        if event.type == Gdk.EventType._2BUTTON_PRESS and event.button == 1:
            self.drag = None
            widget.item.open()
            return True
        if event.type != Gdk.EventType.BUTTON_PRESS:
            return True
        self.select(widget)
        if event.button == 3:
            self.icon_menu(widget, event)
        elif event.button == 1:
            name = os.path.basename(widget.item.path)
            self.drag = {"widget": widget, "name": name, "x": event.x_root, "y": event.y_root,
                         "start": self.cell_xy(self.cells[name]), "moving": False}
        return True

    def on_icon_motion(self, _widget, event):
        d = self.drag
        if not d:
            return False
        dx, dy = event.x_root - d["x"], event.y_root - d["y"]
        # Only a real move starts a drag, so a shaky double-click still opens
        if not d["moving"] and abs(dx) < DRAG_START and abs(dy) < DRAG_START:
            return True
        d["moving"] = True
        w, h = self.size
        x = min(max(0, d["start"][0] + dx), w - ITEM_W)
        y = min(max(0, d["start"][1] + dy), h - ITEM_H)
        self.fixed.move(d["widget"], int(x), int(y))
        return True

    def on_icon_release(self, _widget, event):
        d, self.drag = self.drag, None
        if not d or not d["moving"]:
            return True
        # Snap to the nearest space; an icon already there swaps places
        x = d["start"][0] + event.x_root - d["x"]
        y = d["start"][1] + event.y_root - d["y"]
        col = min(max(0, round((x - MARGIN) / CELL_W)), self.cols - 1)
        row = min(max(0, round((y - MARGIN) / CELL_H)), self.rows - 1)
        old = self.cells[d["name"]]
        other = next((n for n, c in self.cells.items() if c == (col, row) and n != d["name"]), None)
        if other:
            self.cells[other] = old
            self.fixed.move(self.icons[other], *self.cell_xy(old))
        self.cells[d["name"]] = (col, row)
        self.fixed.move(d["widget"], *self.cell_xy((col, row)))
        save_positions(self.cells)
        return True

    def icon_menu(self, widget, event):
        item = widget.item
        entries = [("Open", item.open)]
        if item.app is None:
            entries.append(("Show in the File Manager",
                            lambda: spawn(["pcmanfm", os.path.dirname(os.path.realpath(item.path))])))
        if item.removable:
            entries.append(("Remove from the desktop", lambda: os.remove(item.path)))
        self.popup(entries, event)

    def on_wallpaper_click(self, _w, event):
        self.select(None)
        if event.button != 3:
            return False
        self.popup([
            ("Apps", lambda: spawn(["pkill", "-USR1", "-f", "native-wayland-desktop-panel.p[y]"])),
            ("File Manager", lambda: spawn(["pcmanfm", "/userdata"])),
            ("Terminal", lambda: spawn(TERMINAL)),
            ("Open the Desktop folder", lambda: spawn(["pcmanfm", DESKTOP])),
            ("Arrange icons", lambda: self.fill(arrange=True)),
            None,
            ("Change wallpaper", lambda: spawn(["python3", os.path.join(INSTALL, "native-wayland-desktop-panel.py"), "--wallpaper"])),
            None,
            ("Back to EmulationStation", lambda: spawn(["labwc", "--exit"])),
        ], event)
        return True

    def popup(self, entries, event):
        menu = Gtk.Menu()
        for entry in entries:
            if entry is None:
                menu.append(Gtk.SeparatorMenuItem())
                continue
            label, action = entry
            item = Gtk.MenuItem(label=label)
            item.connect("activate", lambda _i, a=action: a())
            menu.append(item)
        menu.show_all()
        menu.attach_to_widget(self, None)
        menu.popup_at_pointer(event)


def load_positions():
    try:
        with open(POSITIONS) as f:
            return {k: tuple(v) for k, v in json.load(f).items()
                    if isinstance(v, list) and len(v) == 2 and all(isinstance(n, int) for n in v)}
    except (OSError, ValueError, AttributeError):
        return {}


def save_positions(cells):
    try:
        os.makedirs(CONF, exist_ok=True)
        tmp = POSITIONS + ".tmp"
        with open(tmp, "w") as f:
            json.dump({k: list(v) for k, v in sorted(cells.items())}, f, indent=1)
        os.replace(tmp, POSITIONS)
    except OSError as e:
        print(f"desktop: could not save icon places: {e}", file=sys.stderr)


def main():
    first_run()
    css = Gtk.CssProvider()
    css.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), css,
                                             Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    Desktop().show_all()
    Gtk.main()


if __name__ == "__main__":
    main()
