#!/usr/bin/env python3

from pathlib import Path
import os
import re
import py_compile
import subprocess
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

    nextendo_addition = """\
    <feature name="NEXTENDO NETWORK" group="SWITCH OPTIONS" submenu="NETWORK" value="nextendo_network" description="Enable NexTendo network redirection for supported games.">
      <choice name="Disabled" value="false" />
      <choice name="Enabled" value="true" />
    </feature>"""

    internet_addition = """\
    <feature name="INTERNET ACCESS" group="SWITCH OPTIONS" submenu="NETWORK" value="internet_access" description="Allow the emulator to report an active internet connection to the game.">
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

        missing_features = []

        if 'value="nextendo_network"' not in block:
            missing_features.append(nextendo_addition)

        if 'value="internet_access"' not in block:
            missing_features.append(internet_addition)

        # Keep INTERNET ACCESS directly below NEXTENDO NETWORK.
        reversed_pair = (
            internet_addition + "\n" + nextendo_addition
        )

        correct_pair = (
            nextendo_addition + "\n" + internet_addition
        )

        if reversed_pair in block:
            block = block.replace(
                reversed_pair,
                correct_pair,
                1,
            )

            text = text[:start] + block + text[end:]
            changed = True

            print(
                f"[Nextendo] Reordered {emulator_name} "
                "Network settings."
            )
            continue

        if not missing_features:
            print(
                f"[Nextendo] {emulator_name} Advanced Game "
                "Settings features already present."
            )
            continue

        if anchor not in block:
            raise RuntimeError(
                f"{emulator_name} insertion anchor not found"
            )

        block = block.replace(
            anchor,
            anchor + "\n" + "\n".join(missing_features),
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

    nextendo_marker = "system.isOptSet('nextendo_network')"
    internet_marker = "BUA Citron internet-access integration"

    nextendo_integrated = nextendo_marker in text
    internet_integrated = internet_marker in text

    changed = False

    if nextendo_integrated:
        print("[Nextendo] Citron generator support already present.")

    if not nextendo_integrated:
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

        text = new_text
        changed = True

    if not internet_integrated:
        internet_anchor = """            if system.isOptSet('nextendo_network'):
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
"""

        internet_replacement = """            if system.isOptSet('nextendo_network'):
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

            # BUA Citron internet-access integration
            if system.isOptSet('internet_access'):
                internet_enabled = str(
                    system.config["internet_access"]
                ).lower() in (
                    "1",
                    "true",
                    "yes",
                    "on",
                )
            else:
                internet_enabled = (
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

            for section in ("Network", "Services"):
                if not yuzuConfig.has_section(section):
                    yuzuConfig.add_section(section)

                yuzuConfig.set(
                    section,
                    "airplane_mode",
                    "false" if internet_enabled else "true"
                )
                yuzuConfig.set(
                    section,
                    "airplane_mode\\\\default",
                    "false"
                )
"""

        if internet_anchor not in text:
            raise RuntimeError(
                "Citron internet-access anchor not found"
            )

        text = text.replace(
            internet_anchor,
            internet_replacement,
            1,
        )

        changed = True

    if not changed:
        return False

    tmp = GENERATOR.with_suffix(GENERATOR.suffix + ".bua-nextendo.tmp")
    tmp.write_text(text, encoding="utf-8")

    py_compile.compile(str(tmp), doraise=True)

    tmp.replace(GENERATOR)

    print("[Nextendo] Updated Citron generator support.")
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
    internet_marker = "BUA Ryujinx internet-access integration"

    already_integrated = marker in source
    internet_integrated = internet_marker in source

    changed = False

    if already_integrated:
        print(
            "[Nextendo] Ryujinx generator support already present."
        )

    safe_deployment = '        # Deploy updater-managed Ryujinx-Nextendo archive.\n        # BUA_NEXTENDO_SAFE_DEPLOY_V3\n        if os.path.isfile(ryujinx_nextendo_archive):\n            import hashlib\n            import uuid\n            import tempfile\n            from pathlib import PurePosixPath\n\n            backup_dir = ryujinx_extracted_dir + ".nextendo-old"\n            parent_dir = os.path.dirname(ryujinx_extracted_dir)\n            config_dir = "/userdata/system/configs/Ryujinx"\n\n            def valid_install(directory, require_portable=False):\n                binary = os.path.join(directory, "Ryujinx")\n                legacy_binary = os.path.join(directory, "usr", "lib", "Ryujinx")\n                portable = os.path.join(directory, "portable")\n                return (os.path.isdir(directory)\n                        and not os.path.islink(directory)\n                        and ((os.path.isfile(binary) and not os.path.islink(binary))\n                             or (os.path.isfile(legacy_binary) and not os.path.islink(legacy_binary)))\n                        and ((os.path.islink(portable) and os.readlink(portable) == config_dir)\n                             or (not require_portable and not os.path.lexists(portable))))\n\n            # A crash between renaming the old directory and publishing the\n            # new one must never leave the emulator missing.\n            if os.path.lexists(backup_dir):\n                if os.path.islink(backup_dir) or not valid_install(backup_dir):\n                    raise RuntimeError("Unsafe or incomplete Nextendo recovery backup")\n                if not os.path.lexists(ryujinx_extracted_dir):\n                    os.rename(backup_dir, ryujinx_extracted_dir)\n                    writelog("Recovered previous authenticated-layout Ryujinx installation")\n                elif not valid_install(ryujinx_extracted_dir):\n                    raise RuntimeError("Ambiguous Ryujinx recovery state; retained both directories")\n\n            # Existing backups are archived, never discarded or overwritten.\n            # If a restart occurs during this rename, the active installation\n            # is still present and the historical backup remains recoverable.\n            if os.path.lexists(backup_dir):\n                history = backup_dir + ".history-" + uuid.uuid4().hex\n                os.rename(backup_dir, history)\n\n            if os.path.lexists(ryujinx_extracted_dir):\n                if os.path.islink(ryujinx_extracted_dir) or not valid_install(ryujinx_extracted_dir):\n                    raise RuntimeError("Existing Ryujinx installation failed safety checks")\n\n            staging_dir = tempfile.mkdtemp(prefix=".nextendo-stage-", dir=parent_dir)\n            old_moved = False\n            new_activated = False\n            try:\n                extracted = os.path.join(staging_dir, "publish")\n                os.mkdir(extracted)\n                count = 0\n                total = 0\n                seen = set()\n                with tarfile.open(ryujinx_nextendo_archive, "r:gz") as archive:\n                    for member in archive:\n                        pieces = tuple(p for p in PurePosixPath(member.name).parts if p not in ("", "."))\n                        if not pieces:\n                            if member.isdir():\n                                continue\n                            raise RuntimeError("Invalid Nextendo archive root")\n                        if (member.name.startswith("/") or ".." in pieces\n                                or pieces[0] != "publish"\n                                or not (member.isfile() or member.isdir())):\n                            raise RuntimeError("Unsafe Nextendo archive entry: " + member.name)\n                        if pieces in seen:\n                            raise RuntimeError("Duplicate Nextendo archive entry")\n                        seen.add(pieces)\n                        count += 1\n                        total += member.size\n                        if count > 4000 or total > 1024 * 1024 * 1024:\n                            raise RuntimeError("Nextendo archive size or entry limit exceeded")\n                        destination = os.path.join(staging_dir, *pieces)\n                        if member.isdir():\n                            os.makedirs(destination, exist_ok=True)\n                        else:\n                            os.makedirs(os.path.dirname(destination), exist_ok=True)\n                            stream = archive.extractfile(member)\n                            if stream is None:\n                                raise RuntimeError("Unreadable Nextendo archive member")\n                            with stream, open(destination, "xb") as target_file:\n                                shutil.copyfileobj(stream, target_file)\n\n                binary = os.path.join(extracted, "Ryujinx")\n                if not os.path.isfile(binary) or os.path.islink(binary):\n                    raise RuntimeError("Nextendo archive missing regular publish/Ryujinx")\n                if os.stat(binary).st_size < 1024:\n                    raise RuntimeError("Nextendo executable is unexpectedly small")\n                os.chmod(binary, os.stat(binary).st_mode | stat.S_IXUSR)\n\n                portable = os.path.join(extracted, "portable")\n                if os.path.lexists(portable):\n                    # Official releases ship publish/portable/.keep. Accept\n                    # only that empty placeholder; never erase user state.\n                    if os.path.islink(portable) or not os.path.isdir(portable):\n                        raise RuntimeError("Unsafe Nextendo portable entry")\n                    contents = os.listdir(portable)\n                    if any(name != ".keep" for name in contents):\n                        raise RuntimeError("Unexpected Nextendo portable data")\n                    placeholder = os.path.join(portable, ".keep")\n                    if os.path.lexists(placeholder):\n                        if os.path.islink(placeholder) or not os.path.isfile(placeholder) or os.stat(placeholder).st_size != 0:\n                            raise RuntimeError("Unsafe Nextendo portable placeholder")\n                        os.unlink(placeholder)\n                    os.rmdir(portable)\n                os.symlink(config_dir, portable)\n                if not valid_install(extracted, require_portable=True):\n                    raise RuntimeError("Staged Nextendo installation failed layout validation")\n\n                if os.path.lexists(ryujinx_extracted_dir):\n                    os.rename(ryujinx_extracted_dir, backup_dir)\n                    old_moved = True\n                os.rename(extracted, ryujinx_extracted_dir)\n                new_activated = True\n                if not valid_install(ryujinx_extracted_dir, require_portable=True):\n                    raise RuntimeError("Activated Nextendo installation failed validation")\n\n                # Retain rollback directory and downloaded archive until the\n                # new executable has passed layout validation. Do not delete\n                # Batocera configuration, keys, saves or AppImage fallbacks.\n                os.unlink(ryujinx_nextendo_archive)\n                writelog("Ryujinx-Nextendo installed; previous binaries retained for recovery")\n            except Exception:\n                if old_moved:\n                    if new_activated and os.path.isdir(ryujinx_extracted_dir):\n                        failed = ryujinx_extracted_dir + ".failed-" + uuid.uuid4().hex\n                        os.rename(ryujinx_extracted_dir, failed)\n                    if not os.path.lexists(ryujinx_extracted_dir) and os.path.isdir(backup_dir):\n                        os.rename(backup_dir, ryujinx_extracted_dir)\n                raise\n            finally:\n                # Only our unique temporary directory can be removed.\n                if os.path.isdir(staging_dir) and not os.path.islink(staging_dir):\n                    shutil.rmtree(staging_dir)\n\n'

    if not already_integrated:
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

''' + safe_deployment

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

        changed = True

    if already_integrated and "BUA_NEXTENDO_SAFE_DEPLOY_V3" not in source:
        old_deploy_start = "        # Deploy updater-managed Ryujinx-Nextendo archive.\n"
        old_deploy_end = "        # Si un AppImage est présent, l'extraire automatiquement\n"
        if source.count(old_deploy_start) != 1 or source.count(old_deploy_end) != 1:
            raise RuntimeError("Existing Ryujinx deployment anchors not unique")
        begin = source.index(old_deploy_start)
        finish = source.index(old_deploy_end, begin)
        source = source[:begin] + safe_deployment + source[finish:]
        changed = True

    if not internet_integrated:
        config_anchor = """        if system.isOptSet('res_scale'):
            data['res_scale'] = int(system.config["res_scale"])
        else:
            data['res_scale'] = 1
"""

        config_block = """        if system.isOptSet('res_scale'):
            data['res_scale'] = int(system.config["res_scale"])
        else:
            data['res_scale'] = 1

        # BUA Ryujinx internet-access integration
        if system.isOptSet('internet_access'):
            data['enable_internet_access'] = str(
                system.config["internet_access"]
            ).lower() in (
                "1",
                "true",
                "yes",
                "on",
            )
        else:
            data['enable_internet_access'] = (
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
"""

        if config_anchor not in source:
            raise RuntimeError(
                "Ryujinx internet-access config anchor not found"
            )

        source = source.replace(
            config_anchor,
            config_block,
            1,
        )

        changed = True

    if not changed:
        return False

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
        "[Nextendo] Updated Ryujinx-Nextendo generator support."
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


def apply_local_ryujinx_persistence():
    """Reapply locally validated Ryujinx controller/hotkey fixes."""
    repair = Path(
        "/userdata/system/restore-ryujinx-nextendo-fixes.sh"
    )

    if not repair.is_file():
        print(
            "[Nextendo] Local Ryujinx persistence script "
            "not installed; skipping."
        )
        return False

    subprocess.run(
        [str(repair)],
        check=True,
    )

    print(
        "[Nextendo] Reapplied local Ryujinx controller/hotkey fixes."
    )

    return True

def patch_switch_motion():
    packaged = Path(__file__).with_name(
        "switch-motion-restore.sh"
    )

    target = Path(
        "/userdata/system/restore-switch-motion.sh"
    )

    if not packaged.is_file():
        raise RuntimeError(
            "Packaged Switch motion restore script is missing"
        )

    packaged_data = packaged.read_bytes()

    deploy_needed = (
        not target.is_file()
        or target.read_bytes() != packaged_data
    )

    if deploy_needed:
        tmp = target.with_name(
            target.name + ".bua-motion.tmp"
        )

        tmp.write_bytes(packaged_data)
        os.chmod(tmp, 0o755)
        tmp.replace(target)

        print(
            "[Nextendo] Deployed Switch motion persistence script."
        )
    else:
        os.chmod(target, 0o755)
        print(
            "[Nextendo] Switch motion persistence script already current."
        )

    #
    # Prefer the existing Ryujinx/Nextendo boot persistence path.
    #
    restore = Path(
        "/userdata/system/restore-ryujinx-nextendo-fixes.sh"
    )

    marker = "# Switch global motion persistence"

    addition = """#
# Switch global motion persistence
#
if [ -x /userdata/system/restore-switch-motion.sh ]; then
    /userdata/system/restore-switch-motion.sh
    log "Switch motion persistence verified"
else
    log "WARNING: restore-switch-motion.sh missing"
fi

"""

    hooked = False

    if restore.is_file():
        restore_text = restore.read_text(
            encoding="utf-8"
        )

        if marker in restore_text:
            hooked = True

        else:
            anchor = 'log "Persistence check finished"'

            if anchor in restore_text:
                restore_text = restore_text.replace(
                    anchor,
                    addition + anchor,
                    1,
                )

                tmp_restore = restore.with_name(
                    restore.name + ".bua-motion.tmp"
                )

                tmp_restore.write_text(
                    restore_text,
                    encoding="utf-8",
                )

                os.chmod(tmp_restore, 0o755)

                subprocess.run(
                    ["bash", "-n", str(tmp_restore)],
                    check=True,
                )

                tmp_restore.replace(restore)
                hooked = True

                print(
                    "[Nextendo] Added Switch motion to existing "
                    "boot persistence."
                )

    #
    # Fallback for a fresh install where the Ryujinx persistence
    # mechanism is unavailable.
    #
    service = Path(
        "/userdata/system/services/SwitchMotionPersistence"
    )

    if hooked:
        if service.exists():
            try:
                subprocess.run(
                    [
                        "batocera-services",
                        "disable",
                        "SwitchMotionPersistence",
                    ],
                    check=False,
                )
            except Exception:
                pass

            service.unlink(missing_ok=True)

    else:
        service_text = """#!/bin/bash

case "$1" in
    start)
        /userdata/system/restore-switch-motion.sh
        ;;

    stop)
        ;;

    status)
        if [ -f /tmp/restore-switch-motion.log ]; then
            cat /tmp/restore-switch-motion.log
        else
            echo "Switch motion persistence has not run since boot."
        fi
        ;;

    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac

exit 0
"""

        service.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        service.write_text(
            service_text,
            encoding="utf-8",
        )

        os.chmod(service, 0o755)

        subprocess.run(
            [
                "batocera-services",
                "enable",
                "SwitchMotionPersistence",
            ],
            check=False,
        )

        print(
            "[Nextendo] Installed standalone Switch motion "
            "boot persistence."
        )

    subprocess.run(
        [str(target)],
        check=True,
    )

    print(
        "[Nextendo] Switch DSU/Cemuhook motion integration verified."
    )

    return True


def main():
    print("[Nextendo] Checking Switch/Citron/Ryujinx integration...")

    steps = [
        ("Advanced Game Settings", patch_features),
        ("Citron generator", patch_generator),
        ("Ryujinx generator", patch_ryujinx_generator),
        ("Switch launcher config", patch_switchlauncher_config),
        ("OAuth browser selector", patch_browser_handoff),
        ("Local Ryujinx persistence", apply_local_ryujinx_persistence),
        ("Switch motion", patch_switch_motion),
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
