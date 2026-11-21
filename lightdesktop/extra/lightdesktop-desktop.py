#!/usr/bin/env python3
"""The Light Desktop's desktop: the wallpaper, with icons on it for what is
in the Desktop folder (/userdata/system/Desktop): apps, folders and files.

Double-click an icon to open it; right-click an icon or the wallpaper for
more. Apps are added from the app menu (right-click > Add to the desktop) or
by putting a .desktop file or a link in the folder. The first time, the
folder gets links to ROMs, BIOS, Saves and Screenshots and a few apps.

Runs inside the Light Desktop's labwc (lightdesktop-session.sh), on
gtk-layer-shell's background layer, behind every window.
"""
import os
import re
import shlex
import shutil
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
CONF = "/userdata/system/configs/lightdesktop"
DESKTOP = "/userdata/system/Desktop"
DEFAULT_WALLPAPER = os.path.join(INSTALL, "wallpaper.png")
PANEL_ROOM = 80          # the panel along the bottom
ITEM_W, ITEM_H = 104, 104
TERMINAL = ["xterm", "-fs", "14", "-fg", "white", "-bg", "black", "-fa", "Monospace", "-en", "UTF-8", "-sb", "-rightbar"]

CSS = b"""
.ld-desktop flowbox, .ld-desktop flowboxchild { background: transparent; }
.ld-desktop flowboxchild { border-radius: 10px; padding: 6px 2px; }
.ld-desktop flowboxchild:hover { background: rgba(255, 255, 255, 0.10); }
.ld-desktop flowboxchild:selected { background: rgba(79, 155, 255, 0.35); }
.ld-desktop label {
  color: #ffffff; font-size: 10pt;
  text-shadow: 0 1px 3px rgba(0, 0, 0, 0.9), 0 0 2px rgba(0, 0, 0, 0.9);
}
"""


def spawn(argv):
    """Starts a program on its own (not a child of this one), in /userdata."""
    try:
        subprocess.Popen(["/bin/sh", "-c", 'cd /userdata && "$@" >/dev/null 2>&1 &', "sh"] + argv).wait()
    except OSError as e:
        print(f"desktop: could not start {argv}: {e}", file=sys.stderr)


def wallpaper_path():
    if os.path.isdir(CONF):
        for f in sorted(os.listdir(CONF)):
            if f.startswith("wallpaper."):
                return os.path.join(CONF, f)
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
    def __init__(self):
        super().__init__(title="Light Desktop wallpaper")
        self.get_style_context().add_class("ld-desktop")
        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.BACKGROUND)
        GtkLayerShell.set_namespace(self, "lightdesktop-desktop")
        for edge in (GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT,
                     GtkLayerShell.Edge.TOP, GtkLayerShell.Edge.BOTTOM):
            GtkLayerShell.set_anchor(self, edge, True)
        GtkLayerShell.set_exclusive_zone(self, -1)  # the whole screen, under the panel too

        overlay = Gtk.Overlay()
        self.add(overlay)
        self.background = Gtk.Image()
        overlay.add(self.background)

        self.grid = Gtk.FlowBox(orientation=Gtk.Orientation.VERTICAL, homogeneous=True,
                                selection_mode=Gtk.SelectionMode.SINGLE, activate_on_single_click=False,
                                row_spacing=4, column_spacing=4, valign=Gtk.Align.START, halign=Gtk.Align.START)
        self.grid.set_margin_top(16)
        self.grid.set_margin_start(16)
        self.grid.connect("child-activated", lambda _g, child: child.item.open())
        overlay.add_overlay(self.grid)

        # Clicks on the empty wallpaper (the grid only covers its icons)
        events = Gtk.EventBox(visible_window=False)
        events.connect("button-press-event", self.on_wallpaper_click)
        overlay.add_overlay(events)
        overlay.reorder_overlay(events, 0)
        self.grid.connect("button-press-event", self.on_grid_click)

        self.size = (0, 0)
        self.connect("size-allocate", self.on_size)
        self.monitors = []
        for folder in (DESKTOP, CONF):
            os.makedirs(folder, exist_ok=True)
            mon = Gio.File.new_for_path(folder).monitor_directory(Gio.FileMonitorFlags.WATCH_MOVES, None)
            mon.set_rate_limit(500)
            mon.connect("changed", self.on_folder_changed)
            self.monitors.append(mon)
        self.reload_pending = False
        self.fill()
        self.connect("destroy", Gtk.main_quit)

    # Wallpaper, scaled to cover the screen like swaybg's "fill"
    def on_size(self, _w, alloc):
        size = (alloc.width, alloc.height)
        if size != self.size:
            self.size = size
            rows = max(1, (alloc.height - PANEL_ROOM - 16) // (ITEM_H + 4))
            self.grid.set_max_children_per_line(rows)
            self.grid.set_min_children_per_line(rows)
            GLib.idle_add(self.set_wallpaper)

    def set_wallpaper(self):
        w, h = self.size
        if not w or not h:
            return False
        path = wallpaper_path()
        try:
            pix = GdkPixbuf.Pixbuf.new_from_file(path)
        except GLib.Error:
            pix = GdkPixbuf.Pixbuf.new_from_file(DEFAULT_WALLPAPER)
        scale = max(w / pix.get_width(), h / pix.get_height())
        sw, sh = max(w, round(pix.get_width() * scale)), max(h, round(pix.get_height() * scale))
        pix = pix.scale_simple(sw, sh, GdkPixbuf.InterpType.BILINEAR)
        pix = pix.new_subpixbuf((sw - w) // 2, (sh - h) // 2, w, h)
        self.background.set_from_pixbuf(pix)
        return False

    def on_folder_changed(self, _mon, _f, _other, _event):
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

    def fill(self):
        for child in self.grid.get_children():
            self.grid.remove(child)
        for item in self.items():
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            box.set_size_request(ITEM_W, ITEM_H - 12)
            pix = icon_pixbuf(item.gicon, 48)
            box.pack_start(Gtk.Image.new_from_pixbuf(pix) if pix else Gtk.Image(), False, False, 0)
            label = Gtk.Label(label=item.name, max_width_chars=12, justify=Gtk.Justification.CENTER)
            label.set_line_wrap(True)
            label.set_lines(2)
            label.set_ellipsize(3)
            box.pack_start(label, False, False, 0)
            child = Gtk.FlowBoxChild()
            child.add(box)
            child.item = item
            child.set_tooltip_text(item.name)
            self.grid.add(child)
        self.grid.show_all()
        # Nothing selected until clicked (GTK selects the first one by itself)
        GLib.idle_add(lambda: self.grid.unselect_all() or False)

    def on_grid_click(self, _grid, event):
        if event.button != 3:
            return False
        child = self.grid.get_child_at_pos(int(event.x), int(event.y))
        if child is None:
            return self.on_wallpaper_click(None, event)
        self.grid.select_child(child)
        item = child.item
        entries = [("Open", item.open)]
        if item.app is None:
            entries.append(("Show in the File Manager",
                            lambda: spawn(["pcmanfm", os.path.dirname(os.path.realpath(item.path))])))
        if item.removable:
            entries.append(("Remove from the desktop", lambda: os.remove(item.path)))
        self.popup(entries, event)
        return True

    def on_wallpaper_click(self, _w, event):
        self.grid.unselect_all()
        if event.button != 3:
            return False
        self.popup([
            ("Apps", lambda: spawn(["pkill", "-USR1", "-f", "lightdesktop-panel.p[y]"])),
            ("File Manager", lambda: spawn(["pcmanfm", "/userdata"])),
            ("Terminal", lambda: spawn(TERMINAL)),
            ("Open the Desktop folder", lambda: spawn(["pcmanfm", DESKTOP])),
            None,
            ("Change wallpaper", lambda: spawn(["python3", os.path.join(INSTALL, "lightdesktop-panel.py"), "--wallpaper"])),
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
