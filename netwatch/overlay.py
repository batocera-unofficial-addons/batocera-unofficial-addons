#!/usr/bin/env python3
"""
netwatch overlay: a notification banner drawn over everything on an X11
display, including fullscreen emulators, with no compositor required.

Pure stdlib: talks to libX11, libXft and libXext (all shipped with Batocera)
via ctypes. The window is override-redirect, so Openbox never manages it, it
never takes input focus, and controllers keep working while it's on screen.

Styles:
  outline (default)  no background at all: the window is cut to the shape of
                     the outlined text (X Shape extension), so the game shows
                     through everywhere else. Real translucency would need a
                     compositor, which Batocera doesn't run.
  solid              opaque dark box with an accent bar.

  python3 overlay.py "test-pc has connected"
  python3 overlay.py --style solid --scale 1.5 "test-pc has connected"

Exit codes: 0 shown, 2 cannot open display, 3 cannot load libraries or font.
"""
import argparse
import ctypes
import ctypes.util
import os
import sys
import time

from ctypes import (POINTER, Structure, byref, c_char_p, c_int, c_long, c_short,
                    c_uint, c_ulong, c_ushort, c_void_p)


class XSetWindowAttributes(Structure):
    _fields_ = [("background_pixmap", c_ulong), ("background_pixel", c_ulong),
                ("border_pixmap", c_ulong), ("border_pixel", c_ulong),
                ("bit_gravity", c_int), ("win_gravity", c_int),
                ("backing_store", c_int), ("backing_planes", c_ulong),
                ("backing_pixel", c_ulong), ("save_under", c_int),
                ("event_mask", c_long), ("do_not_propagate_mask", c_long),
                ("override_redirect", c_int), ("colormap", c_ulong),
                ("cursor", c_ulong)]


class XRenderColor(Structure):
    _fields_ = [("red", c_ushort), ("green", c_ushort), ("blue", c_ushort),
                ("alpha", c_ushort)]


class XftColor(Structure):
    _fields_ = [("pixel", c_ulong), ("color", XRenderColor)]


class XGlyphInfo(Structure):
    _fields_ = [("width", c_ushort), ("height", c_ushort), ("x", c_short),
                ("y", c_short), ("xOff", c_short), ("yOff", c_short)]


class XImage(Structure):
    # Leading fields only; we just need the pixel buffer and its layout.
    _fields_ = [("width", c_int), ("height", c_int), ("xoffset", c_int),
                ("format", c_int), ("data", c_void_p), ("byte_order", c_int),
                ("bitmap_unit", c_int), ("bitmap_bit_order", c_int),
                ("bitmap_pad", c_int), ("depth", c_int), ("bytes_per_line", c_int),
                ("bits_per_pixel", c_int)]


class XftFont(Structure):
    _fields_ = [("ascent", c_int), ("descent", c_int), ("height", c_int),
                ("max_advance_width", c_int), ("charset", c_void_p),
                ("pattern", c_void_p)]


CW_BACK_PIXEL, CW_OVERRIDE_REDIRECT, CW_SAVE_UNDER = 1 << 1, 1 << 9, 1 << 10
INPUT_OUTPUT = 1
Z_PIXMAP, ALL_PLANES = 2, 0xFFFFFFFF
SHAPE_BOUNDING, SHAPE_INPUT, SHAPE_SET = 0, 2, 0


def load_libs():
    x11_name, xft_name = ctypes.util.find_library("X11"), ctypes.util.find_library("Xft")
    if not x11_name or not xft_name:
        return None, None
    x11, xft = ctypes.CDLL(x11_name), ctypes.CDLL(xft_name)

    x11.XOpenDisplay.restype = c_void_p
    x11.XOpenDisplay.argtypes = [c_char_p]
    for fn in ("XDefaultScreen",):
        getattr(x11, fn).restype = c_int
        getattr(x11, fn).argtypes = [c_void_p]
    for fn, rt in (("XRootWindow", c_ulong), ("XDisplayWidth", c_int),
                   ("XDisplayHeight", c_int), ("XDefaultVisual", c_void_p),
                   ("XDefaultColormap", c_ulong), ("XDefaultDepth", c_int)):
        getattr(x11, fn).restype = rt
        getattr(x11, fn).argtypes = [c_void_p, c_int]
    x11.XCreateWindow.restype = c_ulong
    x11.XCreateWindow.argtypes = [c_void_p, c_ulong, c_int, c_int, c_uint, c_uint, c_uint,
                                  c_int, c_uint, c_void_p, c_ulong,
                                  POINTER(XSetWindowAttributes)]
    for fn in ("XMapRaised", "XRaiseWindow", "XDestroyWindow"):
        getattr(x11, fn).argtypes = [c_void_p, c_ulong]
    x11.XMoveWindow.argtypes = [c_void_p, c_ulong, c_int, c_int]
    x11.XStoreName.argtypes = [c_void_p, c_ulong, c_char_p]
    x11.XFlush.argtypes = [c_void_p]
    x11.XSync.argtypes = [c_void_p, c_int]
    x11.XCloseDisplay.argtypes = [c_void_p]
    x11.XCreatePixmap.restype = c_ulong
    x11.XCreatePixmap.argtypes = [c_void_p, c_ulong, c_uint, c_uint, c_uint]
    x11.XFreePixmap.argtypes = [c_void_p, c_ulong]
    x11.XGetImage.restype = POINTER(XImage)
    x11.XGetImage.argtypes = [c_void_p, c_ulong, c_int, c_int, c_uint, c_uint, c_ulong, c_int]
    x11.XSetWindowBackgroundPixmap.argtypes = [c_void_p, c_ulong, c_ulong]
    x11.XClearWindow.argtypes = [c_void_p, c_ulong]
    x11.XCreateBitmapFromData.restype = c_ulong
    x11.XCreateBitmapFromData.argtypes = [c_void_p, c_ulong, c_char_p, c_uint, c_uint]

    xft.XftFontOpenName.restype = POINTER(XftFont)
    xft.XftFontOpenName.argtypes = [c_void_p, c_int, c_char_p]
    xft.XftFontClose.argtypes = [c_void_p, POINTER(XftFont)]
    xft.XftTextExtentsUtf8.argtypes = [c_void_p, POINTER(XftFont), c_char_p, c_int,
                                       POINTER(XGlyphInfo)]
    xft.XftDrawCreate.restype = c_void_p
    xft.XftDrawCreate.argtypes = [c_void_p, c_ulong, c_void_p, c_ulong]
    xft.XftDrawDestroy.argtypes = [c_void_p]
    xft.XftColorAllocValue.restype = c_int
    xft.XftColorAllocValue.argtypes = [c_void_p, c_void_p, c_ulong, POINTER(XRenderColor),
                                       POINTER(XftColor)]
    xft.XftDrawRect.argtypes = [c_void_p, POINTER(XftColor), c_int, c_int, c_uint, c_uint]
    xft.XftDrawStringUtf8.argtypes = [c_void_p, POINTER(XftColor), POINTER(XftFont),
                                      c_int, c_int, c_char_p, c_int]
    return x11, xft


def load_xext():
    name = ctypes.util.find_library("Xext")
    if not name:
        return None
    xext = ctypes.CDLL(name)
    xext.XShapeQueryExtension.restype = c_int
    xext.XShapeQueryExtension.argtypes = [c_void_p, POINTER(c_int), POINTER(c_int)]
    xext.XShapeCombineMask.argtypes = [c_void_p, c_ulong, c_int, c_int, c_int, c_ulong, c_int]
    xext.XShapeCombineRectangles.argtypes = [c_void_p, c_ulong, c_int, c_int, c_int,
                                             c_void_p, c_int, c_int, c_int]
    return xext


def hex_color(xft, dpy, visual, cmap, value):
    value = value.lstrip("#")
    r, g, b = (int(value[i:i + 2], 16) * 257 for i in (0, 2, 4))
    color = XftColor()
    xft.XftColorAllocValue(dpy, visual, cmap, byref(XRenderColor(r, g, b, 0xFFFF)),
                           byref(color))
    return color


def text_lines(xft, draw, cap_color, main_color, font, cap_font, f, cf, caption, text,
               x, y, gap):
    if caption:
        xft.XftDrawStringUtf8(draw, byref(cap_color), cap_font, x, y + cf.ascent,
                              caption, len(caption))
        y += cf.ascent + cf.descent + gap
    xft.XftDrawStringUtf8(draw, byref(main_color), font, x, y + f.ascent, text, len(text))


def apply_text_shape(x11, xft, xext, dpy, scr, win, w, h, edge, draw_texts):
    """Cut the window down to the text glyphs grown by `edge` pixels.

    Render the text white-on-black into an offscreen pixmap, read it back,
    threshold it into rows of bits, dilate (that ring becomes the outline),
    then hand the result to the Shape extension as the window's outline."""
    pix = x11.XCreatePixmap(dpy, win, w, h, x11.XDefaultDepth(dpy, scr))
    d = xft.XftDrawCreate(dpy, pix, x11.XDefaultVisual(dpy, scr),
                          x11.XDefaultColormap(dpy, scr))
    visual, cmap = x11.XDefaultVisual(dpy, scr), x11.XDefaultColormap(dpy, scr)
    black = hex_color(xft, dpy, visual, cmap, "#000000")
    white = hex_color(xft, dpy, visual, cmap, "#ffffff")
    xft.XftDrawRect(d, byref(black), 0, 0, w, h)
    draw_texts(d, white)
    img = x11.XGetImage(dpy, pix, 0, 0, w, h, ALL_PLANES, Z_PIXMAP).contents
    raw = ctypes.string_at(img.data, img.bytes_per_line * h)
    bpp = img.bits_per_pixel // 8
    rows = []
    for y in range(h):
        start = y * img.bytes_per_line
        greens = raw[start + 1:start + bpp * w:bpp]          # any channel works on grey
        rows.append(int("".join("1" if g > 70 else "0" for g in reversed(greens)), 2)
                    if greens else 0)
    full = (1 << w) - 1
    for _ in range(edge):                                    # horizontal grow
        rows = [(r | (r << 1) | (r >> 1)) & full for r in rows]
    grown = []
    for y in range(h):                                       # vertical grow
        acc = 0
        for yy in range(max(0, y - edge), min(h, y + edge + 1)):
            acc |= rows[yy]
        grown.append(acc)
    stride = (w + 7) // 8
    data = b"".join(r.to_bytes(stride, "little") for r in grown)
    mask = x11.XCreateBitmapFromData(dpy, win, data, w, h)
    xext.XShapeCombineMask(dpy, win, SHAPE_BOUNDING, 0, 0, mask, SHAPE_SET)
    xext.XShapeCombineRectangles(dpy, win, SHAPE_INPUT, 0, 0, None, 0, SHAPE_SET, 0)
    x11.XFreePixmap(dpy, mask)
    xft.XftDrawDestroy(d)
    x11.XFreePixmap(dpy, pix)


def text_width(xft, dpy, font, data):
    ext = XGlyphInfo()
    xft.XftTextExtentsUtf8(dpy, font, data, len(data), byref(ext))
    return ext.xOff


def main():
    ap = argparse.ArgumentParser(description="Show a notification banner over X11")
    ap.add_argument("text")
    ap.add_argument("--caption", default="SUNSHINE")
    ap.add_argument("--style", choices=("outline", "solid"), default="outline")
    ap.add_argument("--scale", type=float, default=1.0,
                    help="size multiplier (1.0 = 26px text at 1440p, 20px at 1080p)")
    ap.add_argument("--duration", type=float, default=5.0)
    ap.add_argument("--position", choices=("top-right", "top-left", "top-center"),
                    default="top-right")
    ap.add_argument("--display", default=os.environ.get("DISPLAY") or ":0")
    ap.add_argument("--font", default="DejaVu Sans")
    ap.add_argument("--accent", default="#4ade80")
    ap.add_argument("--bg", default="#161a22", help="solid style box colour")
    ap.add_argument("--outline", default="#000000", help="outline style edge colour")
    ap.add_argument("--fg", default="#ffffff")
    ap.add_argument("--no-animate", action="store_true")
    args = ap.parse_args()

    x11, xft = load_libs()
    if x11 is None:
        print("overlay: libX11/libXft not found", file=sys.stderr)
        return 3
    dpy = x11.XOpenDisplay(args.display.encode())
    if not dpy:
        print(f"overlay: cannot open display {args.display}", file=sys.stderr)
        return 2

    scr = x11.XDefaultScreen(dpy)
    root = x11.XRootWindow(dpy, scr)
    sw, sh = x11.XDisplayWidth(dpy, scr), x11.XDisplayHeight(dpy, scr)
    visual, cmap = x11.XDefaultVisual(dpy, scr), x11.XDefaultColormap(dpy, scr)

    # Scale from the screen height: 26px text at 1440p, 20px at 1080p.
    size = max(14, int(sh / 54 * args.scale))
    font = xft.XftFontOpenName(dpy, scr, f"{args.font}:bold:pixelsize={size}".encode())
    cap_font = xft.XftFontOpenName(dpy, scr,
                                   f"{args.font}:bold:pixelsize={max(11, size * 11 // 20)}".encode())
    if not font or not cap_font:
        print("overlay: cannot load font", file=sys.stderr)
        x11.XCloseDisplay(dpy)
        return 3

    text = args.text.encode("utf-8")
    caption = args.caption.encode("utf-8")
    f, cf = font.contents, cap_font.contents
    style = args.style
    xext = load_xext() if style == "outline" else None
    if style == "outline" and (xext is None or not xext.XShapeQueryExtension(
            dpy, byref(c_int()), byref(c_int()))):
        style = "solid"                        # no Shape extension: fall back to the box
    edge = max(2, size // 10)                  # outline thickness in px
    if style == "outline":
        pad_x = pad_y = edge + 1
        accent_w = 0
    else:
        pad_x, pad_y = size * 3 // 4, size // 2
        accent_w = max(3, size // 7)
    gap = size // 8
    inner_w = max(text_width(xft, dpy, font, text),
                  text_width(xft, dpy, cap_font, caption) if caption else 0)
    w = accent_w + pad_x * 2 + inner_w
    cap_h = (cf.ascent + cf.descent + gap) if caption else 0
    h = pad_y * 2 + cap_h + f.ascent + f.descent
    w = min(w, sw - 2 * size)
    margin = size
    target_y = margin
    target_x = {"top-right": sw - w - margin, "top-left": margin,
                "top-center": (sw - w) // 2}[args.position]

    attrs = XSetWindowAttributes()
    attrs.override_redirect = 1
    attrs.save_under = 1
    attrs.background_pixel = 0
    start_x = sw if args.position == "top-right" else target_x
    start_y = target_y if args.position == "top-right" else -h
    win = x11.XCreateWindow(dpy, root, start_x, start_y, w, h, 0,
                            x11.XDefaultDepth(dpy, scr), INPUT_OUTPUT, None,
                            CW_OVERRIDE_REDIRECT | CW_BACK_PIXEL | CW_SAVE_UNDER, byref(attrs))
    x11.XStoreName(dpy, win, b"netwatch-overlay")
    fg = hex_color(xft, dpy, visual, cmap, args.fg)
    accent = hex_color(xft, dpy, visual, cmap, args.accent)
    bg = hex_color(xft, dpy, visual, cmap, args.outline if style == "outline" else args.bg)

    # Render the banner once into a pixmap and make it the window background.
    # The X server then repaints it by itself on every expose (e.g. when a game
    # briefly covers us), so there is never a blank frame between raise and redraw.
    banner = x11.XCreatePixmap(dpy, win, w, h, x11.XDefaultDepth(dpy, scr))
    bdraw = xft.XftDrawCreate(dpy, banner, visual, cmap)
    xft.XftDrawRect(bdraw, byref(bg), 0, 0, w, h)
    if accent_w:
        xft.XftDrawRect(bdraw, byref(accent), 0, 0, accent_w, h)
    text_lines(xft, bdraw, accent, fg, font, cap_font, f, cf, caption, text,
               accent_w + pad_x, pad_y, gap)
    if style == "outline":
        apply_text_shape(x11, xft, xext, dpy, scr, win, w, h, edge, draw_texts=lambda d, white: (
            text_lines(xft, d, white, white, font, cap_font, f, cf, caption, text,
                       accent_w + pad_x, pad_y, gap)))
    x11.XSetWindowBackgroundPixmap(dpy, win, banner)
    x11.XClearWindow(dpy, win)

    def place(x, y):
        x11.XMoveWindow(dpy, win, x, y)
        x11.XRaiseWindow(dpy, win)
        x11.XFlush(dpy)

    x11.XMapRaised(dpy, win)
    frames = 1 if args.no_animate else 8
    for i in range(1, frames + 1):             # slide in (ease-out)
        t = 1 - (1 - i / frames) ** 3
        place(int(start_x + (target_x - start_x) * t), int(start_y + (target_y - start_y) * t))
        time.sleep(0.018)

    # Hold. Re-raise every 100ms in case a fullscreen game raises its own window.
    end = time.time() + args.duration
    while time.time() < end:
        place(target_x, target_y)
        time.sleep(0.1)

    for i in range(1, frames + 1):             # slide out (ease-in)
        t = (i / frames) ** 3
        place(int(target_x + (start_x - target_x) * t), int(target_y + (start_y - target_y) * t))
        time.sleep(0.018)

    xft.XftDrawDestroy(bdraw)
    x11.XFreePixmap(dpy, banner)
    xft.XftFontClose(dpy, font)
    xft.XftFontClose(dpy, cap_font)
    x11.XDestroyWindow(dpy, win)
    x11.XSync(dpy, 0)
    x11.XCloseDisplay(dpy)
    return 0


if __name__ == "__main__":
    sys.exit(main())