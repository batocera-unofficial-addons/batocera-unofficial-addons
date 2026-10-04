#!/usr/bin/env python3

import hashlib
import json
import platform
import re
import subprocess
import urllib.request
from pathlib import Path


def supports_x86_64_v3():
    """Return True when this Linux CPU can safely run x86-64-v3 binaries."""

    try:
        cpuinfo = Path("/proc/cpuinfo").read_text(
            encoding="utf-8",
            errors="ignore",
        ).lower()
    except Exception:
        return False

    flags = set()

    for line in cpuinfo.splitlines():
        if line.startswith("flags") and ":" in line:
            flags.update(
                line.split(":", 1)[1].strip().split()
            )

    required = {
        "avx",
        "avx2",
        "bmi1",
        "bmi2",
        "f16c",
        "fma",
        "movbe",
        "xsave",
    }

    if not required.issubset(flags):
        return False

    # Linux commonly reports LZCNT support as ABM on AMD.
    if "lzcnt" not in flags and "abm" not in flags:
        return False

    return True


def get_bytes(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "BUA-Updater",
            "Cache-Control": "no-cache",
        },
    )

    with urllib.request.urlopen(
        req,
        timeout=25,
    ) as response:
        return response.read()


result = subprocess.run(
    ["batocera-es-swissknife", "--version"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    timeout=10,
)

m = re.search(
    r"^([0-9]+)",
    result.stdout.strip(),
)

if not m:
    raise SystemExit(
        "Unable to determine Batocera major version"
    )

major = int(m.group(1))

machine = platform.machine().lower()

if machine in ("x86_64", "amd64"):
    arch = "x86_64"
elif machine in ("aarch64", "arm64"):
    arch = "aarch64"
else:
    arch = machine or "unknown"

if major not in (42, 43, 44):
    raise SystemExit(
        f"Component identity not supported for Batocera {major}"
    )


components = []


# ============================================================
# Citron
# ============================================================

citron_version = None

if arch in ("x86_64", "aarch64"):
    citron_data = json.loads(
        get_bytes(
            "https://api.github.com/repos/"
            "NextendoNetwork/citron-nextendo/releases/tags/nightly-linux"
        ).decode("utf-8")
    )

    citron_asset = None
    citron_commit = None

    assets = citron_data.get("assets", [])

    if arch == "x86_64":
        # Prefer broad compatibility. Only consider the v3 build
        # when this CPU actually supports x86-64-v3.
        preferred_suffixes = [
            "-linux-x86_64.AppImage",
            "-linux-x86_64_v2.AppImage",
        ]

        if supports_x86_64_v3():
            preferred_suffixes.append(
                "-linux-x86_64_v3.AppImage"
            )
    else:
        preferred_suffixes = (
            "-linux-aarch64.AppImage",
            "-linux-aarch64-use-nopgo.AppImage",
        )

    for suffix in preferred_suffixes:
        for asset in assets:
            name = str(asset.get("name") or "")
            url = str(asset.get("browser_download_url") or "")

            if name.endswith(suffix) and url:
                citron_asset = url

                m = re.search(
                    r"citron_nightly-([0-9a-f]+)-",
                    name,
                )

                if m:
                    citron_commit = m.group(1)

                break

        if citron_asset:
            break

    if citron_asset:
        citron_version = (
            "nightly-" + citron_commit
            if citron_commit
            else str(citron_data.get("tag_name") or "nightly-linux")
        )

        components.append({
            "name": "Citron",
            "version": citron_version,
            "url": citron_asset,
            "target": (
                "/userdata/system/switch/appimages/"
                "citron-emu.AppImage"
            ),
        })


# ============================================================
# Ryujinx-Nextendo
# ============================================================

ryujinx_version = None

if arch == "x86_64":
    ryujinx_data = json.loads(
        get_bytes(
            "https://api.github.com/repos/"
            "NextendoNetwork/Ryujinx-Nextendo/releases/latest"
        ).decode("utf-8")
    )

    ryujinx_version = str(
        ryujinx_data.get("tag_name") or ""
    ).strip()

    if not ryujinx_version:
        raise SystemExit(
            "Unable to resolve Ryujinx-Nextendo"
        )

    ryujinx_asset = None

    for asset in ryujinx_data.get("assets", []):
        name = str(asset.get("name") or "")
        url = str(asset.get("browser_download_url") or "")

        if (
            name.startswith("Nextendo-")
            and name.endswith("-linux-x64.tar.gz")
            and url
        ):
            ryujinx_asset = url
            break

    if not ryujinx_asset:
        raise SystemExit(
            "Unable to resolve Ryujinx-Nextendo Linux x64 archive"
        )

    components.append({
        "name": "Ryujinx-Nextendo",
        "version": ryujinx_version,
        "url": ryujinx_asset,
        "target": (
            "/userdata/system/switch/appimages/"
            "ryujinx-nextendo.tar.gz"
        ),
        "type": "replace_file",
        "executable": False,
    })


if arch == "x86_64":
    # ============================================================
    # Eden stable + PGO
    # ============================================================

    eden_data = json.loads(
        get_bytes(
            "https://stable.eden-emu.dev/latest/release.json"
        ).decode("utf-8")
    )

    eden_version = str(
        eden_data.get("tag_name") or ""
    ).strip()

    eden_base = str(
        eden_data.get("base")
        or "https://stable.eden-emu.dev"
    ).rstrip("/")

    if not eden_version:
        raise SystemExit("Unable to resolve Eden")

    eden_url = (
        f"{eden_base}/{eden_version}/"
        f"Eden-Linux-{eden_version}-"
        "amd64-gcc-standard.AppImage"
    )

    eden_pgo_url = (
        f"{eden_base}/{eden_version}/"
        f"Eden-Linux-{eden_version}-"
        "amd64-clang-pgo.AppImage"
    )

    components.append({
        "name": "Eden",
        "version": eden_version,
        "url": eden_url,
        "target": (
            "/userdata/system/switch/appimages/"
            "eden-emu.AppImage"
        ),
    })

    components.append({
        "name": "Eden PGO",
        "version": eden_version,
        "url": eden_pgo_url,
        "target": (
            "/userdata/system/switch/appimages/"
            "eden-pgo.AppImage"
        ),
    })


    # ============================================================
    # Eden Nightly
    # ============================================================

    nightly_data = json.loads(
        get_bytes(
            "https://nightly.eden-emu.dev/latest/release.json"
        ).decode("utf-8")
    )

    nightly_version = str(
        nightly_data.get("tag_name") or ""
    ).strip()

    nightly_base = str(
        nightly_data.get("base")
        or "https://nightly.eden-emu.dev"
    ).rstrip("/")

    if (
        not nightly_version
        or "." not in nightly_version
    ):
        raise SystemExit("Unable to resolve Eden Nightly")

    nightly_short = nightly_version.split(".", 1)[1]

    nightly_url = (
        f"{nightly_base}/{nightly_version}/"
        f"Eden-Linux-{nightly_short}-"
        "amd64-gcc-standard.AppImage"
    )

    components.append({
        "name": "Eden Nightly",
        "version": nightly_version,
        "url": nightly_url,
        "target": (
            "/userdata/system/switch/appimages/"
            "eden-nightly.AppImage"
        ),
    })



# ============================================================
# Composite identity
# ============================================================

identity_payload = {
    "batocera_major": major,
    "architecture": arch,
    "components": components,
}

serialized = json.dumps(
    identity_payload,
    sort_keys=True,
    separators=(",", ":"),
).encode("utf-8")

digest = hashlib.sha256(
    serialized
).hexdigest()

display_parts = []

for component in components:
    display_parts.append(
        f"{component['name']} {component['version']}"
    )

if display_parts:
    display_version = "; ".join(display_parts)
else:
    display_version = (
        f"Switch components unavailable for {arch}"
    )

print(display_version)
print(
    "switch:"
    + str(major)
    + ":components:"
    + digest
)
print("multi_parent")
print("switch-components")
print(json.dumps(
    components,
    separators=(",", ":"),
))
