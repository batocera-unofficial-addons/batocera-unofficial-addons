#!/usr/bin/env python3

from pathlib import Path
import os
import re
import py_compile
import xml.etree.ElementTree as ET

FEATURES = Path(
    "/userdata/system/configs/emulationstation/es_features_switch.cfg"
)

GENERATOR = Path(
    "/userdata/system/switch/configgen/generators/edenGenerator.py"
)

XDG_OPEN = Path(
    "/userdata/system/switch/extra/xdgfix/xdg-open"
)

FEATURE_VALUE = "nextendo_network"


def patch_features():
    if not FEATURES.is_file():
        print("[Nextendo] Switch feature file not installed; skipping.")
        return False

    text = FEATURES.read_text(encoding="utf-8")

    addition = """\
    <feature name="NEXTENDO NETWORK" group="SWITCH OPTIONS" submenu="NETWORK" value="nextendo_network" description="Enable NexTendo network redirection for supported games.">
      <choice name="Disabled" value="false" />
      <choice name="Enabled" value="true" />
    </feature>"""

    changed = False

    emulator_specs = (
        (
            "citron-emu",
            '    <sharedFeature value="hud_corner" '
            'group="SWITCH OPTIONS" submenu="DISPLAY" />',
        ),
        (
            "ryujinx-emu",
            '    <sharedFeature value="videomode" '
            'group="SWITCH OPTIONS" submenu="DISPLAY" />',
        ),
    )

    for emulator_name, anchor in emulator_specs:
        start = text.find(
            f'<emulator name="{emulator_name}"'
        )

        if start == -1:
            print(
                f"[Nextendo] {emulator_name} feature block "
                "not present; skipping."
            )
            continue

        end = text.find("</emulator>", start)

        if end == -1:
            raise RuntimeError(
                f"{emulator_name} feature block is malformed"
            )

        block = text[start:end]

        if 'value="nextendo_network"' in block:
            print(
                f"[Nextendo] {emulator_name} Advanced Game "
                "Settings feature already present."
            )
            continue

        if anchor not in block:
            raise RuntimeError(
                f"{emulator_name} insertion anchor not found"
            )

        block = block.replace(
            anchor,
            anchor + "\n" + addition,
            1,
        )

        text = text[:start] + block + text[end:]
        changed = True

        print(
            f"[Nextendo] Added {emulator_name} "
            "Advanced Game Settings feature."
        )

    if not changed:
        return False

    text = re.sub(
        r'&(?!#\d+;|#x[0-9A-Fa-f]+;|'
        r'[A-Za-z_:][A-Za-z0-9_.:-]*;)',
        '&amp;',
        text,
    )

    ET.fromstring(text)

    tmp = FEATURES.with_suffix(
        FEATURES.suffix + ".bua-nextendo.tmp"
    )
    tmp.write_text(text, encoding="utf-8")
    tmp.replace(FEATURES)

    return True


def patch_generator():
    if not GENERATOR.is_file():
        print("[Nextendo] Switch generator not installed; skipping.")
        return False

    text = GENERATOR.read_text(encoding="utf-8")

    if "system.isOptSet('nextendo_network')" in text:
        print("[Nextendo] Citron generator support already present.")
        return False

    anchor = '''\
    # controls section
        if not yuzuConfig.has_section("Controls"):'''

    addition = '''\
    # NexTendo network redirection - Citron only
        if emulator == "citron-emu":
            if not yuzuConfig.has_section("Network"):
                yuzuConfig.add_section("Network")

            if system.isOptSet('nextendo_network'):
                yuzuConfig.set(
                    "Network",
                    "enable_nextendo",
                    system.config["nextendo_network"]
                )
                yuzuConfig.set(
                    "Network",
                    "enable_nextendo\\\\default",
                    "false"
                )

'''

    if anchor not in text:
        raise RuntimeError("Switch generator insertion anchor not found")

    new_text = text.replace(
        anchor,
        addition + anchor,
        1,
    )

    tmp = GENERATOR.with_suffix(GENERATOR.suffix + ".bua-nextendo.tmp")
    tmp.write_text(new_text, encoding="utf-8")

    py_compile.compile(str(tmp), doraise=True)

    tmp.replace(GENERATOR)

    print("[Nextendo] Added Citron generator support.")
    return True



def patch_ryujinx_generator():
    generator = Path(
        "/userdata/system/switch/configgen/generators/"
        "ryujinxGenerator.py"
    )

    if not generator.is_file():
        print(
            "[Nextendo] Ryujinx generator not installed; skipping."
        )
        return False

    source = generator.read_text(encoding="utf-8")

    marker = "BUA Ryujinx-Nextendo integration"

    if marker in source:
        print(
            "[Nextendo] Ryujinx generator support already present."
        )
        return False

    if not re.search(r'^import tarfile$', source, re.M):
        imports = list(
            re.finditer(r'^import .+$', source, re.M)
        )

        if not imports:
            raise RuntimeError(
                "Ryujinx generator import section not found"
            )

        pos = imports[-1].end()

        source = (
            source[:pos]
            + "\nimport tarfile"
            + source[pos:]
        )

    old_paths = '''        ryujinx_appimage = "/userdata/system/switch/appimages/ryujinx-emu.AppImage"
        ryujinx_extracted = "/userdata/system/switch/appimages/ryujinx-extracted/usr/bin/Ryujinx"
        ryujinx_extracted_dir = "/userdata/system/switch/appimages/ryujinx-extracted"
        ryujinx_wrapper = "/userdata/system/switch/extra/ryu_wrapper"
        ryujinx_libs = "/userdata/system/switch/appimages/ryujinx-extracted/usr/lib"
'''

    new_paths = '''        # BUA Ryujinx-Nextendo integration
        ryujinx_appimage = "/userdata/system/switch/appimages/ryujinx-emu.AppImage"
        ryujinx_nextendo_archive = "/userdata/system/switch/appimages/ryujinx-nextendo.tar.gz"
        ryujinx_extracted_dir = "/userdata/system/switch/appimages/ryujinx-extracted"
        ryujinx_wrapper = "/userdata/system/switch/extra/ryu_wrapper"

        # Deploy updater-managed Ryujinx-Nextendo archive.
        if os.path.isfile(ryujinx_nextendo_archive):
            staging_dir = ryujinx_extracted_dir + ".nextendo-new"
            backup_dir = ryujinx_extracted_dir + ".nextendo-old"

            if os.path.exists(staging_dir):
                shutil.rmtree(staging_dir)

            if os.path.exists(backup_dir):
                shutil.rmtree(backup_dir)

            os.makedirs(staging_dir, exist_ok=True)

            old_moved = False

            try:
                with tarfile.open(
                    ryujinx_nextendo_archive,
                    "r:gz",
                ) as archive:
                    archive.extractall(staging_dir)

                publish_dir = os.path.join(
                    staging_dir,
                    "publish",
                )

                nextendo_binary = os.path.join(
                    publish_dir,
                    "Ryujinx",
                )

                if not os.path.isfile(nextendo_binary):
                    raise RuntimeError(
                        "Ryujinx-Nextendo archive missing "
                        "publish/Ryujinx"
                    )

                st = os.stat(nextendo_binary)
                os.chmod(
                    nextendo_binary,
                    st.st_mode | stat.S_IEXEC,
                )

                # Keep Ryujinx-Nextendo in portable mode while routing
                # portable state into Batocera's persistent Ryujinx tree.
                batocera_ryujinx_config = (
                    "/userdata/system/configs/Ryujinx"
                )

                system_dir = os.path.join(
                    batocera_ryujinx_config,
                    "system",
                )

                os.makedirs(system_dir, exist_ok=True)

                portable_dir = os.path.join(
                    publish_dir,
                    "portable",
                )

                if os.path.lexists(portable_dir):
                    if (
                        os.path.isdir(portable_dir)
                        and not os.path.islink(portable_dir)
                    ):
                        shutil.rmtree(portable_dir)
                    else:
                        os.unlink(portable_dir)

                os.symlink(
                    batocera_ryujinx_config,
                    portable_dir,
                )

                shared_keys = (
                    (
                        "prod.keys",
                        "/userdata/bios/switch/keys/prod.keys",
                    ),
                    (
                        "title.keys",
                        "/userdata/bios/switch/keys/title.keys",
                    ),
                )

                for key_name, shared_key in shared_keys:
                    if not os.path.isfile(shared_key):
                        continue

                    destination = os.path.join(
                        system_dir,
                        key_name,
                    )

                    if os.path.lexists(destination):
                        if os.path.isdir(destination):
                            shutil.rmtree(destination)
                        else:
                            os.unlink(destination)

                    os.symlink(
                        shared_key,
                        destination,
                    )

                if os.path.exists(ryujinx_extracted_dir):
                    os.rename(
                        ryujinx_extracted_dir,
                        backup_dir,
                    )
                    old_moved = True

                os.rename(
                    publish_dir,
                    ryujinx_extracted_dir,
                )

                if os.path.exists(staging_dir):
                    shutil.rmtree(staging_dir)

                os.remove(ryujinx_nextendo_archive)

                if os.path.isfile(ryujinx_appimage):
                    os.remove(ryujinx_appimage)

                if os.path.exists(backup_dir):
                    shutil.rmtree(backup_dir)

                writelog(
                    "Ryujinx-Nextendo archive deployed successfully"
                )

            except Exception:
                if os.path.exists(ryujinx_extracted_dir):
                    shutil.rmtree(ryujinx_extracted_dir)

                if old_moved and os.path.exists(backup_dir):
                    os.rename(
                        backup_dir,
                        ryujinx_extracted_dir,
                    )

                if os.path.exists(staging_dir):
                    shutil.rmtree(staging_dir)

                raise
'''

    if old_paths not in source:
        raise RuntimeError(
            "Ryujinx generator path block not found"
        )

    source = source.replace(
        old_paths,
        new_paths,
        1,
    )

    old_if = '''        if os.path.exists(ryujinx_appimage):
'''

    new_if = '''        if (
            os.path.exists(ryujinx_appimage)
            and not os.path.isfile(
                os.path.join(
                    ryujinx_extracted_dir,
                    "Ryujinx",
                )
            )
        ):
'''

    if old_if not in source:
        raise RuntimeError(
            "Ryujinx AppImage extraction condition not found"
        )

    source = source.replace(
        old_if,
        new_if,
        1,
    )

    stat_anchor = '''        st = os.stat(ryujinx_extracted)
'''

    layout_block = '''        nextendo_binary = os.path.join(
            ryujinx_extracted_dir,
            "Ryujinx",
        )

        legacy_binary = os.path.join(
            ryujinx_extracted_dir,
            "usr",
            "bin",
            "Ryujinx",
        )

        if os.path.isfile(nextendo_binary):
            ryujinx_extracted = nextendo_binary
            ryujinx_libs = ryujinx_extracted_dir
        else:
            ryujinx_extracted = legacy_binary
            ryujinx_libs = os.path.join(
                ryujinx_extracted_dir,
                "usr",
                "lib",
            )

        st = os.stat(ryujinx_extracted)
'''

    if stat_anchor not in source:
        raise RuntimeError(
            "Ryujinx executable stat anchor not found"
        )

    source = source.replace(
        stat_anchor,
        layout_block,
        1,
    )

    old_ld = '''                        "LD_LIBRARY_PATH": "/userdata/system/switch/appimages/ryujinx-extracted/usr/lib",
'''

    new_ld = '''                        "LD_LIBRARY_PATH": ryujinx_libs,
                        "PATH": (
                            "/userdata/system/switch/extra/xdgfix:"
                            + os.environ.get("PATH", "")
                        ),
                        "BROWSER": (
                            "/userdata/system/switch/extra/xdgfix/xdg-open"
                        ),
                        "DEFAULT_BROWSER": (
                            "/userdata/system/switch/extra/xdgfix/xdg-open"
                        ),
'''

    if old_ld not in source:
        raise RuntimeError(
            "Ryujinx LD_LIBRARY_PATH anchor not found"
        )

    source = source.replace(
        old_ld,
        new_ld,
        1,
    )

    rom_anchor = '''        rom_nameq = os.path.basename(rom)
'''

    network_block = '''        nextendo_enabled = (
            system.isOptSet('nextendo_network')
            and str(
                system.config["nextendo_network"]
            ).lower() in (
                "1",
                "true",
                "yes",
                "on",
            )
        )

        if nextendo_enabled:
            environment["NEXTENDO_SERVER_IP"] = "51.178.29.194"
            environment["NEXTENDO_NAT_IP"] = "164.132.111.120"
        else:
            environment.pop("NEXTENDO_SERVER_IP", None)
            environment.pop("NEXTENDO_NAT_IP", None)

        rom_nameq = os.path.basename(rom)
'''

    if rom_anchor not in source:
        raise RuntimeError(
            "Ryujinx ROM anchor not found"
        )

    source = source.replace(
        rom_anchor,
        network_block,
        1,
    )

    tmp = generator.with_suffix(
        generator.suffix + ".bua-nextendo.tmp"
    )

    tmp.write_text(source, encoding="utf-8")

    py_compile.compile(
        str(tmp),
        doraise=True,
    )

    tmp.replace(generator)

    print(
        "[Nextendo] Added Ryujinx-Nextendo generator support."
    )

    return True

def patch_browser_handoff():
    if not XDG_OPEN.parent.is_dir():
        print(
            "[Nextendo] Switch xdgfix directory not installed; "
            "skipping browser handoff."
        )
        return False

    packaged_selector = Path(__file__).with_name(
        "nextendo-browser-select.py"
    )

    if not packaged_selector.is_file():
        print(
            "[Nextendo] Browser selector helper missing; "
            "skipping browser handoff."
        )
        return False

    selector = XDG_OPEN.parent / "nextendo-browser-select.py"

    selector_text = packaged_selector.read_text(
        encoding="utf-8"
    )

    selector_changed = True

    if selector.is_file():
        current_selector = selector.read_text(
            encoding="utf-8",
            errors="ignore",
        )

        if current_selector == selector_text:
            selector_changed = False

    if selector_changed:
        tmp_selector = selector.with_name(
            "nextendo-browser-select.py.bua-nextendo.tmp"
        )

        tmp_selector.write_text(
            selector_text,
            encoding="utf-8",
        )

        os.chmod(tmp_selector, 0o755)
        tmp_selector.replace(selector)
        os.chmod(selector, 0o755)

    desired = '''#!/bin/sh

# Preserve an inherited graphical session when available.
DISPLAY="${DISPLAY:-:0}"
export DISPLAY

# Prefer inherited XAUTHORITY when valid, otherwise try
# Batocera's common persistent/root Xauthority locations.
if [ -z "$XAUTHORITY" ] || [ ! -e "$XAUTHORITY" ]; then
    if [ -e /userdata/system/.Xauthority ]; then
        XAUTHORITY=/userdata/system/.Xauthority
    elif [ -e /.Xauthority ]; then
        XAUTHORITY=/.Xauthority
    fi
fi
export XAUTHORITY

# Preserve an inherited runtime directory when valid.
# Otherwise use Batocera's common runtime locations.
if [ -z "$XDG_RUNTIME_DIR" ] || [ ! -d "$XDG_RUNTIME_DIR" ]; then
    if [ -d /run/user/1000 ]; then
        XDG_RUNTIME_DIR=/run/user/1000
    elif [ -d /var/run ]; then
        XDG_RUNTIME_DIR=/var/run
    fi
fi
export XDG_RUNTIME_DIR

TARGET="$1"
SELECTOR="/userdata/system/switch/extra/xdgfix/nextendo-browser-select.py"

case "$TARGET" in
    http://*|https://*)
        env -u LD_LIBRARY_PATH \\
            -u DOTNET_ROOT \\
            -u DOTNET_BUNDLE_EXTRACT_BASE_DIR \\
            DISPLAY="$DISPLAY" \\
            XAUTHORITY="$XAUTHORITY" \\
            XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \\
            PATH="/sbin:/usr/sbin:/bin:/usr/bin" \\
            python3 "$SELECTOR" "$TARGET" \\
            >/tmp/nextendo-browser-selector.log 2>&1 &
        exit 0
        ;;
    *)
        exec pcmanfm "$@"
        ;;
esac
'''

    current = ""

    if XDG_OPEN.is_file():
        current = XDG_OPEN.read_text(
            encoding="utf-8",
            errors="ignore",
        )

    wrapper_changed = current != desired

    if wrapper_changed:
        if XDG_OPEN.is_file():
            backup = XDG_OPEN.with_name(
                "xdg-open.before-nextendo"
            )

            if not backup.exists():
                backup.write_text(
                    current,
                    encoding="utf-8",
                )
                os.chmod(backup, 0o755)

        tmp = XDG_OPEN.with_name(
            "xdg-open.bua-nextendo.tmp"
        )

        tmp.write_text(
            desired,
            encoding="utf-8",
        )

        os.chmod(tmp, 0o755)
        tmp.replace(XDG_OPEN)
        os.chmod(XDG_OPEN, 0o755)

    if not selector_changed and not wrapper_changed:
        print(
            "[Nextendo] OAuth browser selector already configured."
        )
        return False

    print(
        "[Nextendo] Configured OAuth browser selection support."
    )
    return True



def patch_switchlauncher_config():
    path = Path(
        "/userdata/system/switch/configgen/switchlauncher.py"
    )

    if not path.exists():
        print(
            "[Nextendo] Switch launcher not installed; "
            "skipping config-loader patch."
        )
        return

    text = path.read_text(encoding="utf-8")

    # Accept both the final public marker and the manual version
    # installed during development/testing.
    if (
        "# BUA preserve Batocera game overrides" in text
        or "original_data = _load_system_config(system_name)" in text
    ):
        print(
            "[Nextendo] Switch launcher config-loader support "
            "already present."
        )
        return

    old = '''    if "options" in defaults:
        _dict_merge(data, defaults["options"])

    return data
'''

    new = '''    if "options" in defaults:
        _dict_merge(data, defaults["options"])

    # BUA preserve Batocera game overrides
    # _load_system_config was imported before this module replaces
    # configgen.Emulator._load_system_config below, so this calls
    # Batocera's original configuration loader.
    original_data = _load_system_config(system_name)

    if original_data:
        _dict_merge(data, original_data)

    return data
'''

    if old not in text:
        raise RuntimeError(
            "Switch launcher config-return anchor not found"
        )

    patched = text.replace(old, new, 1)

    # Validate the complete modified source before replacing live file.
    compile(
        patched,
        str(path),
        "exec",
    )

    tmp = path.with_name(
        path.name + ".bua-nextendo.tmp"
    )

    tmp.write_text(
        patched,
        encoding="utf-8",
    )

    tmp.replace(path)

    print(
        "[Nextendo] Added Switch launcher game-option support."
    )

def main():
    print("[Nextendo] Checking Switch/Citron/Ryujinx integration...")

    steps = [
        ("Advanced Game Settings", patch_features),
        ("Citron generator", patch_generator),
        ("Ryujinx generator", patch_ryujinx_generator),
        ("Switch launcher config", patch_switchlauncher_config),
        ("OAuth browser selector", patch_browser_handoff),
    ]

    failures = []

    for label, func in steps:
        try:
            func()
        except Exception as exc:
            failures.append((label, exc))
            print(
                f"[Nextendo] WARNING: {label} integration failed: "
                f"{type(exc).__name__}: {exc}"
            )

    if failures:
        print(
            "[Nextendo] Integration check completed with "
            f"{len(failures)} warning(s)."
        )
    else:
        print("[Nextendo] Integration check complete.")
if __name__ == "__main__":
    main()
