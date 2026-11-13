#!/usr/bin/env python3

import hashlib
import json
import platform
import re
import subprocess
import urllib.error
import urllib.parse
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
# Component sources (BUA_SWITCH_SOURCES_V2)
# ============================================================
# Citron Nextendo and Ryujinx-Nextendo moved from GitHub to the
# official Nextendo Forgejo server; its release API matches GitHub's
# fields (tag_name, draft, prerelease, assets[].browser_download_url).
# Each source is resolved on its own: one unreachable source marks only
# that component unavailable instead of failing the whole Switch check.

NEXTENDO_API = "https://git.nextendo.network/api/v1/repos/NextendoNetwork"
APPIMAGES = "/userdata/system/switch/appimages/"


def _unavailable(name, target, reason):
    return {
        "name": name,
        "version": "unavailable",
        "unavailable": True,
        "error": str(reason)[:200] or "Source unavailable",
        "target": APPIMAGES + target,
    }


def _resolve(name, target, resolver):
    try:
        return resolver()
    except Exception as exc:
        if isinstance(exc, urllib.error.HTTPError):
            failed_url = getattr(exc, "filename", None) or ""
            host = urllib.parse.urlsplit(failed_url).hostname or "source"
            reason = f"HTTP {exc.code} from {host}"
        else:
            reason = str(exc) or exc.__class__.__name__
        return _unavailable(name, target, reason)


def _citron():
    data = json.loads(get_bytes(
        NEXTENDO_API + "/citron-nextendo/releases/tags/nightly-linux"
    ).decode("utf-8"))

    if arch == "x86_64":
        # Broad compatibility first; x86-64-v3 only where the CPU has it;
        # the no-PGO baseline build is the last resort.
        suffixes = ["-linux-x86_64.AppImage", "-linux-x86_64_v2.AppImage"]
        if supports_x86_64_v3():
            suffixes.append("-linux-x86_64_v3.AppImage")
        suffixes.append("-linux-x86_64-use-nopgo.AppImage")
    else:
        suffixes = ["-linux-aarch64.AppImage",
                    "-linux-aarch64-use-nopgo.AppImage"]

    assets = data.get("assets") or []
    for suffix in suffixes:
        for asset in assets:
            name = str(asset.get("name") or "")
            url = str(asset.get("browser_download_url") or "")
            match = re.fullmatch(
                r"citron_nightly-([0-9a-f]+)" + re.escape(suffix), name)
            if match and url:
                return {
                    "name": "Citron",
                    "version": "nightly-" + match.group(1),
                    "url": url,
                    "target": APPIMAGES + "citron-emu.AppImage",
                }

    raise RuntimeError("No Linux build in Citron nightly-linux release")


def _ryujinx():
    releases = json.loads(get_bytes(
        NEXTENDO_API + "/Ryujinx-Nextendo/releases?limit=50"
    ).decode("utf-8"))

    candidates = []
    for release in releases:
        if release.get("draft") or release.get("prerelease"):
            continue
        version = str(release.get("tag_name") or "").strip()
        match = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", version)
        if not match:
            continue
        for asset in release.get("assets") or []:
            name = str(asset.get("name") or "")
            url = str(asset.get("browser_download_url") or "")
            if name == "Nextendo-" + version.removeprefix("v") + "-linux-x64.tar.gz" and url:
                candidates.append((tuple(map(int, match.groups())), version, url))
                break

    if not candidates:
        raise RuntimeError("No Ryujinx-Nextendo Linux x64 release")

    _, version, url = max(candidates, key=lambda item: item[0])
    return {
        "name": "Ryujinx-Nextendo",
        "version": version,
        "url": url,
        "target": APPIMAGES + "ryujinx-nextendo.tar.gz",
        "type": "replace_file",
        "executable": False,
    }


def _eden_release(index_url, default_base):
    data = json.loads(get_bytes(index_url).decode("utf-8"))
    version = str(data.get("tag_name") or "").strip()
    base = str(data.get("base") or default_base).rstrip("/")
    if not version:
        raise RuntimeError("No version in " + index_url)
    return version, base


def _eden_stable_pair():
    version, base = _eden_release(
        "https://stable.eden-emu.dev/latest/release.json",
        "https://stable.eden-emu.dev")
    return [
        {
            "name": "Eden",
            "version": version,
            "url": f"{base}/{version}/Eden-Linux-{version}-amd64-gcc-standard.AppImage",
            "target": APPIMAGES + "eden-emu.AppImage",
        },
        {
            "name": "Eden PGO",
            "version": version,
            "url": f"{base}/{version}/Eden-Linux-{version}-amd64-clang-pgo.AppImage",
            "target": APPIMAGES + "eden-pgo.AppImage",
        },
    ]


def _eden_nightly():
    version, base = _eden_release(
        "https://nightly.eden-emu.dev/latest/release.json",
        "https://nightly.eden-emu.dev")
    if "." not in version:
        raise RuntimeError("Unrecognized Eden Nightly version")
    short = version.split(".", 1)[1]
    return {
        "name": "Eden Nightly",
        "version": version,
        "url": f"{base}/{version}/Eden-Linux-{short}-amd64-gcc-standard.AppImage",
        "target": APPIMAGES + "eden-nightly.AppImage",
    }


if arch in ("x86_64", "aarch64"):
    components.append(_resolve("Citron", "citron-emu.AppImage", _citron))

if arch == "x86_64":
    components.append(
        _resolve("Ryujinx-Nextendo", "ryujinx-nextendo.tar.gz", _ryujinx))

    stable = _resolve("Eden", "eden-emu.AppImage", _eden_stable_pair)
    if isinstance(stable, list):
        components.extend(stable)
    else:
        components.append(stable)
        components.append(
            _unavailable("Eden PGO", "eden-pgo.AppImage", stable["error"]))

    components.append(
        _resolve("Eden Nightly", "eden-nightly.AppImage", _eden_nightly))

if components and all(c.get("unavailable") for c in components):
    raise SystemExit(
        "No Switch component source reachable: "
        + "; ".join(c["name"] + ": " + c["error"] for c in components)
    )


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
