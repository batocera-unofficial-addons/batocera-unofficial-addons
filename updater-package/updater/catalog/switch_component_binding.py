#!/usr/bin/env python3
"""Validate dynamic Switch identities and verify installed components; never installs."""
import hashlib
import json
import re
import urllib.parse
from urllib.parse import urlsplit, unquote

EXPECTED = {
    "Citron": "/userdata/system/switch/appimages/citron-emu.AppImage",
    "Eden": "/userdata/system/switch/appimages/eden-emu.AppImage",
    "Eden PGO": "/userdata/system/switch/appimages/eden-pgo.AppImage",
    "Eden Nightly": "/userdata/system/switch/appimages/eden-nightly.AppImage",
    "Ryujinx-Nextendo": "/userdata/system/switch/appimages/ryujinx-nextendo.tar.gz",
}

def verify_switch_components(lines, major=42, architecture="x86_64",
                             expected_identity=None, expected_display=None):
    """Match a dynamic, locally bundled switch_identity.py result to targets.

    Accepts the five output lines; rejects opaque, mismatched or static URLs.
    Returns verified component metadata, NEVER an installation authorization.
    """
    if architecture != "x86_64" or major not in (42,43,44):
        raise ValueError("Unsupported Switch component platform")
    if not isinstance(lines, (list,tuple)) or len(lines)!=5:
        raise ValueError("Expected exactly five identity output lines")
    display,identity,source_family,recipe_family,raw_json = lines
    if source_family!="multi_parent" or recipe_family!="switch-components":
        raise ValueError("Unexpected Switch identity source family")
    if not all(isinstance(item,str) and len(item)<15000 for item in lines):
        raise ValueError("Invalid Switch identity fields")
    if len(raw_json)>12000:
        raise ValueError("Oversized Switch identity metadata")
    components=json.loads(raw_json)
    if not isinstance(components,list) or len(components)!=5:
        raise ValueError("Expected five independent Switch components")
    names=[item.get("name") if isinstance(item,dict) else None for item in components]
    if len(set(names))!=5 or set(names)!=set(EXPECTED):
        raise ValueError("Missing or duplicate Switch component")
    canonical=json.dumps({"batocera_major":major,"architecture":architecture,
                          "components":components},sort_keys=True,
                         separators=(",",":")).encode("utf-8")
    calculated="switch:"+str(major)+":components:"+hashlib.sha256(canonical).hexdigest()
    if identity!=calculated:
        raise ValueError("Switch component identity digest mismatch")
    expected_display_value="; ".join(item["name"]+" "+item["version"] for item in components)
    if display!=expected_display_value:
        raise ValueError("Switch display does not match component versions")
    if expected_identity is not None and expected_identity!=identity:
        raise ValueError("Switch identity changed since selection")
    if expected_display is not None and expected_display!=display:
        raise ValueError("Switch version changed since selection")
    checked=[]
    for item in components:
        name=item["name"]
        version=item.get("version")
        url=item.get("url")
        if item.get("unavailable"):
            # BUA_SWITCH_SOURCES_V2: this source could not be resolved.
            error=item.get("error")
            if (version!="unavailable" or url is not None
                    or item.get("target")!=EXPECTED[name]
                    or not isinstance(error,str) or not error or len(error)>200):
                raise ValueError("Invalid unavailable component entry")
            checked.append({"name":name,"version":version,"url":None,
                            "target":EXPECTED[name],"unavailable":True,
                            "error":error})
            continue
        if not isinstance(version,str) or not version or len(version)>128:
            raise ValueError("Invalid component version")
        if not isinstance(url,str) or len(url)>1000:
            raise ValueError("Missing component asset")
        if item.get("target") != EXPECTED[name]:
            raise ValueError("Unexpected component target")
        parsed=urlsplit(url)
        if parsed.scheme!="https" or parsed.username or parsed.password or parsed.port not in (None,443) or parsed.query or parsed.fragment:
            raise ValueError("Unsafe component download URL")
        path=parsed.path
        segments=[unquote(x) for x in path.split("/") if x]
        if any(x in (".","..") or "/" in x or chr(92) in x for x in segments):
            raise ValueError("Unsafe asset URL path")
        host=parsed.hostname
        if name=="Citron":
            if host!="git.nextendo.network" or not re.fullmatch(
                r"/NextendoNetwork/citron-nextendo/releases/download/nightly-linux/"
                r"citron_nightly-[0-9a-f]+-linux-x86_64(?:_v2|_v3|-use-nopgo)?[.]AppImage",path):
                raise ValueError("Citron asset not from expected release")
            commit=re.search(r"citron_nightly-([0-9a-f]+)-",path).group(1)
            if version!="nightly-"+commit:
                raise ValueError("Citron commit and version differ")
        elif name=="Ryujinx-Nextendo":
            tag=re.escape(version)
            version_without_v=re.escape(version.removeprefix("v"))
            expected=(r"/NextendoNetwork/Ryujinx-Nextendo/releases/download/"
                      +tag+r"/Nextendo-"+version_without_v+r"-linux-x64[.]tar[.]gz")
            if host!="git.nextendo.network" or not re.fullmatch(expected,path):
                raise ValueError("Ryujinx asset not from selected release")
        elif name in ("Eden","Eden PGO"):
            variant="gcc-standard" if name=="Eden" else "clang-pgo"
            expected="/"+version+"/Eden-Linux-"+version+"-amd64-"+variant+".AppImage"
            if host!="stable.eden-emu.dev" or path!=expected:
                raise ValueError("Eden stable asset mismatch")
        elif name=="Eden Nightly":
            if "." not in version:
                raise ValueError("Unrecognized Eden nightly version")
            short=version.split(".",1)[1]
            expected="/"+version+"/Eden-Linux-"+short+"-amd64-gcc-standard.AppImage"
            if host!="nightly.eden-emu.dev" or path!=expected:
                raise ValueError("Eden nightly asset mismatch")
        checked.append({"name":name,"version":version,"url":url,
                        "target":EXPECTED[name],"type":"replace_file",
                        "executable":name!="Ryujinx-Nextendo"})
    return {"identity":identity,"display_version":display,
            "components":checked,"validated":True}


# ============================================================
# Installed-component verification (BUA_SWITCH_COMPONENT_VERIFY_V1)
# ============================================================
#
# Compares each installed Switch component against the exact asset of
# the latest verified release, byte for byte. Nothing is installed or
# modified here; only the asset-hash cache file is written.

import os
import tarfile
import tempfile
import urllib.request
from pathlib import PurePosixPath

RYUJINX_EXTRACTED_DIR = "/userdata/system/switch/appimages/ryujinx-extracted"
# Outside updater/, so reinstalling the updater keeps it: a new install
# would otherwise download every Switch release again to compare.
ASSET_CACHE_FILE = ("/userdata/system/add-ons/bua/.updater-cache/"
                    "switch-component-assets.json")
MAX_ASSET_BYTES = 2 * 1024 * 1024 * 1024
MAX_ARCHIVE_MEMBERS = 4000
_CHUNK = 1024 * 1024


_LOCAL_HASHES = {}


def sha256_file(path):
    """SHA-256 of a file, memoized while its inode, size and mtime hold."""
    info = os.stat(path)
    key = (os.path.realpath(path), info.st_ino, info.st_size,
           info.st_mtime_ns)
    if key in _LOCAL_HASHES:
        return _LOCAL_HASHES[key]
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(_CHUNK), b""):
            digest.update(block)
    _LOCAL_HASHES[key] = digest.hexdigest()
    return _LOCAL_HASHES[key]


def _download(url, destination):
    """Stream one verified HTTPS asset to destination (size-limited)."""
    request = urllib.request.Request(
        url, headers={"User-Agent": "BUA-Switch-Verify/1",
                      "Cache-Control": "no-cache"})
    total = 0
    with urllib.request.urlopen(request, timeout=60) as response, \
            open(destination, "xb") as target:
        if urllib.parse.urlsplit(response.geturl()).scheme != "https":
            raise ValueError("Asset download left HTTPS")
        for block in iter(lambda: response.read(_CHUNK), b""):
            total += len(block)
            if total > MAX_ASSET_BYTES:
                raise ValueError("Asset exceeds size limit")
            target.write(block)
    if total == 0:
        raise ValueError("Empty asset download")


def ryujinx_archive_members(archive_path):
    """Hash every regular file of a Ryujinx-Nextendo archive.

    Keys are paths relative to publish/, the layout the Nextendo
    deployment writes into ryujinx-extracted/. The portable placeholder
    is skipped because deployment replaces it with a config symlink.
    """
    members = {}
    with tarfile.open(archive_path, "r:gz") as archive:
        for count, member in enumerate(archive, 1):
            if count > MAX_ARCHIVE_MEMBERS:
                raise ValueError("Ryujinx archive has too many entries")
            parts = tuple(p for p in PurePosixPath(member.name).parts
                          if p not in ("", "."))
            if not parts or member.isdir():
                continue
            if (member.name.startswith("/") or ".." in parts
                    or parts[0] != "publish" or not member.isfile()):
                raise ValueError("Unsafe Ryujinx archive entry")
            relative = "/".join(parts[1:])
            if not relative or relative.startswith("portable/") \
                    or relative == "portable":
                continue
            stream = archive.extractfile(member)
            if stream is None:
                raise ValueError("Unreadable Ryujinx archive entry")
            digest = hashlib.sha256()
            with stream:
                for block in iter(lambda: stream.read(_CHUNK), b""):
                    digest.update(block)
            members[relative] = digest.hexdigest()
    if "Ryujinx" not in members:
        raise ValueError("Ryujinx archive has no publish/Ryujinx")
    return members


def _load_cache(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_cache(path, cache):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        temporary = path + ".tmp-" + str(os.getpid())
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(cache, handle, sort_keys=True)
        os.replace(temporary, path)
    except Exception:
        pass


def describe_remote_asset(url, archive, cache, download=_download):
    """Return {"sha256":..., ["members":...]} for one release asset.

    Asset URLs carry their version/commit, so a cached result stays
    valid for that URL. Cache entries are re-validated before use.
    """
    entry = cache.get(url)
    if (isinstance(entry, dict)
            and re.fullmatch(r"[0-9a-f]{64}", str(entry.get("sha256", "")))
            and (not archive or isinstance(entry.get("members"), dict))):
        return entry
    work = tempfile.mkdtemp(prefix="bua-switch-verify-")
    try:
        path = os.path.join(work, "asset")
        download(url, path)
        entry = {"sha256": sha256_file(path)}
        if archive:
            entry["members"] = ryujinx_archive_members(path)
        cache[url] = entry
        return entry
    finally:
        for name in os.listdir(work):
            os.unlink(os.path.join(work, name))
        os.rmdir(work)


def _regular_file(path):
    return os.path.isfile(path) and not os.path.islink(path)


def _check_ryujinx(local_target, extracted_dir, entry):
    # Not launched since the last download: the archive is still staged.
    if _regular_file(local_target):
        if sha256_file(local_target) == entry["sha256"]:
            return "match", "Staged archive matches release"
        return "differs", "Staged archive differs from release"
    if not os.path.isdir(extracted_dir) or os.path.islink(extracted_dir):
        return "missing", "Ryujinx-Nextendo is not installed"
    for relative, digest in entry["members"].items():
        installed = os.path.join(extracted_dir, *relative.split("/"))
        if not _regular_file(installed):
            return "differs", "Missing " + relative
        if sha256_file(installed) != digest:
            return "differs", "Changed " + relative
    return "match", "Installed files match release"


def verify_installed_components(components, root="", cache_path=None,
                                download=_download):
    """Compare installed files with each verified latest component.

    components: the "components" list from verify_switch_components().
    root: test prefix prepended to every /userdata path.
    Returns one {"name","version","state","detail"} per component;
    state is "match", "differs", "missing", "unavailable" or "error".
    """
    cache_path = cache_path or (root + ASSET_CACHE_FILE)
    cache = _load_cache(cache_path)
    results = []
    for item in components:
        name = item["name"]
        target = item["target"]
        if EXPECTED.get(name) != target:
            raise ValueError("Unexpected component target")
        local_target = root + target
        archive = name == "Ryujinx-Nextendo"
        state, detail = "error", ""
        try:
            if item.get("unavailable"):
                state, detail = "unavailable", item.get("error") or ""
            elif not archive and not _regular_file(local_target):
                state, detail = "missing", "Not installed"
            else:
                entry = describe_remote_asset(item["url"], archive, cache,
                                              download=download)
                if archive:
                    state, detail = _check_ryujinx(
                        local_target, root + RYUJINX_EXTRACTED_DIR, entry)
                elif sha256_file(local_target) == entry["sha256"]:
                    state, detail = "match", "Matches release"
                else:
                    state, detail = "differs", "Differs from release"
        except Exception as exc:
            state, detail = "error", str(exc) or exc.__class__.__name__
        results.append({"name": name, "version": item["version"],
                        "state": state, "detail": detail})
    _save_cache(cache_path, cache)
    return results
