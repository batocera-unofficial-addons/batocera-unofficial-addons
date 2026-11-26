"""Theme engine for the Native X11 Desktop.

Loads .palette files, generates CSS for the panel and desktop, and
renders the SVG wallpaper template with the palette's accent and base
colours. The same logic is used by the Wayland desktop (with different
install paths).
"""

import os, re, shutil, subprocess

INSTALL = os.path.dirname(os.path.abspath(__file__))
CONF = "/userdata/system/configs/native-x11-desktop"
PALETTES_DIR = os.path.join(INSTALL, "palettes")
TEMPLATE = os.path.join(INSTALL, "wallpaper.svg.template")
DEFAULT_PALETTE = "blue"


def load_palette(name=None, palettes_dir=None):
    """Parse a .palette file, return dict of P_* vars."""
    if palettes_dir is None:
        palettes_dir = PALETTES_DIR
    if name is None:
        name = get_current_palette()
    path = os.path.join(palettes_dir, name + ".palette")
    p = {}
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    p[k.strip()] = v.strip()
    except FileNotFoundError:
        # Fall back to blue
        if name != DEFAULT_PALETTE:
            return load_palette(DEFAULT_PALETTE, palettes_dir)
    return p


def _hex_to_rgb(h):
    """'#aabbcc' -> (170, 187, 204)"""
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def _rgba(hexcol, alpha):
    """'#aabbcc', 0.5 -> 'rgba(170, 187, 204, 0.5)'"""
    r, g, b = _hex_to_rgb(hexcol)
    return f"rgba({r}, {g}, {b}, {alpha})"


def build_panel_css(p):
    """Generate panel CSS from palette dict."""
    acc = p.get("P_ACC", "#4f9bff")
    acc_h = p.get("P_ACC_H", "#64a8ff")
    fg = p.get("P_FG", "#e8edf5")
    fg_dim = p.get("P_FG_DIM", "#9aa6b8")
    base = p.get("P_BASE", "#0b0f17")
    base1 = p.get("P_BASE1", "#141b28")

    return f"""
* {{ font-family: "DejaVu Sans", sans-serif; font-size: 14px; }}
window {{ background: transparent; }}
.panel {{ background: {_rgba(base1, 0.88)}; border-radius: 14px;
          border: 1px solid rgba(255,255,255,0.10); }}
.start {{ background: {acc}; border-radius: 10px; padding: 4px 14px;
          color: #ffffff; font-weight: bold; }}
.start:hover {{ background: {acc_h}; }}
.pin, .task {{ background: transparent; border-radius: 8px; padding: 2px 6px; min-width: 0; }}
.pin:hover, .task:hover {{ background: rgba(255,255,255,0.09); }}
.task.active {{ background: {_rgba(acc, 0.24)}; }}
.status {{ color: {fg_dim}; padding: 0 4px; }}
.clock {{ color: {fg}; font-weight: bold; padding: 0 10px; }}
.es-btn {{ background: rgba(255,181,71,0.15); border-radius: 8px; padding: 4px 10px; color: #ffb547; }}
.es-btn:hover {{ background: rgba(255,181,71,0.26); }}
.card {{ background: {_rgba(base1, 0.96)}; border-radius: 16px;
         border: 1px solid rgba(255,255,255,0.10); }}
.card label, .card button {{ color: {fg}; }}
.search entry {{ background: rgba(255,255,255,0.06); color: {fg};
                 border: 1px solid rgba(255,255,255,0.12); border-radius: 8px; }}
.search image {{ color: {fg_dim}; }}
.cat-btn {{ background: transparent; border-radius: 8px; padding: 4px 10px; color: {fg_dim}; }}
.cat-btn:hover {{ background: rgba(255,255,255,0.09); }}
.cat-btn.active {{ background: {acc}; color: {base}; }}
.app-btn {{ background: transparent; border-radius: 10px; padding: 6px; }}
.app-btn:hover {{ background: rgba(255,255,255,0.09); }}
.app-btn label {{ color: {fg}; }}
.power-btn {{ background: transparent; border-radius: 8px; padding: 4px 8px; }}
.power-btn:hover {{ background: rgba(255,255,255,0.09); }}
.power-btn label {{ color: {fg_dim}; }}
.warn label {{ color: #ff6b6b; }}
scale trough {{ background: rgba(255,255,255,0.15); min-height: 6px; border-radius: 3px; }}
scale highlight {{ background: {acc}; border-radius: 3px; }}
scale slider {{ background: {fg}; min-width: 16px; min-height: 16px; border-radius: 8px; }}
tooltip {{ background: {_rgba(base1, 0.95)}; color: {fg}; border-radius: 6px;
           border: 1px solid rgba(255,255,255,0.10); }}
"""


def build_desktop_css(p):
    """Generate desktop icon CSS from palette dict."""
    acc = p.get("P_ACC", "#4f9bff")
    return f"""
.icon-box {{ border-radius: 10px; padding: 4px; }}
.icon-box:hover {{ background: rgba(255,255,255,0.10); }}
.icon-box.selected {{ background: {_rgba(acc, 0.35)}; }}
.icon-label {{ color: #ffffff;
               text-shadow: 1px 1px 3px rgba(0,0,0,0.9), 0 0 6px rgba(0,0,0,0.9); }}
"""


def generate_wallpaper(p=None, template_path=None, output_path=None):
    """Replace {{P_ACC}} and {{P_BASE}} in the SVG template, write to output."""
    if p is None:
        p = load_palette()
    if template_path is None:
        template_path = TEMPLATE
    if output_path is None:
        os.makedirs(CONF, exist_ok=True)
        output_path = os.path.join(CONF, "wallpaper-themed.svg")
    try:
        with open(template_path) as f:
            svg = f.read()
    except FileNotFoundError:
        return None
    svg = svg.replace("{{P_ACC}}", p.get("P_ACC", "#4f9bff"))
    svg = svg.replace("{{P_BASE}}", p.get("P_BASE", "#0b0f17"))
    # Only write when the palette changed: the desktop watches CONF and
    # calls this again on every change there, so an unconditional write
    # would keep it redrawing the wallpaper in a loop
    try:
        with open(output_path) as f:
            same = f.read() == svg
    except OSError:
        same = False
    if not same:
        with open(output_path, "w") as f:
            f.write(svg)
    return _render_png(output_path) or output_path


def _render_png(svg_path):
    """Render svg_path to a PNG next to it and return the PNG's path.

    Batocera's gdk-pixbuf has no SVG loader, so GTK cannot show the SVG
    itself; rsvg-convert (librsvg) is part of Batocera. Rendered again only
    when the SVG is newer. Returns None if it cannot be rendered.
    """
    png_path = os.path.splitext(svg_path)[0] + ".png"
    try:
        if os.path.getmtime(png_path) >= os.path.getmtime(svg_path):
            return png_path
    except OSError:
        pass
    rsvg = shutil.which("rsvg-convert")
    if not rsvg:
        return None
    tmp = png_path + ".tmp"
    try:
        subprocess.run([rsvg, "-w", "1920", "-h", "1080", "-o", tmp, svg_path],
                       check=True, timeout=30,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        os.replace(tmp, png_path)
    except (OSError, subprocess.SubprocessError):
        try:
            os.remove(tmp)
        except OSError:
            pass
        return None
    return png_path


def get_current_palette(conf_dir=None):
    """Read the saved palette name from conf_dir/theme."""
    if conf_dir is None:
        conf_dir = CONF
    try:
        with open(os.path.join(conf_dir, "theme")) as f:
            name = f.read().strip()
            if name:
                return name
    except FileNotFoundError:
        pass
    return DEFAULT_PALETTE


def set_current_palette(name, conf_dir=None):
    """Save palette name to conf_dir/theme."""
    if conf_dir is None:
        conf_dir = CONF
    os.makedirs(conf_dir, exist_ok=True)
    with open(os.path.join(conf_dir, "theme"), "w") as f:
        f.write(name + "\n")


def list_palettes(palettes_dir=None):
    """Return sorted list of palette names (without .palette extension)."""
    if palettes_dir is None:
        palettes_dir = PALETTES_DIR
    try:
        return sorted(
            f[:-8] for f in os.listdir(palettes_dir) if f.endswith(".palette")
        )
    except FileNotFoundError:
        return []


def has_custom_wallpaper(conf_dir=None):
    """Check if the user set a custom wallpaper (not the themed one)."""
    if conf_dir is None:
        conf_dir = CONF
    for ext in ("png", "jpg", "jpeg", "bmp", "svg"):
        path = os.path.join(conf_dir, f"wallpaper.{ext}")
        if os.path.exists(path):
            return path
    return None
