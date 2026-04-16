#!/usr/bin/env python3
"""Remove Add Non-Steam Games entries from ES > Steam gamelist and launcher files.
Run on Batocera to clear entries so you can re-run Add Non-Steam Games.
"""
import os
import xml.etree.ElementTree as ET
import urllib.request

ROMS_BASE = "/userdata/.roms_base/steam"
ROMS_FALLBACK = "/userdata/roms/steam"
GAMELIST = "gamelist.xml"


def main():
    roms = ROMS_BASE if os.path.isdir("/userdata/.roms_base") else ROMS_FALLBACK
    gamelist_path = os.path.join(roms, GAMELIST)
    if not os.path.isfile(gamelist_path):
        print(f"No gamelist at {gamelist_path}")
        return

    tree = ET.parse(gamelist_path)
    root = tree.getroot()
    removed = []
    for game in list(root.findall("game")):
        genre = game.find("genre")
        if genre is not None and genre.text == "Non-Steam":
            path_el = game.find("path")
            if path_el is not None and path_el.text:
                p = path_el.text.strip()
                if p.startswith("./"):
                    p = p[2:]
                launcher = os.path.join(roms, p)
                keys_file = launcher + ".keys"
                if os.path.isfile(launcher):
                    os.remove(launcher)
                    removed.append(launcher)
                if os.path.isfile(keys_file):
                    os.remove(keys_file)
                    removed.append(keys_file)
                root.remove(game)

    if removed:
        tree.write(gamelist_path, encoding="utf-8", xml_declaration=True, default_namespace="")
        print("Removed:", ", ".join(os.path.basename(r) for r in removed))
    else:
        print("No Non-Steam entries found")

    try:
        urllib.request.urlopen("http://127.0.0.1:1234/reloadgames", timeout=2)
        print("ES reloaded")
    except Exception:
        pass


if __name__ == "__main__":
    main()
