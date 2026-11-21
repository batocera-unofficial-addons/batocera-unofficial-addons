#!/usr/bin/env python3
"""Put Batocera's folders in the KDE Plasma Desktop's file dialogs and
Dolphin: Userdata, ROMs, BIOS, Saves and Screenshots at the top of Places,
and /userdata as Dolphin's starting folder.

Run by kdeplasma-launch.sh (with Batocera's python) before Plasma starts.
Only adds what is missing, so places the user removes or reorders stay as
they are once added. Usage: kdeplasma-places.py <plasma home folder>
"""
import os
import sys
import time
import xml.etree.ElementTree as ET

# Write as the plasma user (it owns this home), never as root: a link a
# program in Plasma put here then cannot redirect a write into Batocera.
# Paths are relative to the home: plasma cannot reach it through the
# add-on's folder, which only root may open.
os.chdir(sys.argv[1])
home = "."
if os.getuid() == 0:
    os.setgroups([])
    os.setgid(1000)
    os.setuid(1000)
places_file = os.path.join(home, ".local/share/user-places.xbel")
dolphinrc = os.path.join(home, ".config/dolphinrc")

PLACES = [
    ("/userdata", "Userdata", "drive-harddisk"),
    ("/userdata/roms", "ROMs", "folder-games"),
    ("/userdata/bios", "BIOS", "folder-system"),
    ("/userdata/saves", "Saves", "folder-document"),
    ("/userdata/screenshots", "Screenshots", "folder-pictures"),
]

ET.register_namespace("bookmark", "http://www.freedesktop.org/standards/desktop-bookmarks")
ET.register_namespace("kdepriv", "http://www.kde.org/kdepriv")
ET.register_namespace("mime", "http://www.freedesktop.org/standards/shared-mime-info")
BOOKMARK_NS = "{http://www.freedesktop.org/standards/desktop-bookmarks}"

if os.path.exists(places_file):
    tree = ET.parse(places_file)
    xbel = tree.getroot()
else:
    xbel = ET.Element("xbel")
    tree = ET.ElementTree(xbel)

have = {b.get("href") for b in xbel.findall("bookmark")}
stamp = int(time.time())
added = 0
for index, (path, title, icon) in enumerate(PLACES):
    href = "file://" + path
    if href in have or not os.path.isdir(path):
        continue
    bookmark = ET.Element("bookmark", href=href)
    ET.SubElement(bookmark, "title").text = title
    info = ET.SubElement(bookmark, "info")
    fd = ET.SubElement(info, "metadata", owner="http://freedesktop.org")
    ET.SubElement(fd, BOOKMARK_NS + "icon", name=icon)
    kde = ET.SubElement(info, "metadata", owner="http://www.kde.org")
    ET.SubElement(kde, "ID").text = f"{stamp}/{index}"
    ET.SubElement(kde, "isSystemItem").text = "false"
    # At the top, in order, before the standard places
    xbel.insert(index, bookmark)
    added += 1

if added:
    os.makedirs(os.path.dirname(places_file), exist_ok=True)
    ET.indent(tree)
    tree.write(places_file, encoding="utf-8", xml_declaration=True)

# Dolphin opens in /userdata (only set once, so the user can change it)
lines = open(dolphinrc).read().splitlines() if os.path.exists(dolphinrc) else []
if not any(line.startswith("HomeUrl=") for line in lines):
    if "[General]" in lines:
        lines.insert(lines.index("[General]") + 1, "HomeUrl=file:///userdata")
    else:
        lines = ["[General]", "HomeUrl=file:///userdata", "RememberOpenedTabs=false", ""] + lines
    os.makedirs(os.path.dirname(dolphinrc), exist_ok=True)
    with open(dolphinrc, "w") as f:
        f.write("\n".join(lines) + "\n")
print(f"places: added {added}")
