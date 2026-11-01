#!/usr/bin/env python3

import ast
import csv
import hashlib
import json
import os
import re
import time
import urllib.request
from pathlib import Path
from urllib.parse import urlparse, urlsplit

FRONTEND = Path("/userdata/system/add-ons/bua/updater/bua_installerx86.py")

OUTDIR = Path("/userdata/system/add-ons/bua/updater/catalog/global")
CACHEDIR = OUTDIR / "installer-cache"

JSON_OUT = OUTDIR / "global-update-manifest.json"
CSV_OUT = OUTDIR / "global-update-manifest.csv"
SUMMARY_OUT = OUTDIR / "global-update-summary.txt"

OUTDIR.mkdir(parents=True, exist_ok=True)
CACHEDIR.mkdir(parents=True, exist_ok=True)

text = FRONTEND.read_text(errors="replace")
tree = ast.parse(text)


def find_assignment(name):
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if (
                    isinstance(target, ast.Name)
                    and target.id == name
                ):
                    return node.value

        if isinstance(node, ast.AnnAssign):
            if (
                isinstance(node.target, ast.Name)
                and node.target.id == name
            ):
                return node.value

    return None


def literal_string(node):
    if isinstance(node, ast.Constant):
        if isinstance(node.value, str):
            return node.value

    return None


def get_bua_base_url():
    node = find_assignment("BUA_BASE_URL")

    if node is None:
        raise RuntimeError("BUA_BASE_URL assignment not found")

    value = literal_string(node)

    if not value:
        raise RuntimeError(
            "BUA_BASE_URL is not a literal string"
        )

    return value.rstrip("/")


BUA_BASE_URL = get_bua_base_url()


def extract_apps():
    """
    Extract the local patched APPS catalog, then merge the current
    upstream BUA APPS catalog over it.

    This keeps updater-specific frontend changes local while allowing
    newly-added upstream applications to enter the update manifest
    automatically.
    """

    def assignment_from_tree(source_tree, name):
        for node in source_tree.body:
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if (
                        isinstance(target, ast.Name)
                        and target.id == name
                    ):
                        return node.value

            if isinstance(node, ast.AnnAssign):
                if (
                    isinstance(node.target, ast.Name)
                    and node.target.id == name
                ):
                    return node.value

        return None

    def base_url_from_tree(
        source_tree,
        fallback,
    ):
        node = assignment_from_tree(
            source_tree,
            "BUA_BASE_URL",
        )

        value = literal_string(node)

        if value:
            return value.rstrip("/")

        return fallback.rstrip("/")

    def parse_dict(
        node,
        base_url,
    ):
        if not isinstance(node, ast.Dict):
            return []

        result = []

        for key_node, value_node in zip(
            node.keys,
            node.values,
        ):
            app_name = literal_string(key_node)

            if not app_name:
                continue

            record = {
                "app": app_name,
                "installer_path": None,
                "installer_url": None,
                "catalog_expression": None,
            }

            try:
                record["catalog_expression"] = (
                    ast.unparse(value_node)
                )
            except Exception:
                pass

            # Standard BUA entry:
            # "Bridge": bua("bridge/bridge.sh")
            if (
                isinstance(value_node, ast.Call)
                and isinstance(
                    value_node.func,
                    ast.Name,
                )
                and value_node.func.id == "bua"
                and value_node.args
            ):
                path = literal_string(
                    value_node.args[0]
                )

                if path:
                    record["installer_path"] = path
                    record["installer_url"] = (
                        f"{base_url}/{path}"
                    )

            # Direct shell command containing a URL.
            if not record["installer_url"]:
                value = literal_string(value_node)

                if value:
                    match = re.search(
                        r'https?://[^\s\'"]+',
                        value,
                    )

                    if match:
                        record["installer_url"] = (
                            match.group(0)
                        )

            result.append(record)

        return result

    def extract_from_tree(
        source_tree,
        base_url,
    ):
        apps = []

        # Initial APPS = {...}
        node = assignment_from_tree(
            source_tree,
            "APPS",
        )

        if isinstance(node, ast.Dict):
            apps.extend(
                parse_dict(
                    node,
                    base_url,
                )
            )

        # Additional APPS.update({...})
        for stmt in source_tree.body:
            if not isinstance(stmt, ast.Expr):
                continue

            call = stmt.value

            if not isinstance(call, ast.Call):
                continue

            func = call.func

            if not (
                isinstance(func, ast.Attribute)
                and func.attr == "update"
                and isinstance(func.value, ast.Name)
                and func.value.id == "APPS"
                and call.args
            ):
                continue

            apps.extend(
                parse_dict(
                    call.args[0],
                    base_url,
                )
            )

        return apps

    # Start with our patched/static frontend.
    local_base_url = base_url_from_tree(
        tree,
        BUA_BASE_URL,
    )

    apps = extract_from_tree(
        tree,
        local_base_url,
    )

    # Then merge current upstream catalog.
    upstream_url = (
        "https://raw.githubusercontent.com/"
        "batocera-unofficial-addons/"
        "batocera-unofficial-addons/main/app/"
        "bua_installerx86.py"
    )

    try:
        req = urllib.request.Request(
            upstream_url,
            headers={
                "User-Agent":
                    "BUA-Global-Updater-Catalog-Sync/1",
                "Cache-Control": "no-cache",
            },
        )

        with urllib.request.urlopen(
            req,
            timeout=25,
        ) as response:
            upstream_text = (
                response.read().decode(
                    "utf-8",
                    errors="replace",
                )
            )

        upstream_tree = ast.parse(
            upstream_text
        )

        upstream_base_url = (
            base_url_from_tree(
                upstream_tree,
                BUA_BASE_URL,
            )
        )

        upstream_apps = extract_from_tree(
            upstream_tree,
            upstream_base_url,
        )

        if upstream_apps:
            apps.extend(upstream_apps)

            print(
                "Upstream catalog sync: "
                f"{len(upstream_apps)} apps"
            )

    except Exception as exc:
        print(
            "Upstream catalog sync skipped: "
            f"{exc}"
        )


    # Official BUA JSON catalog takes precedence over legacy Python entries.
    # Read installer metadata only; never execute downloaded commands.
    json_url = (
        "https://raw.githubusercontent.com/"
        "batocera-unofficial-addons/batocera-unofficial-addons/"
        "main/app/apps_x86.json"
    )
    try:
        req = urllib.request.Request(
            json_url,
            headers={
                "User-Agent": "BUA-Global-Updater-Catalog-Sync/1",
                "Cache-Control": "no-cache",
            },
        )
        with urllib.request.urlopen(req, timeout=25) as response:
            raw = response.read(2 * 1024 * 1024 + 1)

        if len(raw) > 2 * 1024 * 1024:
            raise ValueError("Official catalog exceeds size limit")

        catalog = json.loads(raw.decode("utf-8"))
        if not isinstance(catalog, dict):
            raise ValueError("Invalid official catalog object")

        entries = catalog.get("apps")
        if not isinstance(entries, list):
            raise ValueError("Official catalog lacks apps list")

        parsed = []
        for entry in entries:
            if not isinstance(entry, dict):
                continue

            name = entry.get("name")
            command = entry.get("install")

            if not isinstance(name, str) or not name.strip():
                continue
            if not isinstance(command, str) or not command.strip():
                continue

            # Extract the first actual HTTPS installer URL from the command.
            urls = re.findall(r"https?://[^\s]+", command)
            installer_url = None
            for candidate_url in urls:
                candidate_url = candidate_url.rstrip(');\'"')
                if urlsplit(candidate_url).scheme == "https":
                    installer_url = candidate_url
                    break

            installer_path = None
            if installer_url and installer_url.startswith(BUA_BASE_URL + "/"):
                installer_path = installer_url[len(BUA_BASE_URL) + 1:]

            parsed.append({
                "app": name.strip(),
                "installer_path": installer_path,
                "installer_url": installer_url,
                "catalog_expression": command,
            })

        if not parsed:
            raise ValueError("Official JSON catalog contains no usable apps")

        if not parsed:
            raise ValueError("Official JSON catalog contains no valid applications")
        if len({entry["app"] for entry in parsed}) != len(parsed):
            raise ValueError("Duplicate official JSON applications")
        apps[:] = parsed
        print(f"Official JSON catalog sync: {len(parsed)} apps")

    except Exception as exc:
        if os.environ.get("BUA_REQUIRE_OFFICIAL_JSON") == "1":
            raise RuntimeError(
                "Official BUA catalog unavailable; "
                "refusing incomplete manifest rebuild"
            ) from exc
        print(
            "Official JSON catalog unavailable; "
            f"legacy fallback retained: {exc}"
        )

    # Runtime dictionary semantics:
    # last assignment wins.
    # Because upstream was appended last, current upstream catalog
    # definitions override stale local catalog definitions.
    merged = {}

    for item in apps:
        merged[item["app"]] = item

    return list(merged.values())


URL_RE = re.compile(
    r'https?://[^\s\'"<>)}\]]+',
    re.I,
)


def fetch(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "BUA-Global-Updater-Audit/1",
            "Accept": "*/*",
            "Cache-Control": "no-cache",
        },
    )

    with urllib.request.urlopen(
        req,
        timeout=25,
    ) as response:
        return response.read()


def clean_url(url):
    return url.rstrip(
        ".,;\\"
    )


def extract_urls(script):
    return sorted({
        clean_url(m.group(0))
        for m in URL_RE.finditer(script)
    })


def external_urls(urls):
    result = []

    for url in urls:
        host = urlparse(url).netloc.lower()

        if (
            "batocera-unofficial-addons" in url.lower()
            or host == "raw.githubusercontent.com"
            and "/batocera-unofficial-addons/" in url.lower()
        ):
            continue

        result.append(url)

    return result


def github_repo_from_text(script):
    patterns = [
        r'api\.github\.com/repos/'
        r'([^/"\s]+)/([^/"\s]+)/releases',

        r'github\.com/'
        r'([^/"\s]+)/([^/"\s]+)/releases',

        r'github\.com/'
        r'([^/"\s]+)/([^/"\s]+?)(?:\.git)?'
        r'(?:["\'/\s]|$)',

        r'raw\.githubusercontent\.com/'
        r'([^/"\s]+)/([^/"\s]+)/',
    ]

    for pattern in patterns:
        match = re.search(
            pattern,
            script,
            re.I,
        )

        if match:
            owner = match.group(1)
            repo = match.group(2)

            repo = re.sub(
                r'\.git$',
                '',
                repo,
                flags=re.I,
            )

            return owner, repo

    return None, None


def classify_source(script, urls):
    lower = script.lower()

    # Prefer the application's real external parent source over
    # incidental nested BUA helper/child script references.
    if re.search(
        r'api\.github\.com/repos/'
        r'[^/\s]+/[^/\s]+/releases',
        script,
        re.I,
    ):
        return "github_release_api"

    if (
        "github.com" in lower
        and "/releases/" in lower
    ):
        return "github_release_download"

    if (
        "gitlab.com/api/" in lower
        or "gitlab.com/api/v4" in lower
    ):
        return "gitlab_api"

    if "gitlab.com" in lower:
        return "gitlab"

    if "sourceforge.net" in lower:
        return "sourceforge"

    if (
        "flathub.org" in lower
        or (
            "flathub" in lower
            and "flatpak" in lower
        )
    ):
        return "flathub"

    if re.search(
        r'https?://[^\s\'"]+\.appimage'
        r'(?:[?&\'"\s]|$)',
        script,
        re.I,
    ):
        return "direct_appimage"

    if re.search(
        r'https?://[^\s\'"]+'
        r'\.(?:zip|tar|tar\.gz|tgz|tar\.xz|7z)'
        r'(?:[?&\'"\s]|$)',
        script,
        re.I,
    ):
        return "direct_archive"

    api_urls = [
        u for u in urls
        if (
            "/api/" in u.lower()
            or "api." in urlparse(u).netloc.lower()
        )
    ]

    if api_urls:
        return "other_api"

    # Raw GitHub is lower-confidence than a release API/download.
    if "raw.githubusercontent.com" in lower:
        return "github_raw"

    # Only classify as nested BUA after ruling out real external
    # parent/update sources.
    if (
        "batocera-unofficial-addons" in lower
        and re.search(
            r'curl.+\.sh.+\|\s*(?:bash|sh)',
            script,
            re.I,
        )
    ):
        return "nested_bua"

    if urls:
        return "direct_web"

    return "unknown"


def version_signals(script):
    signals = []

    checks = [
        ("github_tag_name", r'"tag_name"'),
        (
            "github_release_id",
            r'(?:"|\b)id(?:"|\b)'
            r'.*releases',
        ),
        (
            "browser_download_url",
            r'browser_download_url',
        ),
        (
            "version_variable",
            r'\b(?:LATEST_)?VERSION\s*=',
        ),
        (
            "release_variable",
            r'\b(?:LATEST_)?RELEASE\s*=',
        ),
        (
            "json_parser",
            r'\b(?:jq|json\.load|json\.loads)\b',
        ),
        (
            "grep_version",
            r'grep[^\n]*(?:version|tag_name)',
        ),
        (
            "html_scrape",
            r'(?:grep|sed|awk)[^\n]*'
            r'(?:http|href|download)',
        ),
        (
            "etag",
            r'\betag\b',
        ),
        (
            "last_modified",
            r'last-modified',
        ),
    ]

    for name, pattern in checks:
        if re.search(
            pattern,
            script,
            re.I | re.S,
        ):
            signals.append(name)

    return signals


def safety_flags(script):
    flags = []

    patterns = [
        ("rm_rf", r'\brm\s+-[^\n]*rf\b'),
        (
            "rm_appdir",
            r'\brm\s+-[^\n]*'
            r'(?:\$APPDIR|\$\{APPDIR\})',
        ),
        (
            "delete_addons",
            r'/userdata/system/add-ons',
        ),
        (
            "extract_archive",
            r'\b(?:unzip|tar\s|7z\s+x)\b',
        ),
        (
            "recursive_copy",
            r'\bcp\s+-[^\n]*r',
        ),
        (
            "move_replace",
            r'\bmv\s+',
        ),
        (
            "interactive_dialog",
            r'\b(?:yad|zenity)\b',
        ),
        (
            "service_changes",
            r'\b(?:systemctl|batocera-services)\b',
        ),
    ]

    for name, pattern in patterns:
        if re.search(
            pattern,
            script,
            re.I,
        ):
            flags.append(name)

    return flags


def registration_status(script):
    has_mode = "BUA_REGISTRATION_ONLY" in script
    has_register = "bua_register" in script

    if has_mode and has_register:
        return "supported"

    if has_mode:
        return "partial_mode_only"

    if has_register:
        return "partial_register_only"

    return "not_supported"


def post_install_status(script):
    if (
        "bua_register" in script
        and "BUA_REGISTRATION_ONLY" in script
    ):
        # More than one invocation normally means registration-only
        # plus post-install registration.
        count = len(
            re.findall(
                r'\bbua_register\b',
                script,
            )
        )

        if count >= 2:
            return "present"

    return "not_present"


def rolling_release(script):
    lower = script.lower()

    words = (
        "continuous",
        "nightly",
        "snapshot",
        "rolling",
        "master",
        "canary",
        "edge",
    )

    return any(
        word in lower
        for word in words
    )


def identity_strategy(family, script):
    rolling = rolling_release(script)

    if family == "github_release_api":
        if rolling:
            return "github_release_or_asset_id"

        if '"tag_name"' in script:
            return "tag_name"

        return "github_release_id"

    if family == "github_release_download":
        if rolling:
            return "github_release_or_asset_id"

        return "release_tag_or_asset_identity"

    if family in (
        "direct_appimage",
        "direct_archive",
        "direct_web",
    ):
        return "etag_last_modified_or_content_hash"

    if family in (
        "gitlab",
        "gitlab_api",
    ):
        return "gitlab_release_or_asset_identity"

    if family == "sourceforge":
        return "sourceforge_release_identity"

    if family == "flathub":
        return "flatpak_commit"

    if family == "nested_bua":
        return "child_installer_identity"

    if family == "other_api":
        return "provider_native_identity"

    return "custom"




def simple_shell_variables(script):
    """
    Parse simple quoted shell assignments without executing the installer.
    """
    values = {}

    pattern = re.compile(
        r'(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*'
        r'(["\'])(.*?)\2\s*$'
    )

    for match in pattern.finditer(script):
        values[match.group(1)] = match.group(3)

    return values


def expand_simple_shell_value(value, variables):
    """
    Resolve ${NAME} and $NAME references using only previously parsed
    literal assignments. Environment variables such as $HOME are left
    intact for the frontend to expand on the target machine.
    """
    if not value:
        return value

    for _ in range(8):
        before = value

        for name, replacement in variables.items():
            value = value.replace(
                "${" + name + "}",
                replacement,
            )
            value = re.sub(
                rf'\${re.escape(name)}\b',
                lambda m, r=replacement: r,
                value,
            )

        if value == before:
            break

    return value


def declared_install_root(script):
    variables = simple_shell_variables(script)

    for name in (
        "INSTALL_DIR",
        "INSTALL_PATH",
        "APP_DIR",
        "APP_PATH",
    ):
        value = variables.get(name)

        if value:
            return expand_simple_shell_value(
                value,
                variables,
            )

    return None


def declared_payload_urls_by_arch(script):
    """
    Extract architecture-specific payload URLs from common shell
    case branches without executing the installer.
    """
    variables = simple_shell_variables(script)
    result = {}

    arch_patterns = {
        "x86_64": (
            r'(?ms)^\s*'
            r'(?:x86_64\s*\|\s*amd64|'
            r'amd64\s*\|\s*x86_64|'
            r'x86_64|amd64)'
            r'\s*\)\s*(.*?)^\s*;;'
        ),
        "arm64": (
            r'(?ms)^\s*'
            r'(?:aarch64\s*\|\s*arm64|'
            r'arm64\s*\|\s*aarch64|'
            r'aarch64|arm64)'
            r'\s*\)\s*(.*?)^\s*;;'
        ),
    }

    payload_suffixes = (
        ".appimage",
        ".wsquashfs",
        ".squashfs",
        ".zip",
        ".7z",
        ".tar",
        ".tar.gz",
        ".tgz",
        ".tar.xz",
        ".txz",
        ".tar.bz2",
        ".tbz2",
        ".exe",
        ".msi",
        ".deb",
        ".rpm",
    )

    for arch, pattern in arch_patterns.items():
        match = re.search(
            pattern,
            script,
        )

        if not match:
            continue

        block = match.group(1)

        assignments = re.findall(
            r'(?m)^\s*'
            r'([A-Za-z_][A-Za-z0-9_]*URL[A-Za-z0-9_]*)'
            r'\s*=\s*(["\'])(.*?)\2\s*$',
            block,
        )

        for _, _, raw_value in assignments:
            value = expand_simple_shell_value(
                raw_value,
                variables,
            )

            if not value.lower().startswith(
                ("http://", "https://")
            ):
                continue

            path = value.split("?", 1)[0].lower()

            if path.endswith(payload_suffixes):
                result[arch] = value
                break

    return result


def declared_payload_checksums(script):
    """
    Extract installer-declared SHA-256 payload identities.

    Supports common architecture-specific and generic variable names,
    for example:

        EXPECTED_SHA256_X86_64="..."
        EXPECTED_SHA256_ARM="..."
        SHA256="..."
    """
    result = {}

    patterns = {
        "x86_64": (
            r'(?im)^[A-Za-z0-9_]*(?:SHA256|SHA_256)'
            r'[A-Za-z0-9_]*(?:X86_64|AMD64)'
            r'[A-Za-z0-9_]*\s*=\s*["\']'
            r'([0-9a-f]{64})["\']'
        ),
        "arm64": (
            r'(?im)^[A-Za-z0-9_]*(?:SHA256|SHA_256)'
            r'[A-Za-z0-9_]*(?:AARCH64|ARM64|ARM)'
            r'[A-Za-z0-9_]*\s*=\s*["\']'
            r'([0-9a-f]{64})["\']'
        ),
    }

    for arch, pattern in patterns.items():
        match = re.search(pattern, script)

        if match:
            result[arch] = match.group(1).lower()

    # Generic checksum fallback.
    generic_patterns = (
        r'(?im)^(?:EXPECTED_)?SHA256'
        r'\s*=\s*["\']([0-9a-f]{64})["\']',
        r'(?im)^(?:EXPECTED_)?SHA_256'
        r'\s*=\s*["\']([0-9a-f]{64})["\']',
    )

    for pattern in generic_patterns:
        match = re.search(pattern, script)

        if match:
            result.setdefault(
                "generic",
                match.group(1).lower(),
            )
            break

    return result


def candidate_app_version_strategy(
    family,
    signals,
    script,
):
    if "github_tag_name" in signals:
        return "tag_name"

    checksums = declared_payload_checksums(
        script
    )

    if checksums:
        return "installer_declared_payload_sha256"

    if "version_variable" in signals:
        return "existing_version_variable"

    if family == "flathub":
        return "flatpak_version_or_branch"

    if family == "sourceforge":
        return "sourceforge_release_name"

    if family in (
        "direct_appimage",
        "direct_archive",
        "direct_web",
    ):
        return "provider_version_if_available"

    if family == "nested_bua":
        return "child_installer_report"

    return "custom"


def conversion_status(
    family,
    reg_status,
    script,
):
    if reg_status == "supported":
        return "already_registration_capable"

    if family == "github_release_api":
        return "high_confidence_auto_candidate"

    if family in (
        "github_release_download",
        "gitlab_api",
        "flathub",
    ):
        return "family_adapter_candidate"

    if family in (
        "direct_appimage",
        "direct_archive",
        "sourceforge",
        "other_api",
        "direct_web",
        "github_raw",
        "gitlab",
    ):
        return "inspect_then_family_adapter"

    if family == "nested_bua":
        return "variant_or_child_handling"

    return "custom_required"


def safe_filename(app):
    slug = re.sub(
        r'[^A-Za-z0-9._-]+',
        '_',
        app,
    ).strip("_")

    return slug or "app"


apps = extract_apps()

manifest = []

print(
    f"BUA_BASE_URL={BUA_BASE_URL}"
)
print(
    f"APPS discovered={len(apps)}"
)
print()

for index, app in enumerate(apps, 1):
    name = app["app"]
    url = app["installer_url"]

    print(
        f"[{index:03d}/{len(apps):03d}] "
        f"{name}"
    )

    record = dict(app)

    record.update({
        "fetch_status": None,
        "fetch_error": None,
        "sha256": None,
        "source_family": None,
        "all_urls": [],
        "external_urls": [],
        "github_owner": None,
        "github_repo": None,
        "version_signals": [],
        "candidate_app_version_strategy": None,
        "candidate_update_identity_strategy": None,
        "rolling_release_candidate": False,
        "registration_status": None,
        "post_install_registration": None,
        "safety_flags": [],
        "conversion_status": None,
        "cached_installer": None,
    })

    if not url:
        record["fetch_status"] = "unresolved"
        record["fetch_error"] = (
            "Could not resolve installer URL from APPS"
        )
        record["source_family"] = "unknown"
        record["conversion_status"] = "custom_required"
        manifest.append(record)
        continue

    try:
        raw = fetch(url)
        script = raw.decode(
            "utf-8",
            "replace",
        )

        record["fetch_status"] = "ok"
        record["sha256"] = hashlib.sha256(
            raw
        ).hexdigest()

        cache_name = (
            f"{index:03d}-"
            f"{safe_filename(name)}.sh"
        )

        cache_path = CACHEDIR / cache_name
        cache_path.write_bytes(raw)

        record["cached_installer"] = str(
            cache_path
        )

        urls = extract_urls(script)
        ext_urls = external_urls(urls)

        family = classify_source(
            script,
            ext_urls,
        )

        signals = version_signals(script)
        flags = safety_flags(script)
        reg = registration_status(script)

        owner, repo = github_repo_from_text(
            script
        )

        record.update({
            "source_family": family,
            "all_urls": urls,
            "external_urls": ext_urls,
            "github_owner": owner,
            "github_repo": repo,
            "version_signals": signals,
            "candidate_app_version_strategy":
                candidate_app_version_strategy(
                    family,
                    signals,
                    script,
                ),
            "declared_payload_sha256":
                declared_payload_checksums(
                    script
                ),
            "install_root":
                declared_install_root(
                    script
                ),
            "payload_urls_by_arch":
                declared_payload_urls_by_arch(
                    script
                ),
            "candidate_update_identity_strategy":
                identity_strategy(
                    family,
                    script,
                ),
            "rolling_release_candidate":
                rolling_release(script),
            "registration_status": reg,
            "post_install_registration":
                post_install_status(script),
            "safety_flags": flags,
            "conversion_status":
                conversion_status(
                    family,
                    reg,
                    script,
                ),
        })

    except Exception as exc:
        record["fetch_status"] = "error"
        record["fetch_error"] = (
            f"{type(exc).__name__}: {exc}"
        )
        record["source_family"] = "unknown"
        record["conversion_status"] = (
            "fetch_error"
        )

    manifest.append(record)

    # Be polite to remote hosts while scanning.
    time.sleep(0.03)


family_counts = {}
conversion_counts = {}
registration_counts = {}
fetch_counts = {}

for item in manifest:
    for target, key in (
        (family_counts, item["source_family"]),
        (
            conversion_counts,
            item["conversion_status"],
        ),
        (
            registration_counts,
            item["registration_status"],
        ),
        (
            fetch_counts,
            item["fetch_status"],
        ),
    ):
        # JSON object keys must be strings. Missing classifications
        # are reported explicitly as "unknown".
        if key is None:
            key = "unknown"
        else:
            key = str(key)

        target[key] = target.get(key, 0) + 1


payload = {
    "schema": 1,
    "frontend": str(FRONTEND),
    "bua_base_url": BUA_BASE_URL,
    "total_apps": len(manifest),
    "summary": {
        "fetch_status": fetch_counts,
        "source_families": family_counts,
        "conversion_status": conversion_counts,
        "registration_status": registration_counts,
    },
    "apps": manifest,
}

JSON_OUT.write_text(
    json.dumps(
        payload,
        indent=2,
        sort_keys=True,
    )
)


columns = [
    "app",
    "installer_path",
    "installer_url",
    "fetch_status",
    "fetch_error",
    "sha256",
    "source_family",
    "github_owner",
    "github_repo",
    "rolling_release_candidate",
    "registration_status",
    "post_install_registration",
    "candidate_app_version_strategy",
    "candidate_update_identity_strategy",
    "conversion_status",
    "version_signals",
    "safety_flags",
]

with CSV_OUT.open(
    "w",
    newline="",
) as f:
    writer = csv.DictWriter(
        f,
        fieldnames=columns,
    )

    writer.writeheader()

    for item in manifest:
        row = {}

        for column in columns:
            value = item.get(column)

            if isinstance(value, list):
                value = ",".join(value)

            row[column] = value

        writer.writerow(row)


summary_lines = [
    "BUA GLOBAL UPDATE MANIFEST",
    "==========================",
    "",
    f"Total APPS: {len(manifest)}",
    "",
    "FETCH STATUS",
    "------------",
]

for key, value in sorted(fetch_counts.items()):
    summary_lines.append(
        f"{key}: {value}"
    )

summary_lines += [
    "",
    "SOURCE FAMILIES",
    "---------------",
]

for key, value in sorted(
    family_counts.items(),
    key=lambda x: (-x[1], str(x[0])),
):
    summary_lines.append(
        f"{key}: {value}"
    )

summary_lines += [
    "",
    "CONVERSION STATUS",
    "-----------------",
]

for key, value in sorted(
    conversion_counts.items(),
    key=lambda x: (-x[1], str(x[0])),
):
    summary_lines.append(
        f"{key}: {value}"
    )

summary_lines += [
    "",
    "REGISTRATION STATUS",
    "-------------------",
]

for key, value in sorted(
    registration_counts.items(),
    key=lambda x: (-x[1], str(x[0])),
):
    summary_lines.append(
        f"{key}: {value}"
    )

SUMMARY_OUT.write_text(
    "\n".join(summary_lines) + "\n"
)

print()
print("===== COMPLETE =====")
print(f"JSON:    {JSON_OUT}")
print(f"CSV:     {CSV_OUT}")
print(f"SUMMARY: {SUMMARY_OUT}")
print()
print("\n".join(summary_lines))
