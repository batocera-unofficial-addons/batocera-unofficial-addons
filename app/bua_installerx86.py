#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sys
import threading
import subprocess
import pygame
import json
import base64
import io
import re
import pty
import fcntl
import termios
from datetime import datetime, timezone
from urllib.parse import urlparse
import urllib.request
import urllib.parse
import time
from typing import Dict, List, Tuple
from pathlib import Path
import hashlib

# ------------------------------
# Changelog
# ------------------------------
# Edit this section to add changelog entries. Leave empty to disable.
# This will be shown once to users when they first launch after an update.

CHANGELOG = """
- Added npsget - Helper to download games, DLCs, updates, themes and avatars from NoPayStation
- Added ps3i - Installer for .pkg PS3 games into RPCS3 with automatic shortcut creation
- Added Prism Launcher - open source Minecraft launcher with mod management and multi-instance support
- Added AzaharPlus - selectable 3DS emulator option alongside Azahar
- Replaced StepMania with ITGMania - ITG-focused rhythm game with bundled songs
- Desktop: wallpaper and icon layout now preserved on update
- Desktop: improved DRL migration and palette support
- NVIDIAPatch: fixed GLX chain on host
""".strip()

# ------------------------------
# Live Update Block
# ------------------------------
# This code runs on EVERY launch before the main app loads.
# Use this for one-time setup tasks, migrations, or live fixes.
# Keep it lightweight - heavy operations will slow down app startup.

def live_update_block():
    """
    Code block that runs on every app launch.

    Use cases:
    - Install/update system services (like custom_service_handler)
    - Perform migrations or one-time fixes
    - Update configuration files
    - Check/install dependencies

    IMPORTANT: Keep this fast! It runs on EVERY launch.
    """
    try:
        setup_custom_service_handler()
        check_symlink_manager_and_warn()
        live_update()

    except Exception as e:
        print(f"[BUA] Live update block error: {e}")

# ------------------------------
# Translation System
# ------------------------------

# Translation cache
TRANSLATIONS: Dict[str, Dict[str, str]] = {}
CURRENT_LANGUAGE = "en"
LANGUAGE_FILE = "/userdata/system/add-ons/bua_language.txt"
RESOLUTION_FILE = "/userdata/system/add-ons/bua_resolution.txt"
CARDS_PER_PAGE_FILE = "/userdata/system/add-ons/bua_cards_per_page.txt"
CHANGELOG_HASH_FILE = "/userdata/system/add-ons/bua_changelog_hash.txt"
TRANSLATION_CACHE_FILE = "/userdata/system/add-ons/bua_translation_cache.json"
SPLASH_CACHE_FILE = "/userdata/system/add-ons/bua_splash.mp4"

# Default and current cards per page setting
DEFAULT_CARDS_PER_PAGE = "auto"  # "auto" or a number like "3", "5", "7", etc.
CARDS_PER_PAGE = DEFAULT_CARDS_PER_PAGE

# Cache for available languages (to avoid checking GitHub every time)
AVAILABLE_LANGUAGES_CACHE: List[Tuple[str, str, str]] = []
LANGUAGES_CACHE_CHECKED = False

# Directories to search for translation files (local fallback)
TRANSLATION_DIRS = [
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "translations", "Verified"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "translations"),
    "/userdata/system/add-ons/translations/Verified",
    "/userdata/system/add-ons/translations",
    "translations/Verified",
    "translations",
]

# GitHub URL for translations
TRANSLATION_BASE_URL = "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/translation"

def fetch_url_with_retry(url: str, headers: dict, timeout: int = 5, retries: int = 2) -> bytes:
    """
    Fetch URL with exponential backoff retry logic.
    Returns the response bytes or raises an exception after all retries fail.
    Set retries=0 for a single attempt with no error logging (useful for silent fallbacks).
    """
    import time
    import urllib.error
    last_error = None
    silent_mode = (retries == 0)  # Silent mode when no retries requested

    for attempt in range(retries + 1):
        try:
            if attempt > 0:
                wait_time = (2 ** attempt)  # Exponential backoff: 2s, 4s
                print(f"[BUA] Retry {attempt}/{retries} after {wait_time}s...")
                time.sleep(wait_time)

            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=timeout) as response:
                return response.read()
        except urllib.error.HTTPError as e:
            last_error = e
            if attempt < retries and not silent_mode:
                print(f"[BUA] HTTP Error {e.code}: {e.reason} - {url}")
            continue
        except urllib.error.URLError as e:
            last_error = e
            if attempt < retries and not silent_mode:
                print(f"[BUA] Network error: {e.reason} - {url}")
            continue
        except Exception as e:
            last_error = e
            if attempt < retries and not silent_mode:
                print(f"[BUA] Error: {e} - {url}")
            continue

    # All retries failed
    if not silent_mode:
        print(f"[BUA] Failed to fetch after {retries + 1} attempts: {url}")
    raise last_error

def load_translation_cache() -> Dict[str, Dict[str, str]]:
    """Load all cached translations from disk"""
    try:
        if os.path.exists(TRANSLATION_CACHE_FILE):
            with open(TRANSLATION_CACHE_FILE, 'r', encoding='utf-8') as f:
                cache = json.load(f)
                print(f"[BUA] Loaded translation cache with {len(cache)} languages")
                return cache
    except Exception as e:
        print(f"[BUA] Could not load translation cache: {e}")
    return {}

def save_translation_cache(cache: Dict[str, Dict[str, str]]):
    """Save all translations to disk cache"""
    try:
        os.makedirs(os.path.dirname(TRANSLATION_CACHE_FILE), exist_ok=True)
        with open(TRANSLATION_CACHE_FILE, 'w', encoding='utf-8') as f:
            json.dump(cache, f, ensure_ascii=False)
        print(f"[BUA] Saved translation cache with {len(cache)} languages")
    except Exception as e:
        print(f"[BUA] Could not save translation cache: {e}")

def load_translation_file(lang_code: str) -> Dict[str, str]:
    """Load a translation JSON file from cache or GitHub with retry logic"""
    # First, check disk cache
    cache = load_translation_cache()
    if lang_code in cache:
        print(f"[BUA] Using cached translation for {lang_code} ({len(cache[lang_code])} keys)")
        return cache[lang_code]

    # Not in cache, try downloading from GitHub
    try:
        github_url = f"{TRANSLATION_BASE_URL}/{lang_code}.json"
        print(f"[BUA] Downloading translation from: {github_url}")

        data_bytes = fetch_url_with_retry(
            github_url,
            headers={"User-Agent": "BUA-Installer"},
            timeout=5,
            retries=2
        )

        data = json.loads(data_bytes.decode('utf-8'))
        print(f"[BUA] Successfully downloaded translation {lang_code} ({len(data)} keys)")

        # Save to cache
        cache[lang_code] = data
        save_translation_cache(cache)

        return data
    except Exception as e:
        print(f"[BUA] ERROR: Could not load translation {lang_code} after retries: {e}")
        print(f"[BUA] Continuing with empty translation (English fallback)")
        return {}

def get_batocera_language() -> str:
    """Read system language from batocera.conf"""
    batocera_conf = "/userdata/system/batocera.conf"
    if os.path.exists(batocera_conf):
        try:
            with open(batocera_conf, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('system.language='):
                        # Extract language code (e.g., "en_US" -> "en")
                        lang_value = line.split('=', 1)[1].strip()
                        # Map batocera locale codes to our language codes
                        if lang_value.startswith('en_'):
                            return 'en'
                        elif lang_value.startswith('es_'):
                            return 'es'
                        elif lang_value.startswith('fr_'):
                            return 'fr'
                        elif lang_value.startswith('de_'):
                            return 'de'
                        elif lang_value.startswith('it_'):
                            return 'it'
                        elif lang_value.startswith('pt_BR'):
                            return 'pt_BR'
                        elif lang_value.startswith('pt_'):
                            return 'pt'
                        elif lang_value.startswith('ru_'):
                            return 'ru'
                        elif lang_value.startswith('ja_'):
                            return 'ja'
                        elif lang_value.startswith('zh_CN'):
                            return 'zh'
                        elif lang_value.startswith('zh_TW'):
                            return 'zh_TW'
                        elif lang_value.startswith('ko_'):
                            return 'ko'
                        elif lang_value.startswith('ar_'):
                            return 'ar'
                        elif lang_value.startswith('nl_'):
                            return 'nl'
                        elif lang_value.startswith('pl_'):
                            return 'pl'
                        elif lang_value.startswith('tr_'):
                            return 'tr'
                        elif lang_value.startswith('vi_'):
                            return 'vi'
                        elif lang_value.startswith('th_'):
                            return 'th'
                        elif lang_value.startswith('sv_'):
                            return 'sv'
                        elif lang_value.startswith('no_'):
                            return 'no'
                        elif lang_value.startswith('da_'):
                            return 'da'
                        elif lang_value.startswith('fi_'):
                            return 'fi'
                        elif lang_value.startswith('cs_'):
                            return 'cs'
                        elif lang_value.startswith('hu_'):
                            return 'hu'
                        elif lang_value.startswith('ro_'):
                            return 'ro'
                        elif lang_value.startswith('uk_'):
                            return 'uk'
                        elif lang_value.startswith('el_'):
                            return 'el'
                        elif lang_value.startswith('he_'):
                            return 'he'
                        elif lang_value.startswith('hi_'):
                            return 'hi'
                        elif lang_value.startswith('id_'):
                            return 'id'
                        elif lang_value.startswith('ms_'):
                            return 'ms'
        except Exception as e:
            print(f"Error reading batocera.conf: {e}")
    return "en"

def load_language():
    """Load saved language preference"""
    global CURRENT_LANGUAGE, TRANSLATIONS

    # Priority 1: Check if user has manually set a language in BUA
    user_set_language = False
    try:
        if os.path.exists(LANGUAGE_FILE):
            with open(LANGUAGE_FILE, 'r') as f:
                lang = f.read().strip()
                if lang:
                    CURRENT_LANGUAGE = lang
                    user_set_language = True
    except Exception:
        pass

    # Priority 2: If no user preference, use batocera.conf language
    if not user_set_language:
        CURRENT_LANGUAGE = get_batocera_language()

    # Load English as fallback
    if "en" not in TRANSLATIONS:
        TRANSLATIONS["en"] = load_translation_file("en")

    # Load current language
    if CURRENT_LANGUAGE != "en" and CURRENT_LANGUAGE not in TRANSLATIONS:
        TRANSLATIONS[CURRENT_LANGUAGE] = load_translation_file(CURRENT_LANGUAGE)

def save_language(lang: str):
    """Save language preference and reload translations"""
    global CURRENT_LANGUAGE, TRANSLATIONS
    try:
        os.makedirs(os.path.dirname(LANGUAGE_FILE), exist_ok=True)
        with open(LANGUAGE_FILE, 'w') as f:
            f.write(lang)
    except Exception:
        pass

    # Update current language
    CURRENT_LANGUAGE = lang

    # Load the new language if not already loaded or force reload
    TRANSLATIONS[lang] = load_translation_file(lang)

def t(key: str) -> str:
    """Translate a key to the current language"""
    # Try current language
    if CURRENT_LANGUAGE in TRANSLATIONS:
        value = TRANSLATIONS[CURRENT_LANGUAGE].get(key)
        if value:
            return value

    # Fallback to English
    if "en" in TRANSLATIONS:
        value = TRANSLATIONS["en"].get(key)
        if value:
            return value

    # Last resort: return key itself
    return key

def check_language_exists(lang_data: Tuple[str, str, str], results: list, lock: threading.Lock):
    """Check if a language file exists on GitHub (threaded helper)"""
    name, code, native = lang_data
    github_url = f"{TRANSLATION_BASE_URL}/{code}.json"
    try:
        req = urllib.request.Request(github_url, headers={"User-Agent": "BUA-Installer"}, method='HEAD')
        with urllib.request.urlopen(req, timeout=2) as response:
            if response.status == 200:
                with lock:
                    results.append((name, code, native))
    except Exception:
        # File doesn't exist on GitHub, skip it
        pass

def get_available_languages() -> List[Tuple[str, str, str]]:
    """Get list of available languages as (name, code, native_name) tuples from GitHub"""
    global AVAILABLE_LANGUAGES_CACHE, LANGUAGES_CACHE_CHECKED

    # Return cached result if already checked
    if LANGUAGES_CACHE_CHECKED:
        return AVAILABLE_LANGUAGES_CACHE

    # All potential languages - will be filtered to only show what exists on GitHub
    # Format: (English name, code, native name)
    all_languages = [
        ("Arabic", "ar", "العربية"),
        ("Chinese (Simplified)", "zh", "简体中文"),
        ("Chinese (Traditional)", "zh_TW", "繁體中文"),
        ("Czech", "cs", "Čeština"),
        ("Danish", "da", "Dansk"),
        ("Dutch", "nl", "Nederlands"),
        ("English", "en", "English"),
        ("Finnish", "fi", "Suomi"),
        ("French", "fr", "Français"),
        ("German", "de", "Deutsch"),
        ("Greek", "el", "Ελληνικά"),
        ("Hebrew", "he", "עברית"),
        ("Hindi", "hi", "हिन्दी"),
        ("Hungarian", "hu", "Magyar"),
        ("Indonesian", "id", "Bahasa Indonesia"),
        ("Italian", "it", "Italiano"),
        ("Japanese", "ja", "日本語"),
        ("Korean", "ko", "한국어"),
        ("Malay", "ms", "Bahasa Melayu"),
        ("Norwegian", "no", "Norsk"),
        ("Polish", "pl", "Polski"),
        ("Portuguese", "pt", "Português"),
        ("Portuguese (Brazil)", "pt_BR", "Português (Brasil)"),
        ("Romanian", "ro", "Română"),
        ("Russian", "ru", "Русский"),
        ("Spanish", "es", "Español"),
        ("Swedish", "sv", "Svenska"),
        ("Thai", "th", "ไทย"),
        ("Turkish", "tr", "Türkçe"),
        ("Ukrainian", "uk", "Українська"),
        ("Vietnamese", "vi", "Tiếng Việt"),
    ]

    # Check which languages actually exist on GitHub (in parallel for speed)
    available_languages = []
    lock = threading.Lock()
    threads = []

    for lang_data in all_languages:
        thread = threading.Thread(target=check_language_exists, args=(lang_data, available_languages, lock))
        thread.daemon = True
        thread.start()
        threads.append(thread)

    # Wait for all checks to complete (max 3 seconds total)
    for thread in threads:
        thread.join(timeout=3)

    # Always ensure English is available as fallback
    if not any(lang[1] == "en" for lang in available_languages):
        available_languages.append(("English", "en", "English"))

    # Cache the result
    AVAILABLE_LANGUAGES_CACHE = sorted(available_languages, key=lambda x: x[0])
    LANGUAGES_CACHE_CHECKED = True

    return AVAILABLE_LANGUAGES_CACHE

# Language will be loaded during splash screen
# load_language() - moved to play_splash_and_load()

# ------------------------------
# Installation History Manager
# ------------------------------

HISTORY_FILE = "/userdata/system/add-ons/bua_history.json"

# ------------------------------
# BUA Package State Manager
# ------------------------------
#
# bua_history.json remains the human-readable installation history.
# This separate file stores the machine-readable package state used
# for reliable update detection.
#
# Schema:
#
# {
#   "_schema": 1,
#   "packages": {
#       "Lutris": {
#           "package_revision": "...",
#           "app_version": "...",
#           "installer_source": "...",
#           "update_method": "reinstall",
#           "installed_at": "...",
#           "updated_at": "..."
#       }
#   }
# }
#
PACKAGE_STATE_FILE = os.environ.get(
    "BUA_PACKAGE_STATE_FILE",
    "/userdata/system/add-ons/bua_packages.json"
)
PACKAGE_STATE_SCHEMA = 1

BLOCKED_SOURCE_FILE = (
    "/userdata/system/add-ons/bua/updater/catalog/global/"
    "blocked-source-packages.json"
)

_BLOCKED_SOURCE_CACHE = None


def load_blocked_source_packages() -> Dict:
    """
    Load packages whose required functional upstream/integration source
    is currently unavailable.

    Failure to read this optional manifest must never break the updater.
    """
    global _BLOCKED_SOURCE_CACHE

    if _BLOCKED_SOURCE_CACHE is not None:
        return _BLOCKED_SOURCE_CACHE

    result = {}

    try:
        with open(
            BLOCKED_SOURCE_FILE,
            "r",
            encoding="utf-8",
        ) as f:
            data = json.load(f)

        packages = data.get("packages")

        if isinstance(packages, dict):
            for app_name, info in packages.items():
                if not isinstance(app_name, str):
                    continue

                if not isinstance(info, dict):
                    continue

                if info.get("status") != "blocked_source":
                    continue

                result[app_name] = {
                    "status": "blocked_source",
                    "reason": str(
                        info.get("reason") or ""
                    ).strip(),
                    "source": str(
                        info.get("source") or ""
                    ).strip(),
                }

    except Exception as exc:
        print(
            "[BUA] Could not load blocked-source manifest: "
            f"{exc}"
        )

    _BLOCKED_SOURCE_CACHE = result
    return result


def get_blocked_source_status(app_name: str) -> Dict | None:
    """
    Return blocker metadata for a known broken-source package.
    """
    info = load_blocked_source_packages().get(app_name)

    if not info:
        return None

    return {
        "status": "blocked_source",
        "needs_update": False,
        "reason": info.get("reason") or "",
        "source": info.get("source") or "",
    }


def load_package_state() -> Dict:
    """Load BUA machine-readable installed-package state."""
    default_state = {
        "_schema": PACKAGE_STATE_SCHEMA,
        "packages": {}
    }

    try:
        if not os.path.exists(PACKAGE_STATE_FILE):
            return default_state

        with open(PACKAGE_STATE_FILE, "r") as f:
            state = json.load(f)

        if not isinstance(state, dict):
            return default_state

        if not isinstance(state.get("packages"), dict):
            state["packages"] = {}

        state["_schema"] = PACKAGE_STATE_SCHEMA
        return state

    except Exception as e:
        print(f"Error loading package state: {e}")
        return default_state


def save_package_state(state: Dict):
    """Atomically save BUA machine-readable installed-package state."""
    try:
        os.makedirs(os.path.dirname(PACKAGE_STATE_FILE), exist_ok=True)

        state["_schema"] = PACKAGE_STATE_SCHEMA
        state.setdefault("packages", {})

        temp_file = PACKAGE_STATE_FILE + ".tmp"

        with open(temp_file, "w") as f:
            json.dump(state, f, indent=2, sort_keys=True)

        os.replace(temp_file, PACKAGE_STATE_FILE)

    except Exception as e:
        print(f"Error saving package state: {e}")



BUA_REGISTRATION_PREFIX = "__BUA_REGISTER__="


def extract_install_registration(lines: List[str]) -> Dict | None:
    """
    Extract installer-provided BUA package metadata from captured output.

    Installers may emit one line:

      __BUA_REGISTER__={...json...}

    The newest valid registration line wins.
    """
    if not lines:
        return None

    for raw_line in reversed(lines):
        line = str(raw_line).strip()

        if not line.startswith(BUA_REGISTRATION_PREFIX):
            continue

        payload = line[len(BUA_REGISTRATION_PREFIX):].strip()

        try:
            registration = json.loads(payload)
        except Exception as e:
            print(f"[BUA] Invalid installer registration JSON: {e}")
            continue

        if isinstance(registration, dict):
            return registration

    return None


def normalize_install_registration(registration: Dict) -> Dict:
    """
    Validate and normalize installer-provided package metadata.

    Unknown fields are deliberately ignored so installers cannot write
    arbitrary package-state keys.
    """
    if not isinstance(registration, dict):
        return {}

    normalized = {}

    app_version = registration.get("app_version")

    if app_version is not None:
        app_version = str(app_version).strip()

        if app_version:
            normalized["app_version"] = app_version

    update_identity = registration.get("update_identity")

    if update_identity is not None:
        update_identity = str(update_identity).strip()

    # Backward compatibility:
    # schema-1 installers did not have a separate update identity.
    if not update_identity:
        update_identity = normalized.get("app_version")

    if update_identity:
        normalized["update_identity"] = update_identity

    # Optional variant identifier for installers that expose multiple
    # independently updateable upstream variants under one BUA entry.
    #
    # Examples:
    #   blissos16-generic
    #   blissos16-go
    #
    # Keep this deliberately restrictive because it may later be passed
    # back to registration-only installer probes.
    variant_id = registration.get("variant_id")

    if variant_id is not None:
        variant_id = str(variant_id).strip()

        if (
            variant_id
            and re.fullmatch(
                r"[A-Za-z0-9._-]{1,64}",
                variant_id,
            )
        ):
            normalized["variant_id"] = variant_id

    update_method = registration.get("update_method")

    if update_method in (
        "reinstall",
        "custom",
        "unsupported",
    ):
        normalized["update_method"] = update_method

    upstream = registration.get("upstream")

    if isinstance(upstream, dict):
        upstream_type = upstream.get("type")

        if upstream_type:
            clean_upstream = {
                "type": str(upstream_type).strip()
            }

            for key in (
                "owner",
                "repo",
                "url",
                "channel",
                "asset",
            ):
                value = upstream.get(key)

                if value is not None:
                    value = str(value).strip()

                    if value:
                        clean_upstream[key] = value

            normalized["upstream"] = clean_upstream

    update_recipe = registration.get("update_recipe")

    if isinstance(update_recipe, dict):
        recipe_type = str(
            update_recipe.get("type") or ""
        ).strip()

        if recipe_type in (
            "replace_file",
            "replace_archive",
            "replace_bundle",
            "multi_component",
        ):
            clean_recipe = {
                "type": recipe_type,
            }

            for key in (
                "target",
                "asset_pattern",
                "asset_exclude_pattern",
                "download_url",
                "archive_subpath",
            ):
                value = update_recipe.get(key)

                if value is not None:
                    value = str(value).strip()

                    if value:
                        clean_recipe[key] = value

            executable = update_recipe.get("executable")

            if isinstance(executable, bool):
                clean_recipe["executable"] = executable

            if recipe_type == "multi_component":
                components = update_recipe.get("components")

                if isinstance(components, list):
                    clean_components = []

                    for component in components:
                        if not isinstance(component, dict):
                            continue

                        url = str(
                            component.get("url") or ""
                        ).strip()

                        target = str(
                            component.get("target") or ""
                        ).strip()

                        if (
                            not url
                            or not target.startswith("/userdata/")
                        ):
                            continue

                        clean_component = {
                            "type": str(
                                component.get("type")
                                or "replace_file"
                            ).strip(),
                            "url": url,
                            "target": target,
                            "executable": bool(
                                component.get(
                                    "executable",
                                    True,
                                )
                            ),
                        }

                        name = str(
                            component.get("name") or ""
                        ).strip()

                        version = str(
                            component.get("version") or ""
                        ).strip()

                        if name:
                            clean_component["name"] = name

                        if version:
                            clean_component["version"] = version

                        clean_components.append(
                            clean_component
                        )

                    if clean_components:
                        clean_recipe["components"] = (
                            clean_components
                        )

            normalized["update_recipe"] = clean_recipe

    version_probe = registration.get("version_probe")

    if isinstance(version_probe, dict):
        probe_type = version_probe.get("type")

        if probe_type:
            clean_probe = {
                "type": str(probe_type).strip()
            }

            for key in (
                "path",
                "key",
                "command",
                "pattern",
            ):
                value = version_probe.get(key)

                if value is not None:
                    value = str(value).strip()

                    if value:
                        clean_probe[key] = value

            normalized["version_probe"] = clean_probe

    return normalized


def apply_install_registration(
    app_name: str,
    runner_lines: List[str],
    registration_source: str = "installer",
) -> bool:
    """
    Save package metadata emitted by a successful BUA installer.
    """
    registration = extract_install_registration(runner_lines)

    if not registration:
        return False

    package_data = normalize_install_registration(registration)

    if not package_data:
        return False

    package_data["registration_source"] = registration_source
    package_data["registration_schema"] = 2

    set_package_state(app_name, package_data)

    print(
        f"[BUA] Registered install metadata for "
        f"{app_name}: {package_data}"
    )

    return True



def get_bua_registration_shell_helper() -> str:
    """Return the shell helper injected into BUA installers."""
    return r"""
bua_register() {
    local app_version="$1"
    local upstream_type="$2"
    local owner="$3"
    local repo="$4"
    local update_method="$5"
    local probe_type="$6"
    local probe_path="$7"
    local probe_key="$8"
    local update_identity="${9:-$app_version}"
    local variant_id="${10:-}"
    local probe_command="${11:-}"
    local probe_pattern="${12:-}"
    local update_type="${13:-}"
    local update_target="${14:-}"
    local asset_pattern="${15:-}"
    local update_download_url="${16:-}"
    local update_executable="${17:-}"
    local upstream_url="${18:-}"
    local components_json="${19:-}"

    python3 - \
        "$app_version" \
        "$upstream_type" \
        "$owner" \
        "$repo" \
        "$update_method" \
        "$probe_type" \
        "$probe_path" \
        "$probe_key" \
        "$update_identity" \
        "$variant_id" \
        "$probe_command" \
        "$probe_pattern" \
        "$update_type" \
        "$update_target" \
        "$asset_pattern" \
        "$update_download_url" \
        "$update_executable" \
        "$upstream_url" \
        "$components_json" <<'PYBUAREG'
import json
import sys

(
    app_version,
    upstream_type,
    owner,
    repo,
    update_method,
    probe_type,
    probe_path,
    probe_key,
    update_identity,
    variant_id,
    probe_command,
    probe_pattern,
    update_type,
    update_target,
    asset_pattern,
    update_download_url,
    update_executable,
    upstream_url,
    components_json,
) = sys.argv[1:20]

registration = {
    "app_version": app_version,
    "update_identity": update_identity or app_version,
    "upstream": {
        "type": upstream_type,
    },
    "update_method": update_method,
}

if variant_id:
    registration["variant_id"] = variant_id

if update_type:
    registration["update_recipe"] = {
        "type": update_type,
    }

    if update_target:
        registration["update_recipe"]["target"] = update_target

    if asset_pattern:
        registration["update_recipe"]["asset_pattern"] = asset_pattern

    if update_download_url:
        registration["update_recipe"]["download_url"] = update_download_url

    if update_executable:
        registration["update_recipe"]["executable"] = (
            update_executable.lower()
            in ("1", "true", "yes")
        )

    if components_json:
        components = json.loads(components_json)

        if not isinstance(components, list):
            raise SystemExit(
                "components_json must contain a list"
            )

        registration["update_recipe"]["components"] = components

if owner:
    registration["upstream"]["owner"] = owner

if repo:
    registration["upstream"]["repo"] = repo

if upstream_url:
    registration["upstream"]["url"] = upstream_url

if probe_type:
    registration["version_probe"] = {
        "type": probe_type,
    }

    if probe_path:
        registration["version_probe"]["path"] = probe_path

    if probe_key:
        registration["version_probe"]["key"] = probe_key

    if probe_command:
        registration["version_probe"]["command"] = probe_command

    if probe_pattern:
        registration["version_probe"]["pattern"] = probe_pattern

print(
    "__BUA_REGISTER__="
    + json.dumps(
        registration,
        separators=(",", ":")
    )
)
PYBUAREG
}
export -f bua_register
"""


def get_package_state(app_name: str) -> Dict:
    """Return saved package metadata for one app."""
    state = load_package_state()
    package = state.get("packages", {}).get(app_name, {})

    if isinstance(package, dict):
        return package

    return {}


def set_package_state(app_name: str, package_data: Dict):
    """Create or replace package metadata for one installed BUA app."""
    state = load_package_state()
    packages = state.setdefault("packages", {})

    existing = packages.get(app_name, {})
    if not isinstance(existing, dict):
        existing = {}

    merged = dict(existing)
    merged.update(package_data)

    if "installed_at" not in merged:
        merged["installed_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    merged["updated_at"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    packages[app_name] = merged
    save_package_state(state)


def remove_package_state(app_name: str):
    """Remove package metadata after a BUA-managed uninstall."""
    state = load_package_state()
    packages = state.setdefault("packages", {})

    if app_name in packages:
        del packages[app_name]
        save_package_state(state)


def get_installer_source_url(install_cmd: str) -> str | None:
    """Extract the primary HTTP(S) installer URL from a BUA install command."""
    if not install_cmd:
        return None

    match = re.search(r'https?://[^\s\'"]+', install_cmd)
    if not match:
        return None

    return match.group(0)


def fetch_remote_bytes(url: str, timeout: int = 20) -> bytes | None:
    """Download raw remote content used to calculate a BUA package revision."""
    if not url:
        return None

    try:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "BUA-Installer",
                "Cache-Control": "no-cache",
            }
        )

        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.read()

    except Exception as e:
        print(f"Error fetching package source {url}: {e}")
        return None


def calculate_package_revision_from_bytes(data: bytes) -> str | None:
    """Return deterministic SHA-256 revision for package source content."""
    if data is None:
        return None

    import hashlib
    return hashlib.sha256(data).hexdigest()


def get_remote_package_revision(app_name: str) -> Dict:
    """
    Calculate the current BUA package revision for one app.

    Returns:
        {
            "source": "...",
            "revision": "...",
            "supported": True/False,
            "error": None/"..."
        }
    """
    cmd = APPS.get(app_name, "")
    source_url = get_installer_source_url(cmd)

    result = {
        "source": source_url,
        "revision": None,
        "supported": False,
        "error": None,
    }

    if not source_url:
        result["error"] = "No HTTP installer source"
        return result

    data = fetch_remote_bytes(source_url)

    if data is None:
        result["error"] = "Unable to download installer source"
        return result

    revision = calculate_package_revision_from_bytes(data)

    if not revision:
        result["error"] = "Unable to calculate package revision"
        return result

    result["revision"] = revision
    result["supported"] = True
    return result


def record_current_package_revision(
    app_name: str,
    update_method: str = "reinstall",
    app_version: str | None = None
) -> bool:
    """
    Record the currently published BUA package revision as the installed baseline.

    This does NOT install or update the app. It only records package metadata.
    """
    remote = get_remote_package_revision(app_name)

    if not remote.get("supported"):
        return False

    package_data = {
        "package_revision": remote["revision"],
        "installer_source": remote["source"],
        "update_method": update_method,
    }

    if app_version:
        package_data["app_version"] = app_version

    set_package_state(app_name, package_data)
    return True



def get_github_commit_at_or_before(
    owner: str,
    repo: str,
    branch: str,
    path: str,
    date_str: str
) -> Dict:
    """
    Find the newest GitHub commit touching `path` at or before a local
    BUA installation timestamp.

    Returns:
        {
            "sha": "...",
            "committed_at": "...",
            "error": None/"..."
        }
    """
    result = {
        "sha": None,
        "committed_at": None,
        "error": None,
    }

    try:
        # BUA history timestamps are written in the Batocera machine's
        # local timezone. Convert that local time to UTC for GitHub.
        local_dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M:%S")
        utc_dt = local_dt.astimezone(timezone.utc)
        until = utc_dt.strftime("%Y-%m-%dT%H:%M:%SZ")

        import urllib.parse

        query = urllib.parse.urlencode({
            "path": path,
            "sha": branch,
            "until": until,
            "per_page": 1,
        })

        api_url = (
            f"https://api.github.com/repos/{owner}/{repo}/commits?"
            + query
        )

        req = urllib.request.Request(
            api_url,
            headers={
                "User-Agent": "BUA-Installer",
                "Accept": "application/vnd.github+json",
            }
        )

        with urllib.request.urlopen(req, timeout=20) as response:
            commits = json.loads(response.read().decode("utf-8"))

        if not isinstance(commits, list) or not commits:
            result["error"] = "No historical commit found"
            return result

        commit = commits[0]
        sha = commit.get("sha")

        committed_at = (
            commit.get("commit", {})
                  .get("committer", {})
                  .get("date")
        )

        if not sha:
            result["error"] = "Historical commit has no SHA"
            return result

        result["sha"] = sha
        result["committed_at"] = committed_at
        return result

    except Exception as e:
        result["error"] = str(e)
        return result


def get_historical_package_revision(
    app_name: str,
    install_date: str
) -> Dict:
    """
    Reconstruct the BUA installer revision that existed when an app
    was last successfully installed.
    """
    result = {
        "app": app_name,
        "install_date": install_date,
        "source": None,
        "commit_sha": None,
        "committed_at": None,
        "revision": None,
        "supported": False,
        "error": None,
    }

    cmd = APPS.get(app_name, "")
    parsed = parse_github_raw_url(cmd)

    if not parsed:
        result["error"] = "Installer is not a supported GitHub raw source"
        return result

    owner, repo, branch, path = parsed

    commit = get_github_commit_at_or_before(
        owner,
        repo,
        branch,
        path,
        install_date
    )

    if not commit.get("sha"):
        result["error"] = commit.get("error") or "Historical commit not found"
        return result

    sha = commit["sha"]

    historical_url = (
        f"https://raw.githubusercontent.com/"
        f"{owner}/{repo}/{sha}/{path}"
    )

    data = fetch_remote_bytes(historical_url)

    if data is None:
        result["error"] = "Unable to download historical installer"
        return result

    revision = calculate_package_revision_from_bytes(data)

    if not revision:
        result["error"] = "Unable to hash historical installer"
        return result

    result.update({
        "source": historical_url,
        "commit_sha": sha,
        "committed_at": commit.get("committed_at"),
        "revision": revision,
        "supported": True,
    })

    return result



def migrate_package_state_from_history(
    app_name: str,
    update_method: str | None = None
) -> Dict:
    """
    Create package-state metadata for an existing pre-updater BUA install.

    The historical installer revision is reconstructed from the app's
    last successful BUA installation date. Existing tracked packages
    are never overwritten.
    """
    existing = get_package_state(app_name)

    if existing.get("package_revision"):
        return {
            "status": "already_tracked",
            "app": app_name,
            "package": existing,
            "error": None,
        }

    install_date = get_last_install_date(app_name)

    if not install_date:
        return {
            "status": "no_history",
            "app": app_name,
            "package": {},
            "error": "No successful BUA installation history",
        }

    historical = get_historical_package_revision(
        app_name,
        install_date
    )

    if not historical.get("supported"):
        return {
            "status": "unsupported",
            "app": app_name,
            "package": {},
            "error": historical.get("error"),
        }

    cmd = APPS.get(app_name, "")
    current_source = get_installer_source_url(cmd)

    if update_method is None:
        update_method = get_update_method(app_name)

    package_data = {
        "package_revision": historical["revision"],
        "installer_source": current_source,
        "installed_commit_sha": historical.get("commit_sha"),
        "installed_commit_date": historical.get("committed_at"),
        "installed_at": install_date,
        "baseline_method": "historical_bua_history",
        "update_method": update_method,
    }

    set_package_state(app_name, package_data)

    return {
        "status": "migrated",
        "app": app_name,
        "package": package_data,
        "error": None,
    }




REGISTRATION_SNAPSHOT_CACHE: Dict[str, Dict] = {}

def _build_dev_registration_adapters() -> Dict[str, str]:
    import json

    base = Path("/userdata/system/add-ons/bua/updater")
    converted = base / "converted"
    manifest_path = (
        base
        / "catalog/global/global-update-manifest.json"
    )

    priority = {
        "vendor-api": 10,
        "vendor-web": 20,
        "sourceforge": 30,
        "itch": 40,
        "codeberg": 45,
        "special-parents": 50,
        "github-filtered": 60,
        "trusted-github-parents": 70,
        "github-web-parents": 80,
        "github-release-api": 90,
        "github-release-download": 100,
        "flathub": 105,
        "web-wrappers": 110,
        "variant-packages": 115,
        "integration-packages": 120,
    }

    def norm(value: str) -> str:
        return re.sub(
            r"[^a-z0-9]+",
            "",
            str(value).lower(),
        )

    try:
        manifest = json.loads(
            manifest_path.read_text(
                encoding="utf-8",
            )
        )
    except Exception:
        return {}

    scripts = []

    for path in converted.rglob("*.sh"):
        try:
            script_text = path.read_text(
                encoding="utf-8",
                errors="ignore",
            )
        except Exception:
            continue

        if "BUA_REGISTRATION_ONLY" not in script_text:
            continue

        rel = path.relative_to(converted)
        family = rel.parts[0]

        scripts.append({
            "path": str(path),
            "family": family,
            "score": priority.get(family, 999),
            "keys": {
                norm(path.stem),
                norm(path.parent.name),
            },
        })

    result: Dict[str, str] = {}

    for entry in manifest.get("apps", []):
        app = str(entry.get("app") or "").strip()

        if not app:
            continue

        keys = {norm(app)}

        installer_path = str(
            entry.get("installer_path") or ""
        ).strip()

        if installer_path:
            ip = Path(installer_path)
            keys.add(norm(ip.stem))
            keys.add(norm(ip.parent.name))

        hits = [
            item
            for item in scripts
            if keys & item["keys"]
        ]

        if app == "Wine Dependencies x86":
            hits = [
                item
                for item in hits
                if "dependencies32" in item["path"]
            ]

        elif app == "Wine Dependencies x64":
            hits = [
                item
                for item in hits
                if "dependencies64" in item["path"]
            ]

        if not hits:
            continue

        hits.sort(
            key=lambda item: (
                item["score"],
                item["path"],
            )
        )

        result[app] = hits[0]["path"]

    return result


DEV_REGISTRATION_ADAPTERS: Dict[str, str] = (
    _build_dev_registration_adapters()
)

DEV_REGISTRATION_ADAPTERS["Wine Manager"] = (
    "/userdata/system/add-ons/bua/updater/converted/"
    "integration-packages/wine-manager/061-Wine_Manager.sh"
)


def get_dev_registration_adapter(app_name: str) -> str | None:
    path = DEV_REGISTRATION_ADAPTERS.get(app_name)

    if not path:
        return None

    if not os.path.isfile(path):
        return None

    return path



def get_global_manifest_entry(app_name: str) -> Dict | None:
    """
    Return the canonical global-manifest entry for one live BUA app.
    """
    manifest_path = Path(
        "/userdata/system/add-ons/bua/updater/catalog/global/"
        "global-update-manifest.json"
    )

    try:
        payload = json.loads(
            manifest_path.read_text(
                encoding="utf-8"
            )
        )
    except Exception:
        return None

    items = payload.get("apps", [])

    if not isinstance(items, list):
        return None

    # Preferred join: exact live catalog app name.
    for item in items:
        if (
            isinstance(item, dict)
            and item.get("app") == app_name
        ):
            return item

    return None


def _generic_payload_url_from_manifest(
    entry: Dict
) -> str | None:
    """
    Select the most likely actual application payload URL from
    one canonical manifest entry.

    This deliberately ignores artwork, localhost reload hooks,
    and the BUA installer itself.
    """
    if not isinstance(entry, dict):
        return None

    installer_url = str(
        entry.get("installer_url")
        or ""
    ).strip()

    candidates = []

    for key in (
        "external_urls",
        "all_urls",
    ):
        values = entry.get(key) or []

        if not isinstance(values, list):
            continue

        for value in values:
            url = str(value or "").strip()

            if not url:
                continue

            if url in candidates:
                continue

            candidates.append(url)

    def score(url: str):
        lower = url.lower()

        if (
            "127.0.0.1" in lower
            or "localhost" in lower
        ):
            return -10000

        if (
            installer_url
            and url == installer_url
        ):
            return -10000

        path = lower.split("?", 1)[0]

        # Artwork and metadata are not application payloads.
        if path.endswith((
            ".png",
            ".jpg",
            ".jpeg",
            ".gif",
            ".webp",
            ".svg",
            ".ico",
            ".xml",
        )):
            return -10000

        value = 0

        payload_suffixes = (
            ".appimage",
            ".wsquashfs",
            ".squashfs",
            ".zip",
            ".7z",
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

        if path.endswith(payload_suffixes):
            value += 100

        if "/releases/download/" in lower:
            value += 80

        if "drive.usercontent.google.com/" in lower:
            value += 70

        if "sourceforge.net/" in lower:
            value += 60

        if url in (
            entry.get("external_urls")
            or []
        ):
            value += 20

        return value

    usable = [
        (score(url), url)
        for url in candidates
        if score(url) > -10000
    ]

    if not usable:
        return None

    usable.sort(
        key=lambda pair: pair[0],
        reverse=True,
    )

    return usable[0][1]


def _http_payload_identity(
    url: str
) -> Dict:
    """
    Derive a stable identity from remote payload metadata without
    downloading the complete application.

    Probe order:
      1. HEAD
      2. one-byte ranged GET

    The signed redirect destination is intentionally NOT included
    in the identity. Only the stable catalog payload URL is used.
    """
    import hashlib
    import email.utils

    result = {
        "supported": False,
        "url": url,
        "identity": None,
        "display_version": None,
        "etag": None,
        "last_modified": None,
        "size": None,
        "filename": None,
        "error": None,
    }

    def read_headers(method, ranged=False):
        headers = {
            "User-Agent":
                "BUA-Global-Updater/1",
            "Accept":
                "*/*",
        }

        if ranged:
            headers["Range"] = "bytes=0-0"

        req = urllib.request.Request(
            url,
            headers=headers,
            method=method,
        )

        with urllib.request.urlopen(
            req,
            timeout=30,
        ) as response:
            h = response.headers

            etag = (
                h.get("ETag")
                or ""
            ).strip()

            modified = (
                h.get("Last-Modified")
                or ""
            ).strip()

            disposition = (
                h.get("Content-Disposition")
                or ""
            ).strip()

            content_range = (
                h.get("Content-Range")
                or ""
            ).strip()

            length = (
                h.get("Content-Length")
                or ""
            ).strip()

            total_size = None

            if content_range:
                match = re.search(
                    r"/(\d+)\s*$",
                    content_range,
                )

                if match:
                    total_size = int(
                        match.group(1)
                    )

            if (
                total_size is None
                and length.isdigit()
            ):
                parsed_length = int(length)

                # Ignore zero-length HEAD oddities and the
                # one-byte body from our Range probe.
                if parsed_length > 1:
                    total_size = parsed_length

            filename = None

            if disposition:
                match = re.search(
                    r'filename\*?='
                    r'(?:UTF-8\'\')?'
                    r'"?([^";]+)',
                    disposition,
                    re.I,
                )

                if match:
                    filename = (
                        match.group(1)
                        .strip()
                        .strip('"')
                    )

            return {
                "etag": etag or None,
                "last_modified":
                    modified or None,
                "size": total_size,
                "filename": filename,
            }

    metadata = None

    try:
        metadata = read_headers(
            "HEAD",
            ranged=False,
        )
    except Exception:
        metadata = None

    def useful(m):
        if not isinstance(m, dict):
            return False

        return bool(
            m.get("etag")
            or m.get("last_modified")
            or m.get("size")
        )

    # Google Drive and some CDNs provide useful metadata only
    # when an actual byte range is requested.
    if not useful(metadata):
        try:
            metadata = read_headers(
                "GET",
                ranged=True,
            )
        except Exception as exc:
            result["error"] = str(exc)
            return result

    # Even when HEAD supplies only a weak size, a range request
    # may expose Last-Modified or Content-Range. Prefer the richer
    # result when possible.
    elif not (
        metadata.get("etag")
        or metadata.get("last_modified")
    ):
        try:
            ranged = read_headers(
                "GET",
                ranged=True,
            )

            if useful(ranged):
                metadata = ranged
        except Exception:
            pass

    if not useful(metadata):
        result["error"] = (
            "Payload server exposed no stable "
            "identity metadata"
        )
        return result

    etag = metadata.get("etag")
    modified = metadata.get(
        "last_modified"
    )
    size = metadata.get("size")
    filename = metadata.get(
        "filename"
    )

    # At minimum require something stronger than URL alone.
    if not (
        etag
        or modified
        or size
    ):
        result["error"] = (
            "Payload identity metadata incomplete"
        )
        return result

    identity_material = {
        "url": url,
        "etag": etag,
        "last_modified": modified,
        "size": size,
        "filename": filename,
    }

    encoded = json.dumps(
        identity_material,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

    digest = hashlib.sha256(
        encoded
    ).hexdigest()

    # Human-readable display value. This is deliberately
    # called a payload version rather than pretending it is
    # an upstream semantic application version.
    display_version = None

    if modified:
        try:
            dt = email.utils.parsedate_to_datetime(
                modified
            )

            display_version = (
                "payload@"
                + dt.strftime("%Y-%m-%d")
            )
        except Exception:
            display_version = (
                "payload@"
                + modified
            )

    if not display_version:
        display_version = (
            "payload@"
            + digest[:12]
        )

    result.update({
        "supported": True,
        "identity":
            "payload:" + digest,
        "display_version":
            display_version,
        "etag": etag,
        "last_modified": modified,
        "size": size,
        "filename": filename,
        "error": None,
    })

    return result


def get_generic_catalog_registration_snapshot(
    app_name: str
) -> Dict:
    """
    Generic install/update identity fallback for catalog apps that
    do not implement BUA_REGISTRATION_ONLY.

    It does not install or alter anything.
    """
    result = {
        "supported": False,
        "app": app_name,
        "source": None,
        "registration": None,
        "lines": [],
        "error": None,
    }

    entry = get_global_manifest_entry(
        app_name
    )

    if not entry:
        result["error"] = (
            "No global manifest entry"
        )
        return result

    payload_url = (
        _generic_payload_url_from_manifest(
            entry
        )
    )

    if not payload_url:
        result["error"] = (
            "No generic application payload URL "
            "could be resolved"
        )
        return result

    declared_checksums = (
        entry.get("declared_payload_sha256")
        or {}
    )

    checksum_identity = None

    if isinstance(
        declared_checksums,
        dict,
    ):
        import platform

        machine = platform.machine().lower()

        if machine in (
            "x86_64",
            "amd64",
        ):
            checksum_identity = (
                declared_checksums.get(
                    "x86_64"
                )
                or declared_checksums.get(
                    "generic"
                )
            )

        elif machine in (
            "aarch64",
            "arm64",
        ):
            checksum_identity = (
                declared_checksums.get(
                    "arm64"
                )
                or declared_checksums.get(
                    "generic"
                )
            )

        else:
            checksum_identity = (
                declared_checksums.get(
                    "generic"
                )
            )

    if checksum_identity:
        checksum_identity = str(
            checksum_identity
        ).lower().strip()

        identity = {
            "supported": True,
            "identity":
                "sha256:"
                + checksum_identity,
            "display_version":
                "sha256@"
                + checksum_identity[:12],
            "etag": None,
            "last_modified": None,
            "size": None,
            "filename": None,
            "error": None,
        }

    else:
        identity = _http_payload_identity(
            payload_url
        )

    if not identity.get("supported"):
        result["error"] = (
            identity.get("error")
            or "Unable to identify payload"
        )
        return result

    registration = {
        "app_version":
            identity["display_version"],
        "update_identity":
            identity["identity"],
        "update_method":
            "custom",
        "upstream": {
            "type":
                entry.get("source_family")
                or "generic_http",
            "owner":
                entry.get("github_owner"),
            "repo":
                entry.get("github_repo"),
            "url":
                payload_url,
        },
    }

    result.update({
        "supported": True,
        "source": payload_url,
        "registration": registration,
        "error": None,
    })

    return result


def get_catalog_registration_snapshot(
    app_name: str,
    use_cache: bool = True,
) -> Dict:
    """
    Ask the app's current BUA installer for its latest upstream identity
    without installing or modifying anything.

    The installer itself acts as the parent-source adapter.
    """
    if use_cache and app_name in REGISTRATION_SNAPSHOT_CACHE:
        return REGISTRATION_SNAPSHOT_CACHE[app_name]

    result_data = {
        "supported": False,
        "app": app_name,
        "source": None,
        "registration": None,
        "lines": [],
        "error": None,
    }

    install_cmd = APPS.get(app_name)

    if not install_cmd:
        result_data["error"] = "No installer command"
        return result_data

    source_url = get_installer_source_url(
        install_cmd
    )

    dev_adapter = get_dev_registration_adapter(
        app_name
    )

    if dev_adapter:
        result_data["source"] = dev_adapter

        try:
            installer_text = Path(
                dev_adapter
            ).read_text(
                encoding="utf-8",
                errors="ignore",
            )
        except Exception as exc:
            result_data["error"] = (
                "Could not read dev registration adapter: "
                f"{exc}"
            )
            return result_data

    else:
        result_data["source"] = source_url

        if not source_url:
            result_data["error"] = (
                "Installer source is not registration-compatible"
            )
            return result_data

        try:
            installer_bytes = fetch_remote_bytes(
                source_url
            )
        except Exception as exc:
            result_data["error"] = str(exc)
            return result_data

        if not installer_bytes:
            result_data["error"] = "Installer source was empty"
            return result_data

        if isinstance(installer_bytes, bytes):
            installer_text = installer_bytes.decode(
                "utf-8",
                "ignore",
            )
        else:
            installer_text = str(installer_bytes)

    # Never execute an installer as an update probe unless it has
    # explicitly opted into the metadata-only contract.
    if "BUA_REGISTRATION_ONLY" not in installer_text:
        generic = get_generic_catalog_registration_snapshot(
            app_name
        )

        if generic.get("supported"):
            if use_cache:
                REGISTRATION_SNAPSHOT_CACHE[
                    app_name
                ] = generic

            return generic

        result_data["error"] = (
            generic.get("error")
            or
            "Installer does not advertise "
            "registration-only support"
        )

        if use_cache:
            REGISTRATION_SNAPSHOT_CACHE[
                app_name
            ] = result_data

        return result_data

    helper = get_bua_registration_shell_helper()

    installed_package = (
        get_package_state(app_name)
        or {}
    )

    installed_variant = str(
        installed_package.get("variant_id")
        or ""
    ).strip()

    # Package-state variant IDs were normalized on write, but validate
    # again before placing one into a shell environment.
    if not re.fullmatch(
        r"[A-Za-z0-9._-]{0,64}",
        installed_variant,
    ):
        installed_variant = ""

    script = (
        helper
        + "\n"
        + "export BUA_REGISTRATION_ONLY=1\n"
        + (
            "export BUA_INSTALLED_VARIANT='"
            + installed_variant
            + "'\n"
        )
        + installer_text
        + "\n"
    )

    try:
        process = subprocess.run(
            ["bash"],
            input=script,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=45,
        )
    except Exception as exc:
        result_data["error"] = str(exc)
        return result_data

    lines = process.stdout.splitlines()
    result_data["lines"] = lines

    if process.returncode != 0:
        result_data["error"] = (
            f"Registration-only mode exited "
            f"{process.returncode}"
        )

        return result_data

    registration = extract_install_registration(
        lines
    )

    if not registration:
        result_data["error"] = (
            "Installer emitted no registration metadata"
        )
        return result_data

    normalized = normalize_install_registration(
        registration
    )

    if not normalized:
        result_data["error"] = (
            "Installer emitted invalid registration metadata"
        )
        return result_data

    if not normalized.get("app_version"):
        result_data["error"] = (
            "Installer registration has no app_version"
        )
        return result_data

    # Converted integration adapters may only describe the
    # BUA-packaged integration artifact rather than the real
    # upstream application payload. Those are not valid parent-
    # source identities for the global updater.
    upstream = normalized.get("upstream") or {}

    upstream_type = str(
        upstream.get("type") or ""
    ).strip().lower()

    upstream_owner = str(
        upstream.get("owner") or ""
    ).strip().lower()

    if (
        upstream_type == "integration_asset"
        or upstream_owner == "bua"
    ):
        generic = get_generic_catalog_registration_snapshot(
            app_name
        )

        if generic.get("supported"):
            if use_cache:
                REGISTRATION_SNAPSHOT_CACHE[
                    app_name
                ] = generic

            return generic

    result_data.update({
        "supported": True,
        "registration": normalized,
        "error": None,
    })

    if use_cache:
        REGISTRATION_SNAPSHOT_CACHE[app_name] = result_data

    return result_data


def migrate_registered_metadata(app_name: str) -> bool:
    """
    Adopt safe updater metadata for an existing BUA install.

    Important:
    A registration-only snapshot describes the CURRENT upstream release,
    not necessarily the version already installed locally.

    Therefore adoption may copy source/probe/policy metadata, but it must
    never stamp the latest upstream app_version or update_identity onto an
    existing installation unless the local installed identity is known.
    """
    package = get_package_state(app_name)

    if not package:
        return False

    snapshot = get_catalog_registration_snapshot(
        app_name
    )

    if not snapshot.get("supported"):
        return False

    registration = (
        snapshot.get("registration") or {}
    )

    adopted = {}

    upstream = registration.get("upstream")

    if isinstance(upstream, dict) and upstream:
        adopted["upstream"] = upstream

    version_probe = registration.get("version_probe")

    if isinstance(version_probe, dict) and version_probe:
        adopted["version_probe"] = version_probe

    update_method = registration.get("update_method")

    if update_method in (
        "reinstall",
        "custom",
        "unsupported",
    ):
        adopted["update_method"] = update_method

    if not adopted:
        return False

    adopted["registration_source"] = "installer"
    adopted["registration_schema"] = 2

    # Only retain an installed identity that already existed.
    # Never manufacture it from the latest upstream snapshot.
    if package.get("app_version"):
        adopted["app_version"] = package["app_version"]

    if package.get("update_identity"):
        adopted["update_identity"] = package["update_identity"]

    set_package_state(
        app_name,
        adopted,
    )

    print(
        f"[BUA] Adopted updater metadata for "
        f"{app_name} without changing installed identity"
    )

    return True


def ensure_package_tracking(app_name: str) -> Dict:
    """
    Ensure an existing BUA install has package revision metadata
    and, where supported, upstream application registration metadata.

    Safe to call repeatedly.
    """
    existing = get_package_state(app_name)

    if not existing.get("package_revision"):
        result = migrate_package_state_from_history(app_name)

        if result.get("status") not in ("tracked", "migrated"):
            return result

        existing = get_package_state(app_name)

    if existing and not existing.get("upstream"):
        migrate_registered_metadata(app_name)
        existing = get_package_state(app_name)

    return {
        "status": "tracked",
        "app": app_name,
        "package": existing,
        "error": None,
    }


def package_update_status(app_name: str) -> Dict:
    """
    Compare saved installed BUA revision against the currently published revision.

    Status values:
        untracked
        current
        update_available
        unsupported
        error
    """
    installed = get_package_state(app_name)
    remote = get_remote_package_revision(app_name)

    if not remote.get("supported"):
        return {
            "status": "unsupported",
            "needs_update": False,
            "installed_revision": installed.get("package_revision"),
            "remote_revision": None,
            "source": remote.get("source"),
            "error": remote.get("error"),
        }

    installed_revision = installed.get("package_revision")
    remote_revision = remote.get("revision")

    if not installed_revision:
        status = "untracked"
        needs_update = False
    elif installed_revision != remote_revision:
        status = "update_available"
        needs_update = True
    else:
        status = "current"
        needs_update = False

    return {
        "status": status,
        "needs_update": needs_update,
        "installed_revision": installed_revision,
        "remote_revision": remote_revision,
        "source": remote.get("source"),
        "error": None,
    }


def load_history() -> Dict:
    """Load installation history from file"""
    try:
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, 'r') as f:
                return json.load(f)
    except Exception as e:
        print(f"Error loading history: {e}")
    return {}

def save_history(history: Dict):
    """Save installation history to file"""
    try:
        os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
        with open(HISTORY_FILE, 'w') as f:
            json.dump(history, f, indent=2)
    except Exception as e:
        print(f"Error saving history: {e}")

def mark_installed(app_name: str, success: bool):
    """Mark an app as installed in history"""
    history = load_history()
    if app_name not in history:
        history[app_name] = []
    
    history[app_name].append({
        'date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'success': success
    })
    save_history(history)

def is_installed(app_name: str) -> bool:
    """Check if app has been successfully installed"""
    history = load_history()
    if app_name in history:
        # Check if any installation was successful
        return any(entry['success'] for entry in history[app_name])
    return False

def scan_installed_addons_directory() -> dict:
    """Scan /userdata/system/add-ons directory for installed apps.
    Returns dict mapping app_name -> directory modification timestamp (or None if not found)."""
    addons_dir = "/userdata/system/add-ons"
    found_apps = {}

    try:
        if not os.path.exists(addons_dir):
            return {}

        # List all items in add-ons directory
        items = os.listdir(addons_dir)

        # Match directory/file names against known app names
        for app_name in APPS.keys():
            dir_path = None
            # Check if app name exists as directory or file
            if app_name in items:
                dir_path = os.path.join(addons_dir, app_name)
            # Also check with common variations
            elif app_name.replace(' ', '_') in items:
                dir_path = os.path.join(addons_dir, app_name.replace(' ', '_'))
            elif app_name.replace(' ', '-') in items:
                dir_path = os.path.join(addons_dir, app_name.replace(' ', '-'))

            if dir_path and os.path.exists(dir_path):
                try:
                    # Get modification time of the directory
                    mtime = os.path.getmtime(dir_path)
                    found_apps[app_name] = mtime
                except Exception:
                    found_apps[app_name] = None
    except Exception:
        pass

    return found_apps

def get_last_install_date(app_name: str) -> str:
    """Get the last successful installation date"""
    history = load_history()
    if app_name in history:
        successful = [e for e in history[app_name] if e['success']]
        if successful:
            return successful[-1]['date']
    return None

def mark_uninstalled(app_name: str):
    """Remove an app from installation history"""
    history = load_history()
    if app_name in history:
        del history[app_name]
        save_history(history)

# Custom uninstall commands for apps that don't follow the standard pattern
CUSTOM_UNINSTALL: Dict[str, str] = {
    "Desktop For Batocera": "/userdata/system/configs/bat-drl/Remover_Desktop.sh",
}

def get_uninstall_command(install_cmd: str, app_name: str = None) -> str:
    """Convert an installation command to an uninstall command.

    First checks CUSTOM_UNINSTALL dictionary for app-specific uninstall scripts.
    Otherwise, replaces .sh with _uninstall.sh in the URL.

    Example:
    https://.../ 7zip/7zip.sh -> https://.../7zip/7zip_uninstall.sh
    """
    # Check for custom uninstall command first
    if app_name and app_name in CUSTOM_UNINSTALL:
        return CUSTOM_UNINSTALL[app_name]

    import re
    # Find the .sh URL in the curl command
    match = re.search(r'(https://[^\s]+)\.sh', install_cmd)
    if match:
        base_url = match.group(1)
        # Replace .sh with _uninstall.sh
        uninstall_url = f"{base_url}_uninstall.sh"
        # Create the curl command
        return f"curl -Ls {uninstall_url} | bash"
    return None

# ------------------------------
# Apps and Install Commands
# ------------------------------

# Base URL for BUA repository scripts
BUA_BASE_URL = "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/refs/heads/main"

def bua(path: str) -> str:
    """Helper to build BUA install command from relative path"""
    return f"curl -L {BUA_BASE_URL}/{path} | bash"


# ------------------------------
# BUA Update Policies
# ------------------------------
#
# reinstall:
#   Re-running the BUA installer is considered the approved update path.
#
# custom:
#   This add-on needs a dedicated BUA-controlled updater before automatic
#   updates should be enabled.
#
# unsupported:
#   No automatic BUA update path has been approved yet.
#

def read_json_key(path: str, key: str) -> str | None:
    """Read one top-level value from a JSON file."""
    try:
        with open(path, "r") as f:
            data = json.load(f)

        value = data.get(key)

        if value is None:
            return None

        return str(value).strip()

    except Exception as e:
        print(f"[BUA] Version read error for {path}: {e}")
        return None


def read_version_probe(probe: Dict) -> str | None:
    """Read an installed application version using registered probe metadata."""
    if not isinstance(probe, dict):
        return None

    probe_type = probe.get("type")

    if probe_type == "json":
        return read_json_key(
            probe.get("path", ""),
            probe.get("key", "")
        )

    if probe_type == "command":
        command = probe.get("command")

        if not command:
            return None

        try:
            result = subprocess.run(
                command,
                shell=True,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=20,
            )

            if result.returncode != 0:
                return None

            output = result.stdout.strip()

            match = re.search(
                probe.get("pattern", r"(.+)"),
                output,
            )

            if not match:
                return None

            return match.group(1).strip()

        except Exception:
            return None

    return None


def get_registered_version_metadata(app_name: str) -> Dict:
    """Return installer-registered update/version metadata."""
    package = get_package_state(app_name)

    return {
        "app_version": package.get("app_version"),
        "update_identity": (
            package.get("update_identity")
            or package.get("app_version")
        ),
        "upstream": package.get("upstream"),
        "version_probe": package.get("version_probe"),
        "registration_source": package.get("registration_source"),
        "registration_schema": package.get("registration_schema"),
    }


def get_installed_app_version(app_name: str) -> str | None:
    """
    Return the actual installed app version when possible.

    Prefer the registered local probe. Fall back to the version BUA
    recorded when the installer completed.
    """
    registered = get_registered_version_metadata(app_name)

    probe = registered.get("version_probe")

    if isinstance(probe, dict):
        probed = read_version_probe(probe)

        if probed:
            return probed

    recorded = registered.get("app_version")

    if recorded:
        return str(recorded).strip()

    return None


def get_latest_github_release_version(
    owner: str,
    repo: str
) -> str | None:
    """Return tag_name from the repository's latest GitHub release."""
    try:
        api_url = (
            f"https://api.github.com/repos/"
            f"{owner}/{repo}/releases/latest"
        )

        req = urllib.request.Request(
            api_url,
            headers={
                "User-Agent": "BUA-Installer",
                "Accept": "application/vnd.github+json",
                "Cache-Control": "no-cache",
            }
        )

        with urllib.request.urlopen(req, timeout=20) as response:
            release = json.loads(
                response.read().decode("utf-8")
            )

        tag = release.get("tag_name")

        if not tag:
            return None

        return str(tag).strip()

    except Exception as e:
        print(
            f"[BUA] GitHub release version error "
            f"for {owner}/{repo}: {e}"
        )
        return None


def get_latest_version_from_upstream(upstream: Dict) -> str | None:
    """Resolve latest app version from registered upstream metadata."""
    if not isinstance(upstream, dict):
        return None

    upstream_type = upstream.get("type")

    if upstream_type == "github_release":
        owner = upstream.get("owner")
        repo = upstream.get("repo")

        if not owner or not repo:
            return None

        return get_latest_github_release_version(
            str(owner),
            str(repo)
        )

    return None


def get_latest_app_version(app_name: str) -> str | None:
    """Return latest upstream version from installer registration."""
    registered = get_registered_version_metadata(app_name)

    upstream = registered.get("upstream")

    if not isinstance(upstream, dict):
        return None

    return get_latest_version_from_upstream(upstream)


def resolve_parent_update_asset(app_name: str) -> Dict:
    """
    Resolve the latest application payload directly from its parent source.

    This does not run the BUA installer.
    """
    import fnmatch

    result = {
        "supported": False,
        "url": None,
        "target": None,
        "executable": False,
        "registration": None,
        "recipe": None,
        "error": None,
    }

    snapshot = get_catalog_registration_snapshot(
        app_name,
        use_cache=False,
    )

    if not snapshot.get("supported"):
        result["error"] = snapshot.get("error")
        return result

    registration = snapshot.get("registration") or {}

    # Execution metadata comes from the canonical global recipe
    # registry. Parent/source identity continues to come live from
    # the registration adapter.
    recipe = {}

    recipe_manifest = Path(
        "/userdata/system/add-ons/bua/updater/catalog/global/"
        "app-update-recipes.json"
    )

    try:
        recipe_data = json.loads(
            recipe_manifest.read_text(
                encoding="utf-8",
            )
        )

        canonical = (
            recipe_data.get("apps", {})
            .get(app_name, {})
        )

        if isinstance(canonical, dict):
            canonical_type = str(
                canonical.get("update_type") or ""
            ).strip()

            if canonical_type:
                recipe["type"] = canonical_type

            for key in (
                "target",
                "asset_pattern",
                "asset_exclude_pattern",
                "download_url",
                "archive_subpath",
                "archive_format",
                "executable",
            ):
                if key in canonical:
                    recipe[key] = canonical[key]

            bundle_members = canonical.get("bundle_members")
            if isinstance(bundle_members, list):
                recipe["bundle_members"] = bundle_members

            components = canonical.get("components")
            if isinstance(components, list):
                recipe["components"] = components

    except Exception as exc:
        result["error"] = (
            "Could not read global update recipe: "
            f"{exc}"
        )
        return result

    # A future adapter may provide additional live recipe metadata.
    # Merge it over the canonical defaults.
    adapter_recipe = registration.get("update_recipe")

    if isinstance(adapter_recipe, dict):
        recipe.update(adapter_recipe)

    if not recipe:
        result["error"] = "No parent-source update recipe"
        return result

    if recipe.get("type") not in (
        "replace_file",
        "replace_archive",
        "replace_bundle",
        "multi_component",
    ):
        result["error"] = (
            "Unsupported update recipe: "
            + str(recipe.get("type") or "")
        )
        return result

    target = str(recipe.get("target") or "").strip()

    if not target.startswith("/userdata/"):
        result["error"] = "Unsafe or missing update target"
        return result

    if recipe.get("type") == "multi_component":
        components = recipe.get("components") or []

        if not isinstance(components, list) or not components:
            result["error"] = "multi_component has no components"
            return result

        for index, component in enumerate(components):
            if not isinstance(component, dict):
                result["error"] = (
                    f"Invalid multi_component entry {index + 1}"
                )
                return result

            component_type = str(
                component.get("type") or "replace_file"
            ).strip()

            if component_type != "replace_file":
                result["error"] = (
                    "Unsupported multi_component member type: "
                    + component_type
                )
                return result

            component_url = str(
                component.get("url") or ""
            ).strip()

            component_target = str(
                component.get("target") or ""
            ).strip()

            if not component_url:
                result["error"] = (
                    f"Component {index + 1} has no URL"
                )
                return result

            if not component_target.startswith("/userdata/"):
                result["error"] = (
                    f"Component {index + 1} has unsafe target"
                )
                return result

        result.update({
            "supported": True,
            "url": "",
            "target": target,
            "executable": False,
            "registration": registration,
            "recipe": recipe,
        })

        return result

    download_url = str(
        recipe.get("download_url") or ""
    ).strip()

    upstream = registration.get("upstream") or {}

    # Any registration adapter may expose the current resolved parent
    # payload directly. This is source-family agnostic.
    if not download_url:
        download_url = str(
            upstream.get("url") or ""
        ).strip()

    if not download_url:
        if upstream.get("type") != "github_release":
            result["error"] = (
                "Update recipe requires a resolved parent payload URL "
                "or GitHub release metadata"
            )
            return result

        owner = str(upstream.get("owner") or "").strip()
        repo = str(upstream.get("repo") or "").strip()
        pattern = str(
            recipe.get("asset_pattern") or ""
        ).strip()

        exclude_pattern = str(
            recipe.get("asset_exclude_pattern") or ""
        ).strip()

        if not owner or not repo or not pattern:
            result["error"] = "Incomplete GitHub update recipe"
            return result

        try:
            api_url = (
                f"https://api.github.com/repos/"
                f"{owner}/{repo}/releases/latest"
            )

            req = urllib.request.Request(
                api_url,
                headers={
                    "User-Agent": "BUA-Installer",
                    "Accept": "application/vnd.github+json",
                    "Cache-Control": "no-cache",
                },
            )

            with urllib.request.urlopen(
                req,
                timeout=20,
            ) as response:
                release = json.loads(
                    response.read().decode("utf-8")
                )

            for asset in release.get("assets") or []:
                name = str(asset.get("name") or "")
                url = str(
                    asset.get("browser_download_url") or ""
                )

                if not (
                    name
                    and url
                    and fnmatch.fnmatch(name, pattern)
                ):
                    continue

                if (
                    exclude_pattern
                    and fnmatch.fnmatch(
                        name,
                        exclude_pattern,
                    )
                ):
                    continue

                download_url = url
                break

        except Exception as exc:
            result["error"] = (
                f"Parent release lookup failed: {exc}"
            )
            return result

    if not download_url:
        result["error"] = "No matching parent release asset"
        return result

    result.update({
        "supported": True,
        "url": download_url,
        "target": target,
        "executable": bool(
            recipe.get("executable", False)
        ),
        "registration": registration,
        "recipe": recipe,
    })

    return result


def build_parent_update_command(
    app_name: str,
) -> tuple[str | None, str | None]:
    """
    Build one generic parent-source payload update job.

    This NEVER reruns the original BUA installer.
    Reinstall remains a separate repair action.
    """
    import shlex

    resolved = resolve_parent_update_asset(app_name)

    if not resolved.get("supported"):
        return None, resolved.get("error")

    registration = resolved["registration"]
    recipe = resolved.get("recipe") or {}

    recipe_type = str(
        recipe.get("type") or ""
    ).strip()

    url = resolved["url"]
    target = resolved["target"]

    marker = (
        "__BUA_REGISTER__="
        + json.dumps(
            registration,
            sort_keys=True,
            separators=(",", ":"),
        )
    )

    q_url = shlex.quote(url)
    q_target = shlex.quote(target)
    q_marker = shlex.quote(marker)

    if recipe_type == "multi_component":
        components = recipe.get("components") or []

        if not isinstance(components, list) or not components:
            return None, "multi_component has no components"

        clean_components = []

        for index, component in enumerate(components):
            if not isinstance(component, dict):
                return None, (
                    f"Invalid multi_component entry {index + 1}"
                )

            component_type = str(
                component.get("type") or "replace_file"
            ).strip()

            if component_type != "replace_file":
                return None, (
                    "Unsupported multi_component member type: "
                    + component_type
                )

            name = str(
                component.get("name")
                or f"component-{index + 1}"
            ).strip()

            component_url = str(
                component.get("url") or ""
            ).strip()

            component_target = str(
                component.get("target") or ""
            ).strip()

            if not component_url:
                return None, f"{name}: missing URL"

            if not component_target.startswith("/userdata/"):
                return None, f"{name}: unsafe target"

            clean_components.append({
                "name": name,
                "url": component_url,
                "target": component_target,
                "executable": bool(
                    component.get("executable", False)
                ),
            })

        parts = [
            "BUA_PARENT_UPDATE=1",
            "set -e",
            'WORK=$(mktemp -d /tmp/bua-multi-update.XXXXXX)',
            'trap \'rm -rf "$WORK"\' EXIT',
        ]

        # Stage every component before touching installed payloads.
        for index, component in enumerate(clean_components):
            q_name = shlex.quote(component["name"])
            q_component_url = shlex.quote(component["url"])
            staged = shlex.quote(
                f'$WORK/component-{index}'
            )

            # Keep $WORK expandable rather than shell-quoting it.
            staged = f'"$WORK/component-{index}"'

            parts.extend([
                f"echo '[BUA] Downloading {component['name']}'",
                (
                    "curl -fL --retry 3 -o "
                    f"{staged} {q_component_url}"
                ),
                f"test -s {staged}",
            ])

            if component["executable"]:
                parts.append(f"chmod +x {staged}")

        # Back up all currently installed component files.
        for index, component in enumerate(clean_components):
            q_target_component = shlex.quote(
                component["target"]
            )

            parts.extend([
                f"TARGET_{index}={q_target_component}",
                (
                    f'OLD_{index}="${{TARGET_{index}}}'
                    '.bua-old.$$"'
                ),
                (
                    f'mkdir -p "$(dirname '
                    f'"${{TARGET_{index}}}")"'
                ),
                f'rm -f "$OLD_{index}"',
                (
                    f'if [ -e "${{TARGET_{index}}}" ]; then '
                    f'mv "${{TARGET_{index}}}" "$OLD_{index}"; '
                    "fi"
                ),
            ])

        # Install every staged component.
        parts.append("FAILED=0")

        for index, component in enumerate(clean_components):
            parts.append(
                f'if ! mv "$WORK/component-{index}" '
                f'"${{TARGET_{index}}}"; then '
                "FAILED=1; "
                "fi"
            )

        # Roll everything back if any component failed.
        rollback = []

        for index, component in enumerate(clean_components):
            if index == 0:
                rollback.append(
                    f'if [ "$FAILED" -ne 0 ]; then '
                    f'rm -f "${{TARGET_{index}}}"'
                )
            else:
                rollback.append(
                    f'rm -f "${{TARGET_{index}}}"'
                )

            rollback.append(
                f'if [ -e "$OLD_{index}" ]; then '
                f'mv "$OLD_{index}" '
                f'"${{TARGET_{index}}}"; fi'
            )

        rollback.extend([
            "exit 1",
            "fi",
        ])

        parts.extend(rollback)

        # Commit successful transaction.
        for index, component in enumerate(clean_components):
            parts.append(f'rm -f "$OLD_{index}"')

        parts.extend([
            "trap - EXIT",
            'rm -rf "$WORK"',
            f"echo {q_marker}",
        ])

        return "; ".join(parts), None

    if recipe_type == "replace_file":
        chmod_step = ""

        if resolved.get("executable"):
            chmod_step = 'chmod +x "$TMP"; '

        command = (
            "BUA_PARENT_UPDATE=1; "
            "set -e; "
            f"TARGET={q_target}; "
            'TMP="${TARGET}.bua-update.$$"; '
            'trap \'rm -f "$TMP"\' EXIT; '
            'mkdir -p "$(dirname "$TARGET")"; '
            f"echo '[BUA] Downloading newest {app_name} payload'; "
            f'curl -fL --retry 3 -o "$TMP" {q_url}; '
            'test -s "$TMP"; '
            + chmod_step
            + 'mv -f "$TMP" "$TARGET"; '
            'trap - EXIT; '
            f"echo {q_marker}"
        )

        return command, None

    if recipe_type == "replace_archive":
        archive_subpath = str(
            recipe.get("archive_subpath") or ""
        ).strip()

        archive_format = str(
            recipe.get("archive_format") or ""
        ).strip().lower()

        q_subpath = shlex.quote(archive_subpath)
        q_archive_format = shlex.quote(archive_format)

        command = (
            "BUA_PARENT_UPDATE=1; "
            "set -e; "
            f"TARGET={q_target}; "
            f"URL={q_url}; "
            f"SUBPATH={q_subpath}; "
            f"ARCHIVE_FORMAT={q_archive_format}; "
            'WORK=$(mktemp -d /tmp/bua-update.XXXXXX); '
            'ARCHIVE="$WORK/payload"; '
            'EXTRACT="$WORK/extract"; '
            'mkdir -p "$EXTRACT"; '
            'trap \'rm -rf "$WORK"\' EXIT; '
            f"echo '[BUA] Downloading newest {app_name} payload'; "
            'curl -fL --retry 3 -o "$ARCHIVE" "$URL"; '
            'test -s "$ARCHIVE"; '
            'case "$ARCHIVE_FORMAT" in '
            'bsdtar) bsdtar -xf "$ARCHIVE" -C "$EXTRACT" ;; '
            'zip) unzip -oq "$ARCHIVE" -d "$EXTRACT" ;; '
            'tar) tar -xf "$ARCHIVE" -C "$EXTRACT" ;; '
            '"") '
            'case "$URL" in '
            '*.zip*) unzip -oq "$ARCHIVE" -d "$EXTRACT" ;; '
            '*.tar.gz*|*.tgz*|*.tar.xz*|*.txz*|*.tar.bz2*|*.tbz2*) '
            'tar -xf "$ARCHIVE" -C "$EXTRACT" ;; '
            '*) echo "[BUA] Unsupported archive format: $URL"; exit 1 ;; '
            'esac ;; '
            '*) echo "[BUA] Unsupported archive extractor: $ARCHIVE_FORMAT"; exit 1 ;; '
            'esac; '
            'SOURCE="$EXTRACT"; '
            'if [ -n "$SUBPATH" ]; then SOURCE="$EXTRACT/$SUBPATH"; fi; '
            'test -e "$SOURCE"; '
            'NEW="${TARGET}.bua-new.$$"; '
            'OLD="${TARGET}.bua-old.$$"; '
            'rm -rf "$NEW" "$OLD"; '
            'mv "$SOURCE" "$NEW"; '
            'if [ -e "$TARGET" ]; then mv "$TARGET" "$OLD"; fi; '
            'if mv "$NEW" "$TARGET"; then '
            '  rm -rf "$OLD"; '
            'else '
            '  rm -rf "$NEW"; '
            '  if [ -e "$OLD" ]; then mv "$OLD" "$TARGET"; fi; '
            '  exit 1; '
            'fi; '
            'trap - EXIT; '
            'rm -rf "$WORK"; '
            f"echo {q_marker}"
        )

        return command, None

    if recipe_type == "replace_bundle":
        members = recipe.get("bundle_members") or []

        if not isinstance(members, list) or not members:
            return None, "replace_bundle has no bundle members"

        archive_subpath = str(
            recipe.get("archive_subpath") or ""
        ).strip()

        archive_format = str(
            recipe.get("archive_format") or ""
        ).strip().lower()

        clean_members = []

        for member in members:
            member = str(member or "").strip()

            if (
                not member
                or "/" in member
                or member in (".", "..")
            ):
                return None, (
                    "Unsafe replace_bundle member: "
                    + repr(member)
                )

            clean_members.append(member)

        member_words = " ".join(
            shlex.quote(member)
            for member in clean_members
        )

        q_subpath = shlex.quote(archive_subpath)
        q_archive_format = shlex.quote(archive_format)

        chmod_step = ""

        if resolved.get("executable"):
            chmod_step = 'chmod +x "$NEW"; '

        command = (
            "BUA_PARENT_UPDATE=1; "
            "set -e; "
            f"TARGET={q_target}; "
            f"URL={q_url}; "
            f"MEMBERS=({member_words}); "
            f"SUBPATH={q_subpath}; "
            f"ARCHIVE_FORMAT={q_archive_format}; "
            'WORK=$(mktemp -d /tmp/bua-update.XXXXXX); '
            'ARCHIVE="$WORK/payload"; '
            'EXTRACT="$WORK/extract"; '
            'mkdir -p "$EXTRACT" "$TARGET"; '
            'trap \'rm -rf "$WORK"\' EXIT; '
            f"echo '[BUA] Downloading newest {app_name} payload'; "
            'curl -fL --retry 3 -o "$ARCHIVE" "$URL"; '
            'test -s "$ARCHIVE"; '
            'if [ "$ARCHIVE_FORMAT" = "squashfs" ]; then '
            '  unsquashfs -f -d "$EXTRACT" "$ARCHIVE"; '
            'else '
            '  case "$URL" in '
            '  *.zip*) unzip -oq "$ARCHIVE" -d "$EXTRACT" ;; '
            '  *.tar.gz*|*.tgz*|*.tar.xz*|*.txz*|*.tar.bz2*|*.tbz2*) '
            '  tar -xf "$ARCHIVE" -C "$EXTRACT" ;; '
            '  *) echo "[BUA] Unsupported archive format: $URL"; exit 1 ;; '
            '  esac; '
            'fi; '
            'SOURCE_ROOT="$EXTRACT"; '
            'if [ -n "$SUBPATH" ]; then SOURCE_ROOT="$EXTRACT/$SUBPATH"; fi; '
            'test -d "$SOURCE_ROOT"; '

            # Stage every new member before touching installed payloads.
            'for MEMBER in "${MEMBERS[@]}"; do '
            '  SRC=$(find "$SOURCE_ROOT" -maxdepth 1 -type f -name "$MEMBER" -print -quit); '
            '  if [ -z "$SRC" ]; then '
            '    echo "[BUA] Missing bundle member: $MEMBER"; exit 1; '
            '  fi; '
            '  DEST="$TARGET/$MEMBER"; '
            '  NEW="${DEST}.bua-new.$$"; '
            '  rm -f "$NEW"; '
            '  cp -p "$SRC" "$NEW"; '
            + chmod_step +
            'done; '

            # Back up only payload members.
            'for MEMBER in "${MEMBERS[@]}"; do '
            '  DEST="$TARGET/$MEMBER"; '
            '  OLD="${DEST}.bua-old.$$"; '
            '  rm -f "$OLD"; '
            '  if [ -e "$DEST" ]; then mv "$DEST" "$OLD"; fi; '
            'done; '

            # Install all staged members.
            'FAILED=0; '
            'for MEMBER in "${MEMBERS[@]}"; do '
            '  DEST="$TARGET/$MEMBER"; '
            '  NEW="${DEST}.bua-new.$$"; '
            '  if ! mv "$NEW" "$DEST"; then FAILED=1; break; fi; '
            'done; '

            # Roll back the entire bundle if any member failed.
            'if [ "$FAILED" -ne 0 ]; then '
            '  for MEMBER in "${MEMBERS[@]}"; do '
            '    DEST="$TARGET/$MEMBER"; '
            '    OLD="${DEST}.bua-old.$$"; '
            '    NEW="${DEST}.bua-new.$$"; '
            '    rm -f "$DEST" "$NEW"; '
            '    if [ -e "$OLD" ]; then mv "$OLD" "$DEST"; fi; '
            '  done; '
            '  exit 1; '
            'fi; '

            # Commit.
            'for MEMBER in "${MEMBERS[@]}"; do '
            '  DEST="$TARGET/$MEMBER"; '
            '  rm -f "${DEST}.bua-old.$$"; '
            'done; '
            'trap - EXIT; '
            'rm -rf "$WORK"; '
            f"echo {q_marker}"
        )

        return command, None

    return None, (
        "Unsupported global update recipe: "
        + recipe_type
    )




def try_adopt_verified_payload_baseline(
    app_name: str,
) -> bool:
    """
    Safely adopt the CURRENT upstream identity for an already-installed
    but previously untracked application.

    Adoption happens only when:
      1. the manifest declares an architecture-specific payload URL,
      2. the installer declares that payload's SHA-256,
      3. the downloaded archive matches that SHA-256,
      4. every regular file in the current upstream payload matches
         the corresponding installed file byte-for-byte.

    No application files are modified.
    """
    import hashlib
    import os
    import platform
    import shutil
    import tarfile
    import tempfile
    import urllib.request
    import zipfile

    entry = get_global_manifest_entry(
        app_name
    )

    if not isinstance(entry, dict):
        return False

    install_root = str(
        entry.get("install_root")
        or ""
    ).strip()

    payload_urls = (
        entry.get("payload_urls_by_arch")
        or {}
    )

    checksums = (
        entry.get("declared_payload_sha256")
        or {}
    )

    if (
        not install_root
        or not isinstance(payload_urls, dict)
        or not isinstance(checksums, dict)
    ):
        return False

    machine = platform.machine().lower()

    if machine in ("x86_64", "amd64"):
        arch = "x86_64"
    elif machine in ("aarch64", "arm64"):
        arch = "arm64"
    else:
        return False

    payload_url = str(
        payload_urls.get(arch)
        or payload_urls.get("generic")
        or ""
    ).strip()

    expected_sha256 = str(
        checksums.get(arch)
        or checksums.get("generic")
        or ""
    ).strip().lower()

    if (
        not payload_url
        or not re.fullmatch(
            r"[0-9a-f]{64}",
            expected_sha256,
        )
    ):
        return False

    # Resolve installer-style shell paths such as:
    #   $HOME/.local/example
    install_root = os.path.expanduser(
        os.path.expandvars(
            install_root
        )
    )

    installed_root = Path(
        install_root
    )

    if not installed_root.is_dir():
        return False

    work = Path(
        tempfile.mkdtemp(
            prefix="bua-baseline-verify-"
        )
    )

    payload_path = work / "payload"
    extract_root = work / "extract"

    try:
        req = urllib.request.Request(
            payload_url,
            headers={
                "User-Agent":
                    "BUA-Verified-Baseline/1",
                "Cache-Control":
                    "no-cache",
            },
        )

        digest = hashlib.sha256()

        with urllib.request.urlopen(
            req,
            timeout=60,
        ) as response, payload_path.open(
            "wb"
        ) as out:
            while True:
                chunk = response.read(
                    1024 * 1024
                )

                if not chunk:
                    break

                digest.update(chunk)
                out.write(chunk)

        actual_sha256 = digest.hexdigest()

        if actual_sha256 != expected_sha256:
            print(
                f"[BUA] Baseline verification refused for "
                f"{app_name}: payload checksum mismatch"
            )
            return False

        extract_root.mkdir(
            parents=True,
            exist_ok=True,
        )

        lower_url = payload_url.lower().split(
            "?",
            1,
        )[0]

        if lower_url.endswith(".zip"):
            with zipfile.ZipFile(
                payload_path
            ) as archive:
                archive.extractall(
                    extract_root
                )

        else:
            try:
                with tarfile.open(
                    payload_path,
                    mode="r:*",
                ) as archive:
                    # Python 3.12+ safe extraction policy.
                    try:
                        archive.extractall(
                            extract_root,
                            filter="data",
                        )
                    except TypeError:
                        archive.extractall(
                            extract_root
                        )

            except tarfile.TarError:
                return False

        # Some archives contain the payload directly at archive root.
        # Others wrap everything in one top-level directory.
        candidates = [
            extract_root,
        ]

        top_entries = list(
            extract_root.iterdir()
        )

        if (
            len(top_entries) == 1
            and top_entries[0].is_dir()
        ):
            candidates.append(
                top_entries[0]
            )

        matched_payload = False

        for payload_root in candidates:
            payload_files = [
                path
                for path in payload_root.rglob("*")
                if path.is_file()
                and not path.is_symlink()
            ]

            if not payload_files:
                continue

            candidate_matches = True

            for payload_file in payload_files:
                relative = payload_file.relative_to(
                    payload_root
                )

                installed_file = (
                    installed_root / relative
                )

                if not installed_file.is_file():
                    candidate_matches = False
                    break

                def sha256_file(path):
                    h = hashlib.sha256()

                    with path.open("rb") as fh:
                        while True:
                            block = fh.read(
                                1024 * 1024
                            )

                            if not block:
                                break

                            h.update(block)

                    return h.hexdigest()

                if (
                    sha256_file(payload_file)
                    != sha256_file(installed_file)
                ):
                    candidate_matches = False
                    break

            if candidate_matches:
                matched_payload = True
                break

        if not matched_payload:
            print(
                f"[BUA] Existing {app_name} install does not "
                f"match the current upstream payload"
            )
            return False

        snapshot = get_catalog_registration_snapshot(
            app_name,
            use_cache=False,
        )

        if not snapshot.get("supported"):
            return False

        registration = (
            snapshot.get("registration")
            or {}
        )

        app_version = str(
            registration.get("app_version")
            or ""
        ).strip()

        update_identity = str(
            registration.get("update_identity")
            or app_version
        ).strip()

        if not app_version or not update_identity:
            return False

        package_data = {
            "app_version":
                app_version,
            "update_identity":
                update_identity,
            "update_method":
                registration.get(
                    "update_method"
                )
                or "custom",
            "registration_source":
                "verified_payload_match",
            "registration_schema":
                2,
            "upstream":
                registration.get(
                    "upstream"
                )
                or {},
            "updated_at":
                datetime.now().strftime(
                    "%Y-%m-%d %H:%M:%S"
                ),
        }

        set_package_state(
            app_name,
            package_data,
        )

        print(
            f"[BUA] Verified and adopted installed "
            f"baseline for {app_name}: "
            f"{app_version}"
        )

        return True

    except Exception as exc:
        print(
            f"[BUA] Baseline verification skipped for "
            f"{app_name}: {exc}"
        )

        return False

    finally:
        shutil.rmtree(
            work,
            ignore_errors=True,
        )


def get_app_version_status(app_name: str) -> Dict:
    """
    Compare the installed update identity with the latest identity
    reported by the app's current BUA installer.

    app_version is human-readable.
    update_identity is the authoritative comparison key.
    """
    metadata = get_registered_version_metadata(
        app_name
    )

    registered_version = metadata.get(
        "app_version"
    )

    installed_identity = (
        metadata.get("update_identity")
        or registered_version
    )

    probe_version = read_version_probe(
        metadata.get("version_probe")
    )

    installed_version = (
        probe_version
        or registered_version
    )

    latest_version = None
    latest_identity = None
    snapshot_error = None

    snapshot = get_catalog_registration_snapshot(
        app_name
    )

    if snapshot.get("supported"):
        latest_registration = (
            snapshot.get("registration") or {}
        )

        latest_version = (
            latest_registration.get("app_version")
        )

        latest_identity = (
            latest_registration.get("update_identity")
            or latest_version
        )

    else:
        snapshot_error = snapshot.get("error")

    # Compatibility fallback for installers not yet converted.
    if not latest_version:
        latest_version = get_latest_app_version(
            app_name
        )

        latest_identity = latest_version

    registration_mismatch = bool(
        probe_version
        and registered_version
        and probe_version != registered_version
    )

    if not installed_version:
        adopted = try_adopt_verified_payload_baseline(
            app_name
        )

        if adopted:
            metadata = get_registered_version_metadata(
                app_name
            )

            registered_version = metadata.get(
                "app_version"
            )

            installed_identity = (
                metadata.get("update_identity")
                or registered_version
            )

            probe_version = read_version_probe(
                metadata.get("version_probe")
            )

            installed_version = (
                probe_version
                or registered_version
            )

        if not installed_version:
            return {
                "status": "unknown",
                "needs_update": False,
                "installed_version": None,
                "latest_version": latest_version,
                "installed_update_identity": installed_identity,
                "latest_update_identity": latest_identity,
                "registered_version": registered_version,
                "probe_version": probe_version,
                "registration_mismatch": registration_mismatch,
                "error": "Installed application version is unknown",
            }

    if not installed_identity:
        if probe_version and latest_version:
            installed_cmp = str(probe_version).strip()
            latest_cmp = str(latest_version).strip()

            if installed_cmp.lower().startswith("v"):
                installed_cmp = installed_cmp[1:]

            if latest_cmp.lower().startswith("v"):
                latest_cmp = latest_cmp[1:]

            needs_update = (
                installed_cmp != latest_cmp
            )

            return {
                "status": (
                    "update_available"
                    if needs_update
                    else "current"
                ),
                "needs_update": needs_update,
                "installed_version": installed_version,
                "latest_version": latest_version,
                "installed_update_identity": None,
                "latest_update_identity": latest_identity,
                "registered_version": registered_version,
                "probe_version": probe_version,
                "registration_mismatch": registration_mismatch,
                "error": None,
            }

        return {
            "status": "unknown",
            "needs_update": False,
            "installed_version": installed_version,
            "latest_version": latest_version,
            "installed_update_identity": None,
            "latest_update_identity": latest_identity,
            "registered_version": registered_version,
            "probe_version": probe_version,
            "registration_mismatch": registration_mismatch,
            "error": "Installed update identity is unknown",
        }

    if not latest_identity:
        return {
            "status": "unknown",
            "needs_update": False,
            "installed_version": installed_version,
            "latest_version": latest_version,
            "installed_update_identity": installed_identity,
            "latest_update_identity": None,
            "registered_version": registered_version,
            "probe_version": probe_version,
            "registration_mismatch": registration_mismatch,
            "error": snapshot_error,
        }

    needs_update = (
        installed_identity != latest_identity
    )

    return {
        "status": (
            "update_available"
            if needs_update
            else "current"
        ),
        "needs_update": needs_update,
        "installed_version": installed_version,
        "latest_version": latest_version,
        "installed_update_identity": installed_identity,
        "latest_update_identity": latest_identity,
        "registered_version": registered_version,
        "probe_version": probe_version,
        "registration_mismatch": registration_mismatch,
        "error": None,
    }


UPDATE_POLICIES: Dict[str, str] = {}


def get_update_method(app_name: str) -> str:
    """Return the approved BUA update method for one package."""
    return UPDATE_POLICIES.get(app_name, "unsupported")


def can_auto_update(app_name: str) -> bool:
    """Return True only when BUA currently has an approved automatic updater."""
    return get_update_method(app_name) == "reinstall"


APPS: Dict[str, str] = {
    "7zip": bua("7zip/7zip.sh"),
    "Amazon Luna": bua("amazonluna/amazonluna.sh"),
    "Ambermoon": bua("ambermoon/ambermoon.sh"),
    "Android": bua("Android/Install_Android.sh"),
    "Armagetron": bua("armagetron/armagetron.sh"),
    "Arcade Manager": bua("arcademanager/arcademanager.sh"),
    "Assault Cube": bua("assaultcube/assaultcube.sh"),
    "AzaharPlus": bua("azaharplus/azaharplus.sh"),
    "Brave": bua("brave/brave.sh"),
    "Chiaki": bua("chiaki/chiaki.sh"),
    "Chrome": bua("chrome/chrome.sh"),
    "Clone Hero": bua("clonehero/clonehero.sh"),
    "Conty": bua("conty/conty.sh"),
    "CS Portable": bua("csportable/csportable.sh"),
    "Disney Plus": bua("disneyplus/disneyplus.sh"),
    "CLI Tools": bua("docker/cli.sh"),
    "Endless Sky": bua("endlesssky/endlesssky.sh"),
    "EGGNOGG+": bua("eggnoggplus/eggnoggplus.sh"),
    "Everest": bua("everest/everest.sh"),
    "Firefox": bua("firefox/firefox.sh"),
    "Fightcade": bua("fightcade/fightcade.sh"),
    "Flathub": bua("flathub/flathub.sh"),
    "Freej2me": bua("Freej2me/Install_j2me.sh"),
    "Winconfig (Windows Game Fix)": bua("Winconfig_Windows_Game_Fix/Install_Winconfig.sh"),
    "Desktop For Batocera": bua("Desktop_for_Batocera/Install_Desktop.sh"),
    "Free Droid RPG": bua("freedroidrpg/freedroidrpg.sh"),
    "Greenlight": bua("greenlight/greenlight.sh"),
    "Heroic": bua("heroic/heroic.sh"),
    "IPTV Nator": bua("iptvnator/iptvnator.sh"),
    "Input Leap": bua("inputleap/inputleap.sh"),
    "Itch.io": bua("itchio/itch.sh"),
    "Jellyfin Player": bua("jellyfin-client/jellyfin-client.sh"),
    "JDownloader": bua("jdownloader/jdownloader.sh"),
    "Java Runtime": bua("java/java.sh"),
    "Minecraft": bua("minecraft/minecraft.sh"),
    "Prism Launcher": bua("prismlauncher/prismlauncher.sh"),
    "Moonlight": bua("moonlight/moonlight.sh"),
    "Netflix": bua("netflix/netflix.sh"),
    "NVIDIA Patcher": bua("nvidiapatch/nvidiapatch.sh"),
    "Nazi Zombies Portable": bua("nzp/nzp.sh"),
    "OBS": bua("obs/obs.sh"),
    "OpenRA": bua("openra/openra.sh"),
    "OpenRGB": bua("openrgb/openrgb.sh"),
    "PortMaster": bua("portmaster/portmaster.sh"),
    "qBittorrent": bua("qbittorrent/qbittorrent.sh"),
    "ShadPS4": bua("shadps4plus/shadps4plus.sh"),
    "Spotify": bua("spotify/spotify.sh"),
    "ITGMania": bua("itgmania/itgmania.sh"),
    "Stremio": bua("stremio/stremio.sh"),
    "Sunshine": bua("sunshine/sunshine.sh"),
    "SuperTux": bua("supertux/supertux.sh"),
    "SuperTuxKart": bua("supertuxkart/supertuxkart.sh"),
    "Switch": bua("switch/switch.sh"),
    "Tailscale": bua("tailscale/tailscale.sh"),
    "Telegraf": bua("telegraf/telegraf.sh"),
    "Twitch": bua("twitch/twitch.sh"),
    "Vesktop": bua("vesktop/vesktop.sh"),
    "Warzone 2100": bua("warzone2100/warzone2100.sh"),
    "Wine Dependencies x86": bua("winemanager/install_redist_dependencies32.sh"),
    "Wine Dependencies x64": bua("winemanager/install_redist_dependencies64.sh"),
    "Wine Manager": bua("winemanager/winemanager.sh"),
    "Xonotic": bua("xonotic/xonotic.sh"),
    "YouTube": bua("youtubetv/youtubetv.sh"),
    "NVIDIA Clocker": "curl -Ls https://raw.githubusercontent.com/nicolai-6/batocera-nvidia-clocker/refs/heads/main/install.sh | bash",
    "Custom Wine": bua("wine-custom/wine.sh"),
    "GParted": bua("gparted/gparted.sh"),
    "YARG": bua("yarg/yarg.sh"),
    "Plex": bua("plex/plex.sh"),
    "OpenTTD": bua("openttd/openttd.sh"),
    "Luanti": bua("luanti/luanti.sh"),
    "Parsec": bua("parsec/parsec.sh"),
    "HBO Max": bua("hbomax/hbomax.sh"),
    "Prime Video": bua("prime/prime.sh"),
    "Crunchyroll": bua("crunchyroll/crunchyroll.sh"),
    "Mubi": bua("mubi/mubi.sh"),
    "Tidal": bua("tidal/tidal.sh"),
    "FreeTube": bua("freetube/freetube.sh"),
    "Super Mario X": bua("supermariox/supermariox.sh"),
    "Celeste 64": bua("celeste64/celeste64.sh"),
    "Steam": bua("steam/steam2.sh"),
    "Lutris": bua("lutris/lutris.sh"),
    "FileZilla": bua("filezilla/filezilla.sh"),
    "PeaZip": bua("peazip/peazip.sh"),
    "VLC": bua("vlc/vlc.sh"),
    "Docker": bua("docker/docker.sh"),
    "Bottles": bua("bottles/bottles.sh"),
    "Extras": bua("extra/extra.sh"),
    "UltraStar": bua("usdeluxe/usdeluxe.sh"),
    "F1": bua("f1/f1.sh"),
    "Desktop": bua("desktop/desktop.sh"),
    "X11VNC": bua("x11vnc/x11vnc.sh"),
    "QEMU GA": bua("qga/qga.sh"),
    "Bridge": bua("bridge/bridge.sh"),
    "Sandtrix": bua("sandtrix/sandtrix.sh"),
    "Soar": bua("soar/soar.sh"),
    "Dark Mode": bua("dark/dark.sh"),
    "VClean": bua("vclean/vclean.sh"),
    "Overlay Remove": bua("overlay-remove/overlay-remove.sh"),
    "RGSX": "curl -L bit.ly/rgsx-install | sh",
    "Raspberry Pi Imager": bua("rpi/rpi.sh"),
    "Gamescope": bua("gamescope/gamescope.sh"),
    "npsget": "curl -fsSL https://npsget.8101987.xyz | sh",
    "ps3i": "curl -fsSL https://ps3i.8101987.xyz/install.sh | sh",
}

# --- Integrated Windows Freeware installers (previously separate bash menu) ---
# These run upstream installer scripts directly within the existing runner.
APPS.update({
    "AM2R": bua("windows/am2r.sh"),
    "Maldita Castilla": bua("windows/castilla.sh"),
    "Celeste": bua("windows/celeste.sh"),
    "Donkey Kong Advanced": bua("windows/dka.sh"),
    "Spelunky": bua("windows/spelunky.sh"),
    "Zelda 2 PC Remake": bua("windows/zelda2.sh"),
    "Zelda - Dungeons of Infinity": bua("windows/zeldadoi.sh"),
    "Space Quest 3D": bua("windows/sq3d.sh"),
    "Streets of Rage Remake": bua("windows/sorr.sh"),
    "Super Crate Box": bua("windows/scb.sh"),
    "Super Smash Flash 2": bua("windows/ssf2.sh"),
    "TMNT Rescue Palooza": bua("windows/tmntrp.sh"),
    "Crash Bandicoot - Back In Time": bua("windows/cbbit.sh"),
    "Sonic Triple Trouble 16bit": bua("windows/stt.sh"),
    "Sonic 3D in 2D": bua("windows/s3d2d.sh"),
    "SHRUBNAUT": bua("windows/shrubnaut.sh"),
    "Secret Maryo Chronicles": bua("windows/smc.sh"),
    "SCP Containment Breach": bua("windows/scpcontainmentbreach.sh"),
    "Zero-K": bua("windows/zerok.sh"),
    "Modern Modern Chef": bua("windows/mmc.sh"),
    "Sonic Robo Blast 2": bua("windows/srb2.sh"),
    "Sonic Time Twisted": bua("windows/sttw.sh"),
    "Super Smash Bros CMC+": bua("windows/cmc+.sh"),
    "Unreal Tournament": bua("windows/ut.sh"),
})

# --- Integrated Docker app installers (previously separate bash menu) ---
APPS.update({
    "CasaOS": bua("docker/casaos.sh"),
    "UmbrelOS": bua("docker/umbrelos.sh"),
    "Arch KDE (Webtop)": bua("docker/archkde.sh"),
    "Ubuntu MATE (Webtop)": bua("docker/ubuntumate.sh"),
    "Alpine XFCE (Webtop)": bua("docker/alpinexfce.sh"),
    "Jellyfin": bua("docker/jellyfin.sh"),
    "Emby": bua("docker/emby.sh"),
    "Arr-In-One": bua("docker/arrinone.sh"),
    "Arr-In-One Downloaders": bua("docker/arrdownloaders.sh"),
})

DESCRIPTIONS: Dict[str, str] = {
    "Sunshine": "Self-hosted game streaming server (host for Moonlight).",
    "Moonlight": "Stream PC games on Batocera.",
    "NVIDIA Patcher": "Enable NVIDIA GPU support on Batocera.",
    "Switch": "Nintendo Switch emulator for Batocera.",
    "Tailscale": "VPN service for secure Batocera connections.",
    "Telegraf": "Server agent for collecting and reporting metrics.",
    "Wine Manager": "Manage Windows games with Wine on Batocera.",
    "Wine Dependencies x86": "Install Windows x86 dependencies with Wine on Batocera.",
    "Wine Dependencies x64": "Install Windows x64 dependencies with Wine on Batocera.",
    "ShadPS4": "UPDATED 11/11 to ShadPS4Plus | Experimental PS4 streaming client.",
    "Conty": "Standalone Linux distro container.",
    "Minecraft": "Minecraft: Java or Bedrock Edition.",
    "Prism Launcher": "Open source Minecraft launcher with mod management and multi-instance support.",
    "Armagetron": "Tron-style light cycle game.",
    "Clone Hero": "Guitar Hero clone for Batocera.",
    "Stremio": "Stremio video streaming app for Batocera.",
    "Vesktop": "Discord client for Batocera.",
    "Endless Sky": "Space exploration game.",
    "EGGNOGG+": "Award-winning 2-player sword fighting game.",
    "Chiaki": "PS4/PS5 Remote Play client.",
    "Chrome": "Google Chrome web browser.",
    "Amazon Luna": "Amazon Luna game streaming client.",
    "PortMaster": "Download and manage games on handhelds.",
    "Greenlight": "Client for xCloud and Xbox streaming.",
    "Heroic": "Epic, GOG, and Amazon Games launcher.",
    "YouTube": "YouTube client for Batocera.",
    "Netflix": "Netflix streaming app for Batocera.",
    "IPTV Nator": "IPTV client for watching live TV.",
    "Input Leap": "Share Keyboard and mouse with other OSes.",
    "Firefox": "Mozilla Firefox browser.",
    "Flathub": "Browse different Flatpak applications.",
    "Java Runtime": "Install the Java Runtime on your batocera.",
    "Spotify": "Spotify music streaming client.",
    "CLI Tools": ">=V40! Various CLI tools including Docker, ZSH, Git etc.",
    "Arcade Manager": "Manage arcade ROMs and games.",
    "CS Portable": "Fan-made portable Counter-Strike.",
    "Brave": "Privacy-focused Brave browser.",
    "OpenRGB": "Manage RGB lighting on devices.",
    "Warzone 2100": "Real-time strategy and tactics game.",
    "Xonotic": "Fast-paced open-source arena shooter.",
    "Itch.io": "Indy Game Marketplace",
    "Android": "Android System for Batocera (EXPERIMENTAL).",
    "Freej2me": "J2ME classic game emulator.",
    "Desktop For Batocera": "Desktop for batocera. (Native)",
    "Winconfig (Windows Game Fix)": "Tool to simplify dependencies/config for Windows games (DRL Edition)",
    "Fightcade": "*UPDATED* Play classic arcade games online.",
    "SuperTuxKart": "Free and open-source kart racer.",
    "OpenRA": "Modernized RTS for Command & Conquer.",
    "AzaharPlus": "AzaharPlus 3DS emulator - selectable alongside Azahar in EmulationStation.",
    "Assault Cube": "Multiplayer first-person shooter game.",
    "OBS": "Streaming and video recording software.",
    "SuperTux": "2D platformer starring Tux the Linux mascot.",
    "Free Droid RPG": "Open-source role-playing game for Batocera.",
    "Disney Plus": "Disney+ streaming app for Batocera.",
    "Twitch": "Twitch streaming app for Batocera.",
    "NVIDIA Clocker": "A CLI/Ports program to overclock NVIDIA GPUs",
    "7zip": "A free and open-source file archiver",
    "qBittorrent": "Free and open-source BitTorrent client",
    "ITGMania": "In The Groove-focused rhythm game, fork of StepMania with ITG improvements.",
    "Ambermoon": "Ambermoon.net, a port of the classic",
    "Custom Wine": "Download Wine/Proton versions",
    "GParted": "Linux partition manager",
    "JDownloader": "Download manager with background service",
    "YARG": "Yet Another Rhythm Game",
    "Plex": "Plex Media Player",
    "OpenTTD": "Open source clone of Transport Tycoon Deluxe",
    "Luanti": "Voxel sandbox (Minecraft-like)",
    "Nazi Zombies Portable": "Classic Nazi Zombies on modern platforms",
    "Parsec": "Remote desktop & game streaming",
    "HBO Max": "HBO Max streaming app",
    "Prime Video": "Amazon Prime Video streaming app",
    "Crunchyroll": "Anime-focused streaming service",
    "Mubi": "Curated cinema platform",
    "Tidal": "HiFi music streaming",
    "Everest": "Celeste Mod Loader",
    "FreeTube": "Privacy-minded YouTube client",
    "Super Mario X": "Fan-made Super Mario tribute",
    "Celeste 64": "Free 3D platformer (Celeste)",
    "Steam": "NEW BUILD DEC 25 - Steam Big Picture / Desktop",
    "Lutris": "Open source game manager",
    "FileZilla": "Cross-platform FTP client",
    "PeaZip": "Free and open-source file archiver",
    "VLC": "VLC media player",
    "Docker": "Docker/Podman/Portainer AIO.",
    "Bottles": "Run Windows software on Linux",
    "Extras": "Various scripts, incl. motion support.",
    "UltraStar": "UltraStar Deluxe karaoke",
    "F1": "Ports shortcut to file manager",
    "Desktop": "Desktop mode (Ports)",
    "X11VNC": "Remote control over VNC",
    "QEMU GA": "Guest agent for VMs",
    "Bridge": "Chart downloader for CloneHero/YARG",
    "Sandtrix": "Falling sand physics puzzle game",
    "Soar": "Soar package manager (integrated with BUA)",
    "Dark Mode": "Toggle F1 dark mode",
    "VClean": "Service to clean the Batocera version string (removes extra flags)",
    "Overlay Remove": "Remove the Batocera boot overlay file from /boot/boot/overlay.",
    "RGSX": "Retro Game Sets Xtra. A free, user-friendly ROM downloader for Batocera",
    "Raspberry Pi Imager": "Flash OS images to USB and SD cards.",
    "Gamescope": "Full-screen gaming compositor with smoother performance, scaling & low-latency control.",
    "npsget": "Helper to download games, DLCs, updates, themes and avatars from NoPayStation",
    "ps3i": "Installer for .pkg PS3 games into RPCS3 with automatic shortcut creation",
}

# Descriptions for integrated Windows Freeware entries
DESCRIPTIONS.update({
    "AM2R": "Another Metroid 2 Remake - Fan remake",
    "Maldita Castilla": "Arcade action platformer",
    "Celeste": "Indie platformer classic",
    "Donkey Kong Advanced": "Fan remake/port",
    "Spelunky": "Rogue-like platformer",
    "Zelda 2 PC Remake": "Fan remake of Zelda II",
    "Zelda - Dungeons of Infinity": "Zelda-inspired project",
    "Space Quest 3D": "Fan project tribute",
    "Streets of Rage Remake": "Enhanced beat 'em up remake",
    "Super Crate Box": "Fast-paced arcade platformer",
    "Super Smash Flash 2": "Fan fighting game",
    "TMNT Rescue Palooza": "Beat 'em up fan game",
    "Crash Bandicoot - Back In Time": "Fan game",
    "Sonic Triple Trouble 16bit": "Fan remake",
    "Sonic 3D in 2D": "2D demake of Sonic 3D Blast",
    "SHRUBNAUT": "Space exploration and mining game",
    "Secret Maryo Chronicles": "Super Mario-inspired platformer",
    "SCP Containment Breach": "SCP Foundation horror survival game",
    "Zero-K": "Free multiplayer real-time strategy game",
    "Modern Modern Chef": "Indie title",
    "Sonic Robo Blast 2": "Doom-based Sonic fangame",
    "Sonic Time Twisted": "Time-traveling Sonic fan game",
    "Super Smash Bros CMC+": "Fan crossover",
        "Unreal Tournament": "Classic competitive first-person shooter",
})

# Descriptions for integrated Docker apps
DESCRIPTIONS.update({
    "CasaOS": "Simple home server UI and app store",
    "UmbrelOS": "Self-hosted OS with app marketplace",
    "Arch KDE (Webtop)": "Arch Linux desktop in browser (noVNC)",
    "Ubuntu MATE (Webtop)": "Ubuntu MATE desktop in browser (noVNC)",
    "Alpine XFCE (Webtop)": "Alpine XFCE desktop in browser (noVNC)",
    "Jellyfin": "Open-source media server",
    "Jellyfin Player": "Jellyfin media player client with controller support",
    "Emby": "Media server and streaming",
    "Arr-In-One": "All-in-one media management stack",
    "Arr-In-One Downloaders": "Downloaders companion stack",
})


def sync_upstream_catalog():
    """
    Merge the current upstream BUA catalog into this patched frontend.

    Only catalog metadata is imported:
      - APPS
      - DESCRIPTIONS
      - CATEGORIES

    The rest of this frontend, including the global parent-source updater,
    remains local and unchanged.
    """
    import ast
    import urllib.request

    url = (
        "https://raw.githubusercontent.com/"
        "batocera-unofficial-addons/"
        "batocera-unofficial-addons/main/app/bua_installerx86.py"
    )

    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "BUA-Catalog-Sync"},
        )

        with urllib.request.urlopen(req, timeout=8) as r:
            source = r.read().decode("utf-8")

        tree = ast.parse(source)

        upstream_apps = {}
        upstream_desc = {}
        upstream_categories = {}

        def eval_value(node):
            if isinstance(node, ast.Constant):
                return node.value

            if isinstance(node, ast.List):
                return [eval_value(x) for x in node.elts]

            if isinstance(node, ast.Tuple):
                return tuple(eval_value(x) for x in node.elts)

            if isinstance(node, ast.Dict):
                return {
                    eval_value(k): eval_value(v)
                    for k, v in zip(node.keys, node.values)
                }

            if (
                isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "bua"
                and len(node.args) == 1
                and isinstance(node.args[0], ast.Constant)
            ):
                path = node.args[0].value
                return f"curl -L {BUA_BASE_URL}/{path} | bash"

            raise ValueError(f"Unsupported catalog node: {type(node).__name__}")

        for node in tree.body:
            # APPS = {...}, DESCRIPTIONS = {...}, CATEGORIES = {...}
            if isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name):
                name = node.target.id

                if name == "APPS":
                    upstream_apps.update(eval_value(node.value))
                elif name == "DESCRIPTIONS":
                    upstream_desc.update(eval_value(node.value))
                elif name == "CATEGORIES":
                    upstream_categories.update(eval_value(node.value))

            # APPS.update({...}) / DESCRIPTIONS.update({...})
            elif (
                isinstance(node, ast.Expr)
                and isinstance(node.value, ast.Call)
                and isinstance(node.value.func, ast.Attribute)
                and isinstance(node.value.func.value, ast.Name)
                and node.value.func.attr == "update"
                and len(node.value.args) == 1
            ):
                name = node.value.func.value.id

                if name == "APPS":
                    upstream_apps.update(eval_value(node.value.args[0]))
                elif name == "DESCRIPTIONS":
                    upstream_desc.update(eval_value(node.value.args[0]))

        if not upstream_apps:
            raise RuntimeError("No upstream APPS entries parsed")

        before = len(APPS)

        # Upstream is authoritative for install commands/catalog metadata.
        APPS.update(upstream_apps)
        DESCRIPTIONS.update(upstream_desc)

        for category, entries in upstream_categories.items():
            CATEGORIES[category] = entries

        after = len(APPS)

        print(
            f"[BUA] Upstream catalog sync OK: "
            f"{len(upstream_apps)} upstream apps, "
            f"{before} -> {after} local apps"
        )

    except Exception as e:
        print(f"[BUA] Upstream catalog sync skipped: {e}")


CATEGORIES: Dict[str, List[str]] = {
    "Games": [
        "Minecraft", "Prism Launcher", "Armagetron", "Clone Hero", "Endless Sky", "EGGNOGG+", "CS Portable",
        "Warzone 2100", "Xonotic", "Fightcade", "SuperTuxKart", "OpenRA",
        "Assault Cube", "SuperTux", "Free Droid RPG", "ITGMania", "Ambermoon",
        "YARG", "OpenTTD", "Luanti", "Super Mario X", "Celeste 64", "UltraStar",
        "Sandtrix"
    ],
    "Windows Freeware": [
        "AM2R",
        "Maldita Castilla",
        "Celeste",
        "Donkey Kong Advanced",
        "Spelunky",
        "Zelda 2 PC Remake",
        "Zelda - Dungeons of Infinity",
        "Space Quest 3D",
        "Streets of Rage Remake",
        "Super Crate Box",
        "Super Smash Flash 2",
        "TMNT Rescue Palooza",
        "Crash Bandicoot - Back In Time",
        "Sonic Triple Trouble 16bit",
        "Sonic 3D in 2D",
        "SHRUBNAUT",
        "Secret Maryo Chronicles",
        "SCP Containment Breach",
        "Zero-K",
        "Modern Modern Chef",
        "Nazi Zombies Portable",
        "Sonic Robo Blast 2",
        "Sonic Time Twisted",
        "Super Smash Bros CMC+",
        "Unreal Tournament",
    ],
    "Docker Menu": [
        "CasaOS",
        "UmbrelOS",
        "Arch KDE (Webtop)",
        "Ubuntu MATE (Webtop)",
        "Alpine XFCE (Webtop)",
        "Jellyfin",
        "Emby",
        "Arr-In-One",
        "Arr-In-One Downloaders",
    ],
    "Game Utilities": [
        "Android", "Amazon Luna", "AzaharPlus", "PortMaster", "Greenlight", "ShadPS4",
        "Chiaki", "Heroic", "Switch", "Parsec", "Java Runtime", "Freej2me",
        "Steam", "Lutris", "Bottles", "Sunshine", "Moonlight", "Bridge",
        "Itch.io", "Everest", "RGSX", "npsget", "ps3i"
    ],
    "System Utilities": [
        "Desktop For Batocera", "Winconfig (Windows Game Fix)", "F1", "Tailscale",
        "Telegraf", "Wine Manager", "Vesktop", "Chrome", "YouTube", "Netflix",
        "Input Leap", "IPTV Nator", "Firefox", "Spotify", "Arcade Manager", "Brave",
        "OpenRGB", "OBS", "Stremio", "Disney Plus", "Twitch", "7zip", "qBittorrent",
        "GParted", "Plex", "HBO Max", "Prime Video", "Crunchyroll",
        "Mubi", "Tidal", "FreeTube", "Jellyfin Player", "FileZilla", "PeaZip",
        "Desktop", "Flathub", "JDownloader", "Raspberry Pi Imager"
    ],
    "Developer Tools": [
        "NVIDIA Patcher", "Conty", "CLI Tools", "NVIDIA Clocker", "Docker",
        "Extras", "X11VNC", "QEMU GA", "Soar", "Dark Mode", "VClean", "Overlay Remove"
    ],
}

sync_upstream_catalog()

def get_top_level() -> List[Tuple[str, str]]:
    """Generate top-level menu items with current language translations"""
    return [
        (t("games"), t("games_desc")),
        (t("windows_freeware"), t("windows_freeware_desc")),
        (t("game_utilities"), t("game_utilities_desc")),
        (t("system_utilities"), t("system_utilities_desc")),
        (t("developer_tools"), t("developer_tools_desc")),
        (t("docker_menu"), t("docker_menu_desc")),
        (t("custom_wine"), t("custom_wine_desc")),
        (t("updater"), t("updater_desc")),
        (t("settings"), t("settings_desc")),
        (t("exit"), t("exit_desc")),
    ]

# TOP_LEVEL will be initialized after translations load in play_splash_and_load()
TOP_LEVEL = None

SPECIAL_TOPLEVEL_RUN: Dict[str, str] = {
    # "Windows Freeware" and "Docker Menu" integrated as categories in the UI
}

# ------------------------------
# Pygame UI helpers
# ------------------------------

pygame.init()
pygame.mouse.set_visible(False)
# Window caption will be set after translations load in play_splash_and_load()

def load_saved_cards_per_page():
    """Load saved cards per page preference"""
    global CARDS_PER_PAGE
    try:
        if os.path.exists(CARDS_PER_PAGE_FILE):
            with open(CARDS_PER_PAGE_FILE, 'r') as f:
                value = f.read().strip()
                if value:
                    CARDS_PER_PAGE = value
                    return value
    except Exception:
        pass
    return DEFAULT_CARDS_PER_PAGE

def save_cards_per_page(value: str):
    """Save cards per page preference (e.g., 'auto', '3', '5', '7')"""
    global CARDS_PER_PAGE
    try:
        os.makedirs(os.path.dirname(CARDS_PER_PAGE_FILE), exist_ok=True)
        with open(CARDS_PER_PAGE_FILE, 'w') as f:
            f.write(value)
        CARDS_PER_PAGE = value
    except Exception:
        pass

def load_saved_resolution():
    """Load saved resolution preference"""
    try:
        if os.path.exists(RESOLUTION_FILE):
            with open(RESOLUTION_FILE, 'r') as f:
                res = f.read().strip()
                if res and 'x' in res:
                    parts = res.split('x')
                    return int(parts[0]), int(parts[1])
    except Exception:
        pass
    return None

def save_resolution(width: int, height: int):
    """Save resolution preference"""
    try:
        os.makedirs(os.path.dirname(RESOLUTION_FILE), exist_ok=True)
        with open(RESOLUTION_FILE, 'w') as f:
            f.write(f"{width}x{height}")
    except Exception:
        pass

def get_visible_items(list_h: int, item_h: int) -> int:
    """Calculate number of visible items based on user preference.
    If CARDS_PER_PAGE is 'auto', calculate based on available space.
    Otherwise, use the specified number."""
    global CARDS_PER_PAGE
    try:
        if CARDS_PER_PAGE == "auto":
            return max(1, list_h // item_h)
        else:
            return max(1, int(CARDS_PER_PAGE))
    except Exception:
        return max(1, list_h // item_h)

def should_show_changelog() -> bool:
    """Check if changelog should be shown (has content and hasn't been shown for this version)."""
    if not CHANGELOG or not CHANGELOG.strip():
        return False

    # Hash the current changelog content
    current_hash = hashlib.md5(CHANGELOG.encode('utf-8')).hexdigest()

    # Check if we've shown this version before
    try:
        if os.path.exists(CHANGELOG_HASH_FILE):
            with open(CHANGELOG_HASH_FILE, 'r') as f:
                shown_hash = f.read().strip()
                if shown_hash == current_hash:
                    return False  # Already shown this changelog
    except Exception:
        pass

    return True

def mark_changelog_shown():
    """Mark the current changelog as shown by saving its hash."""
    try:
        current_hash = hashlib.md5(CHANGELOG.encode('utf-8')).hexdigest()
        os.makedirs(os.path.dirname(CHANGELOG_HASH_FILE), exist_ok=True)
        with open(CHANGELOG_HASH_FILE, 'w') as f:
            f.write(current_hash)
    except Exception:
        pass

# Safe exit function that properly releases KMS/DRM resources
def clean_exit(code=0):
    pygame.display.quit()
    pygame.quit()
    sys.exit(code)

# Safe display initialization that never corrupts the Batocera framebuffer
def init_display():
    global screen, W, H, UI_SCALE

    # Windowed mode for development/testing if needed
    if os.environ.get("BUA_WINDOWED"):
        size = (1280, 720)
        screen = pygame.display.set_mode(size, pygame.RESIZABLE)
    else:
        # Use native resolution (matches working display.py approach)
        display_info = pygame.display.Info()
        screen_width = display_info.current_w
        screen_height = display_info.current_h
        screen = pygame.display.set_mode((screen_width, screen_height))

    W, H = screen.get_size()
    UI_SCALE = max(1.0, min(W / 1280.0, H / 720.0))

def S(n: int) -> int:
    return int(round(n * UI_SCALE))

init_display()
clock = pygame.time.Clock()

def load_fonts():
    # DejaVu Sans for primary UI - good Latin/Cyrillic/Greek coverage
    # Note: DejaVu Sans doesn't support Arabic, Hebrew, CJK, Indic scripts
    # Those will show as squares in language names, but that's acceptable
    # since we show "English (Native)" format anyway

    primary = pygame.font.SysFont("DejaVu Sans", 24)
    small = pygame.font.SysFont("DejaVu Sans", 18)
    big = pygame.font.SysFont("DejaVu Sans", 36, bold=True)
    return primary, small, big

FONT, FONT_SMALL, FONT_BIG = load_fonts()

# Batocera brand-inspired palette
# Dark slate background, slate cards, cyan-blue accents
BG = (12, 16, 20)
CARD = (52, 64, 72)
ACCENT = (0, 168, 224)
FG = (235, 242, 247)
MUTED = (153, 163, 173)
SELECT = (0, 120, 180)

# ---------- Assets & Background ----------
LOGO_SURF = None
WHEEL_SURF = None
BACKGROUND_SURF = None  # Will be created in init_assets()
BUTTON_ICONS: Dict[str, pygame.Surface] = {}
# You can point to hosted images via per-key envs (e.g. BUA_BTN_A_URL)
# or set a common base URL via BUA_BTN_BASE_URL where files are named as below.
DEFAULT_BUTTONS_BASE_URL = os.environ.get("BUA_BTN_BASE_URL") or \
    "https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/app/extra"

# Controller style detection and mapping
PAD_STYLE = "xbox"  # xbox | playstation | nintendo | generic | keyboard
# Optional user override set from Settings (None => auto/detect/env)
PAD_STYLE_USER_OVERRIDE: str | None = None
# Map logical A/B/X/Y prompts to icon keys by style (for rendering)
STYLE_ICON_MAP: Dict[str, Dict[str, str]] = {
    "xbox": {"A": "A", "B": "B", "X": "X", "Y": "Y"},
    "playstation": {"A": "CROSS", "B": "CIRCLE", "X": "SQUARE", "Y": "TRIANGLE"},
    # For Nintendo, physical labels are A(right), B(bottom), X(top), Y(left).
    # Map logical buttons to Nintendo icons by position: A(bottom)->B, B(back)->A, X(left)->Y, Y(top)->X.
    "nintendo": {"A": "B", "B": "A", "X": "Y", "Y": "X"},
    "generic": {"A": "A", "B": "B", "X": "X", "Y": "Y"},
    "keyboard": {"A": "A", "B": "B", "X": "X", "Y": "Y"},
}

# Runtime joystick button mapping (for input)
# This normalizes diverse controller layouts into logical buttons.
# Values can be overridden with environment variables, e.g. BUA_BTN_START=9
BTN_A = 0
BTN_B = 1
BTN_X = 2
BTN_Y = 3
BTN_LB = 4
BTN_RB = 5
BTN_BACK = 6
BTN_START = 7

def _env_int(name: str, default: int) -> int:
    try:
        val = os.environ.get(name)
        if val is None:
            return default
        return int(val)
    except Exception:
        return default

def update_button_mapping():
    """Update global BTN_* constants from environment variables only.
    No default mappings - buttons must be set via manual mapping or env vars."""
    global BTN_A, BTN_B, BTN_X, BTN_Y, BTN_LB, BTN_RB, BTN_BACK, BTN_START
    # Only use environment variables, no fallback defaults
    BTN_A    = _env_int("BUA_BTN_A",    0)
    BTN_B    = _env_int("BUA_BTN_B",    1)
    BTN_X    = _env_int("BUA_BTN_X",    2)
    BTN_Y    = _env_int("BUA_BTN_Y",    3)
    BTN_LB   = _env_int("BUA_BTN_LB",   4)
    BTN_RB   = _env_int("BUA_BTN_RB",   5)
    BTN_BACK = _env_int("BUA_BTN_BACK", 6)
    BTN_START= _env_int("BUA_BTN_START",7)

# ------------------------------
# Optional: manual button mapper
# ------------------------------

# Where to persist a manual button map
CONTROLS_FILE = "/userdata/system/add-ons/bua_controls.json"

def _load_saved_button_map() -> dict:
    try:
        if os.path.exists(CONTROLS_FILE):
            with open(CONTROLS_FILE, "r", encoding="utf-8") as f:
                data = json.load(f) or {}
                if isinstance(data, dict):
                    return data
    except Exception:
        pass
    return {}

def _apply_saved_button_map_if_any() -> bool:
    """If a manual mapping exists, apply it by setting env vars and updating globals.
    Returns True if applied.
    """
    data = _load_saved_button_map()
    required = ["A","B","X","Y","LB","RB","BACK","START"]
    if all(k in data and isinstance(data[k], int) for k in required):
        os.environ["BUA_BTN_A"] = str(data["A"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_B"] = str(data["B"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_X"] = str(data["X"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_Y"] = str(data["Y"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_LB"] = str(data["LB"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_RB"] = str(data["RB"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_BACK"] = str(data["BACK"])  # type: ignore[arg-type]
        os.environ["BUA_BTN_START"] = str(data["START"])  # type: ignore[arg-type]
        # Lock into a generic style label to avoid flipping icons unexpectedly
        os.environ["BUA_PAD_STYLE"] = os.environ.get("BUA_PAD_STYLE", "generic")
        # Recompute globals
        update_button_mapping()
        return True
    return False

def _save_button_map(mapping: dict) -> None:
    try:
        os.makedirs(os.path.dirname(CONTROLS_FILE), exist_ok=True)
        with open(CONTROLS_FILE, "w", encoding="utf-8") as f:
            json.dump(mapping, f, indent=2)
    except Exception:
        pass

def run_manual_button_mapper() -> bool:
    """Blocking mini-wizard to manually map controller buttons.
    Returns True if a complete map was saved and applied.
    """
    if pygame.joystick.get_count() <= 0:
        return False

    order = [
        ("A", t("btn_desc_a")),
        ("B", t("btn_desc_b")),
        ("X", t("btn_desc_x")),
        ("Y", t("btn_desc_y")),
        ("LB", t("btn_desc_lb")),
        ("RB", t("btn_desc_rb")),
        ("BACK", t("btn_desc_back")),
        ("START", t("btn_desc_start")),
    ]
    mapping: dict[str,int] = {}

    hold_ms_required = 500
    last = None
    progress = 0
    start_ts = 0

    # Simple overlay panel renderer
    def draw_panel(title: str, desc: str, prog: float):
        draw_background(screen)
        cx, cy = W//2, H//2
        box_w, box_h = min(S(700), W - S(80)), S(280)
        rect = pygame.Rect(cx - box_w//2, cy - box_h//2, box_w, box_h)
        pygame.draw.rect(screen, CARD, rect, border_radius=12)
        pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=12)
        draw_text(screen, t("controller_setup"), FONT_BIG, FG, (rect.x + S(16), rect.y + S(12)))
        draw_text(screen, title, FONT, FG, (rect.x + S(16), rect.y + S(64)))
        draw_text(screen, desc, FONT_SMALL, MUTED, (rect.x + S(16), rect.y + S(96)))
        # progress bar
        bar_x, bar_y, bar_w, bar_h = rect.x + S(16), rect.y + box_h - S(60), box_w - S(32), S(20)
        pygame.draw.rect(screen, (30, 34, 44), (bar_x, bar_y, bar_w, bar_h), border_radius=6)
        fill_w = int(bar_w * max(0.0, min(1.0, prog)))
        if fill_w > 0:
            pygame.draw.rect(screen, ACCENT, (bar_x, bar_y, fill_w, bar_h), border_radius=6)
        pygame.draw.rect(screen, (200,200,210), (bar_x, bar_y, bar_w, bar_h), width=2, border_radius=6)
        pygame.display.flip()

    idx = 0
    # Consume stale events
    pygame.event.get()
    while idx < len(order):
        label, desc = order[idx]
        title = t("hold_button_for").format(label=label)
        draw_panel(title, desc, progress/hold_ms_required)
        for e in pygame.event.get():
            if e.type == pygame.QUIT:
                return False
            # Allow cancel with Escape or B/Back
            if e.type == pygame.KEYDOWN and e.key == pygame.K_ESCAPE:
                return False
            if e.type == pygame.JOYBUTTONDOWN:
                if last is None:
                    last = (e.button, pygame.time.get_ticks())
                    start_ts = last[1]
                elif last and last[0] != e.button:
                    # restart hold if changed
                    last = (e.button, pygame.time.get_ticks())
                    start_ts = last[1]
            if e.type == pygame.JOYBUTTONUP:
                if last and e.button == last[0]:
                    last = None
                    progress = 0
        if last is not None:
            now = pygame.time.get_ticks()
            progress = now - start_ts
            draw_panel(title, desc, progress/hold_ms_required)
            if progress >= hold_ms_required:
                mapping[label] = last[0]
                last = None
                progress = 0
                idx += 1
                # small debounce delay
                pygame.time.wait(200)
        pygame.time.wait(10)

    # Persist and apply
    _save_button_map(mapping)
    _apply_saved_button_map_if_any()
    return True

def set_pad_style_choice(choice: str) -> None:
    """Set or clear the user-selected controller layout.
    choice: 'auto', 'xbox', 'playstation', 'nintendo', 'generic'
    """
    global PAD_STYLE_USER_OVERRIDE, PAD_STYLE
    choice = (choice or "").strip().lower()
    if choice == "auto":
        PAD_STYLE_USER_OVERRIDE = None
        PAD_STYLE = detect_pad_style()
    elif choice in ("xbox", "playstation", "nintendo", "generic"):
        PAD_STYLE_USER_OVERRIDE = choice
        PAD_STYLE = choice
    else:
        # Ignore invalid, keep current
        return
    update_button_mapping()

# Keyboard hint mapping for visible prompts when no gamepad
KEYBOARD_HINT_MAP: Dict[str, str] = {
    "A": "Enter",
    "B": "Esc",
    "X": "X",
    "Y": "A",  # Select all
    "START": "Space",
    "LB": "PgUp",
    "RB": "PgDn",
    "BACK": "AltGr",
}
def _try_load(path: str):
    try:
        return pygame.image.load(path).convert_alpha()
    except Exception:
        return None


def _from_url(url: str | None, verbose: bool = False):
    """
    Download image from URL.
    Set verbose=True to print error messages (useful for critical resources).
    By default, errors are silent since this is often used with fallback URLs.
    """
    if not url:
        return None
    try:
        data = fetch_url_with_retry(
            url,
            headers={"User-Agent": "BUA-Icons"},
            timeout=5,
            retries=0  # No retries for icons - fail fast and try next fallback
        )
        if verbose:
            print(f"[BUA] Successfully downloaded: {url}")
        return pygame.image.load(io.BytesIO(data)).convert_alpha()
    except Exception:
        # Silent failure - this is expected when trying multiple fallback URLs
        return None

def init_assets():
    global LOGO_SURF, WHEEL_SURF, BACKGROUND_SURF, BUTTON_ICONS
    LOGO_SURF = None
    WHEEL_SURF = None
    BUTTON_ICONS = {}
    # Preferred watermark/background logo (try hosted first)
    if DEFAULT_BUTTONS_BASE_URL:
        remote_logo = _from_url(DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/batocera-unofficial-addons.png")
        if remote_logo is not None:
            LOGO_SURF = remote_logo
    if LOGO_SURF is None:
        logo_candidates = [
            os.path.join(os.sep, "images", "BatoceraUnofficialAddons.png"),
            os.path.join("images", "BatoceraUnofficialAddons.png"),
            os.path.join("assets", "logo.png"),
            "logo.png",
            os.path.join("assets", "images", "logo.png"),
            os.path.join("images", "batocera-unofficial-addons.png"),
        ]
        for p in logo_candidates:
            if os.path.exists(p):
                surf = _try_load(p)
                if surf is not None:
                    LOGO_SURF = surf
                    break

    # Top bar text-replacement (Wheel) image
    if DEFAULT_BUTTONS_BASE_URL:
        remote_wheel = _from_url(DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/batocera-unofficial-addons-wheel.png")
        if remote_wheel is not None:
            WHEEL_SURF = remote_wheel
    if WHEEL_SURF is None:
        wheel_candidates = [
            os.path.join(os.sep, "images", "BatoceraUnofficialAddons_Wheel.png"),
            os.path.join("images", "BatoceraUnofficialAddons_Wheel.png"),
            os.path.join("images", "batocera-unofficial-addons-wheel.png"),
        ]
        for p in wheel_candidates:
            if os.path.exists(p):
                surf = _try_load(p)
                if surf is not None:
                    WHEEL_SURF = surf
                    break

    # Optional ABXY icons
    # 1) Try explicit per-key hosted URLs
    for key in ("A", "B", "X", "Y"):
        if key in BUTTON_ICONS:
            continue
        env_url = os.environ.get(f"BUA_BTN_{key}_URL")
        surf = _from_url(env_url)
        if surf is not None:
            BUTTON_ICONS[key] = surf

    # 2) Try files if not provided by base64
    base_dirs = [
        os.path.join(os.sep, "images", "buttons"),
        os.path.join("images", "buttons"),
        os.path.join("assets", "buttons"),
        "images",
        "assets",
        os.curdir,
    ]
    name_patterns = [
        "btn_{k}.png",
        "button_{k}.png",
        "{k}.png",
        "abxy_{k}.png",
    ]
    for key in ("a", "b", "x", "y"):
        if key.upper() in BUTTON_ICONS:
            continue
        env_key = os.environ.get(f"BUA_BTN_{key.upper()}")
        surf = None
        if env_key and os.path.exists(env_key):
            surf = _try_load(env_key)
        if surf is None:
            for d in base_dirs:
                for pat in name_patterns:
                    p = os.path.join(d, pat.format(k=key))
                    if os.path.exists(p):
                        surf = _try_load(p)
                        if surf is not None:
                            break
                if surf is not None:
                    break
        if surf is not None:
            BUTTON_ICONS[key.upper()] = surf

    # 2b) Try a common hosted base URL if provided
    if DEFAULT_BUTTONS_BASE_URL:
        for key in ("a", "b", "x", "y"):
            kU = key.upper()
            if kU in BUTTON_ICONS:
                continue
            # include uppercase/hyphen variants preferred by the repo
            repo_names = [
                f"btn_{key.upper()}.png",
                f"btn-{key.upper()}.png",
            ]
            tried = repo_names + name_patterns
            for pat in tried:
                # pat may already be a full name
                if "{k}" in pat:
                    fname = pat.format(k=key)
                else:
                    fname = pat
                url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/" + fname
                surf = _from_url(url)
                if surf is not None:
                    BUTTON_ICONS[kU] = surf
                    break

    # Load PlayStation synonyms (CROSS/CIRCLE/SQUARE/TRIANGLE) from URLs/files
    ps_keys = ["CROSS", "CIRCLE", "SQUARE", "TRIANGLE"]
    # per-key URL
    for key in ps_keys:
        if key in BUTTON_ICONS:
            continue
        env_url = os.environ.get(f"BUA_BTN_{key}_URL")
        surf = _from_url(env_url)
        if surf is not None:
            BUTTON_ICONS[key] = surf
    # common base URL
    if DEFAULT_BUTTONS_BASE_URL:
        # Exact names from the provided repo
        direct_map = {
            "cross": "btn_cro.png",
            "circle": "btn_cir.png",
            "square": "btn_squ.png",
            "triangle": "btn_tri.png",
        }
        ps_name_patterns = [
            "ps_{k}.png",
            "playstation_{k}.png",
            "button_{k}.png",
        ]
        for key in ["cross", "circle", "square", "triangle"]:
            kU = key.upper()
            if kU in BUTTON_ICONS:
                continue
            # try exact repo filename first
            url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/" + direct_map[key]
            surf = _from_url(url)
            if surf is not None:
                BUTTON_ICONS[kU] = surf
                continue
            for pat in ps_name_patterns:
                url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/" + pat.format(k=key)
                surf = _from_url(url)
                if surf is not None:
                    BUTTON_ICONS[kU] = surf
                    break

    # 3) As a final fallback, procedurally draw simple ABXY icons
    def make_icon(fill_dir: str) -> pygame.Surface:
        size = 96
        surf = pygame.Surface((size, size), pygame.SRCALPHA)
        cx, cy = size // 2, size // 2
        r = size // 2 - 2
        # Diamond (rotated square)
        pts = [(cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)]
        pygame.draw.polygon(surf, (255, 255, 255), pts)
        pygame.draw.polygon(surf, (0, 0, 0), pts, width=4)
        # Circle positions
        off = r - 22
        positions = {
            "Y": (cx, cy - off),
            "B": (cx + off, cy),
            "A": (cx, cy + off),
            "X": (cx - off, cy),
        }
        for k, (px, py) in positions.items():
            if k == fill_dir:
                pygame.draw.circle(surf, (0, 0, 0), (px, py), 14)
                pygame.draw.circle(surf, (0, 0, 0), (px, py), 14, width=2)
            else:
                pygame.draw.circle(surf, (0, 0, 0), (px, py), 14, width=3)
                pygame.draw.circle(surf, (255, 255, 255), (px, py), 13, width=0)
        return surf

    for key in ("A", "B", "X", "Y"):
        if key not in BUTTON_ICONS:
            BUTTON_ICONS[key] = make_icon(key)

    # Load Start/Play icon for Start button if available
    if "START" not in BUTTON_ICONS:
        # Try hosted play-button.png first
        play_url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/play-button.png" if DEFAULT_BUTTONS_BASE_URL else None
        start_surf = _from_url(play_url)
        if start_surf is None:
            # Look in local common paths
            for p in [
                os.path.join("images", "play-button.png"),
                os.path.join("assets", "play-button.png"),
                "play-button.png",
            ]:
                if os.path.exists(p):
                    start_surf = _try_load(p)
                    if start_surf is not None:
                        break
        if start_surf is not None:
            BUTTON_ICONS["START"] = start_surf

    # Load Back/Select icon if available (e.g., btn_sel.png on the hosted repo)
    if "BACK" not in BUTTON_ICONS:
        back_candidates = [
            "btn_sel.png",
            "select.png",
            "btn_back.png",
            "back.png",
        ]
        back_surf = None
        # Try hosted first
        if DEFAULT_BUTTONS_BASE_URL:
            for n in back_candidates:
                url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/" + n
                back_surf = _from_url(url)
                if back_surf is not None:
                    break
        # Local fallbacks
        if back_surf is None:
            for n in back_candidates:
                for p in [os.path.join("images", n), os.path.join("assets", n), n]:
                    if os.path.exists(p):
                        back_surf = _try_load(p)
                        if back_surf is not None:
                            break
                if back_surf is not None:
                    break
        if back_surf is not None:
            BUTTON_ICONS["BACK"] = back_surf

    # Load shoulder button icons (LB/RB) if available
    if "LB" not in BUTTON_ICONS or "RB" not in BUTTON_ICONS:
        def try_load_button(filename: str):
            # Try remote URL first
            if DEFAULT_BUTTONS_BASE_URL:
                url = DEFAULT_BUTTONS_BASE_URL.rstrip("/") + "/" + filename
                surf = _from_url(url)
                if surf is not None:
                    return surf
            # Local fallbacks
            for p in [os.path.join("images", filename), os.path.join("assets", filename), filename]:
                if os.path.exists(p):
                    s = _try_load(p)
                    if s is not None:
                        return s
            return None

        if "LB" not in BUTTON_ICONS:
            lb_surf = try_load_button("btn_lb.png")
            if lb_surf is not None:
                BUTTON_ICONS["LB"] = lb_surf
        if "RB" not in BUTTON_ICONS:
            rb_surf = try_load_button("btn_rb.png")
            if rb_surf is not None:
                BUTTON_ICONS["RB"] = rb_surf

    # Build a textured background once
    BACKGROUND_SURF = pygame.Surface((W, H)).convert()
    BACKGROUND_SURF.fill(BG)
    # Subtle vertical gradient
    grad = pygame.Surface((W, H), pygame.SRCALPHA)
    for i in range(H):
        a = int(40 * (i / H))
        pygame.draw.line(grad, (0, 0, 0, a), (0, i), (W, i))
    BACKGROUND_SURF.blit(grad, (0, 0))
    # Vignette
    vignette = pygame.Surface((W, H), pygame.SRCALPHA)
    steps = 10
    for s in range(steps):
        r = int(max(W, H) * (0.6 + 0.4 * s / steps))
        alpha = int(12 + 22 * s / steps)
        pygame.draw.circle(vignette, (0, 0, 0, alpha), (W // 2, H // 2), r, width=3)
    BACKGROUND_SURF.blit(vignette, (0, 0))
    # Large logo background, centered and filling the whole screen
    if LOGO_SURF is not None:
        try:
            # Scale-to-cover (fill), keep aspect ratio, center
            cover_scale = max(W / LOGO_SURF.get_width(), H / LOGO_SURF.get_height())
            new_w = max(1, int(LOGO_SURF.get_width() * cover_scale))
            new_h = max(1, int(LOGO_SURF.get_height() * cover_scale))
            wm = pygame.transform.smoothscale(LOGO_SURF, (new_w, new_h)).convert_alpha()
            # Subtle dim so foreground text remains readable
            tint = pygame.Surface(wm.get_size(), pygame.SRCALPHA)
            tint.fill((0, 0, 0, 210))
            wm.blit(tint, (0, 0), special_flags=pygame.BLEND_RGBA_SUB)
            BACKGROUND_SURF.blit(wm, ((W - wm.get_width()) // 2, (H - wm.get_height()) // 2))
        except Exception:
            pass

def draw_background(surf):
    if BACKGROUND_SURF is not None:
        surf.blit(BACKGROUND_SURF, (0, 0))
    else:
        # Fallback if assets haven't loaded yet
        surf.fill(BG)

# Assets will be loaded during splash screen
# init_assets() - moved to play_splash_and_load()

# Handle window resizing (windowed mode only - safe for testing)
def handle_resize(new_w: int, new_h: int):
    if not os.environ.get("BUA_WINDOWED"):
        return
    global screen, W, H, UI_SCALE, FONT, FONT_SMALL, FONT_BIG
    # Safe for windowed mode - does not affect KMS/DRM
    screen = pygame.display.set_mode((new_w, new_h), pygame.RESIZABLE)
    W, H = screen.get_size()
    UI_SCALE = max(1.0, min(W / 1280.0, H / 720.0))
    FONT, FONT_SMALL, FONT_BIG = load_fonts()
    init_assets()

# Controller support
pygame.joystick.init()
JOYS = [pygame.joystick.Joystick(i) for i in range(pygame.joystick.get_count())]
for j in JOYS:
    j.init()
LAST_JOY_COUNT = pygame.joystick.get_count()

# Analog stick support for navigation (for arcade cabinets without dpad)
ANALOG_DEADZONE = 0.5  # Threshold for detecting stick movement
ANALOG_REPEAT_DELAY = 0.15  # Seconds between repeated inputs when holding stick
last_analog_vertical_time = 0.0  # Track timing for vertical stick movement
last_analog_horizontal_time = 0.0  # Track timing for horizontal stick movement
last_analog_vertical_state = 0  # -1 (up), 0 (neutral), 1 (down)
last_analog_horizontal_state = 0  # -1 (left), 0 (neutral), 1 (right)


def detect_pad_style() -> str:
    # If user picked a style in Settings, prefer that here
    if PAD_STYLE_USER_OVERRIDE in ("xbox", "playstation", "nintendo", "generic"):
        return PAD_STYLE_USER_OVERRIDE
    forced = os.environ.get("BUA_PAD_STYLE", "").strip().lower()
    if forced in ("xbox", "playstation", "nintendo", "generic"):
        return forced
    # Heuristic from connected joystick names
    try:
        if pygame.joystick.get_count() == 0:
            return "keyboard"
        names = []
        for i in range(pygame.joystick.get_count()):
            try:
                js = pygame.joystick.Joystick(i)
                nm = js.get_name() or ""
                names.append(nm.lower())
            except Exception:
                pass
        s = " ".join(names)
        if any(k in s for k in ["sony", "playstation", "dualsense", "dualshock", "ps4", "ps5"]):
            return "playstation"
        if any(k in s for k in ["xbox", "xinput", "microsoft", "360", "one", "series"]):
            return "xbox"
        if any(k in s for k in ["nintendo", "switch", "pro controller"]):
            return "nintendo"
    except Exception:
        pass
    return "keyboard" if pygame.joystick.get_count() == 0 else "xbox"


# Decide pad style (updates dynamically on connect/disconnect)
PAD_STYLE = detect_pad_style()
update_button_mapping()

def input_style_label() -> str:
    """Return a concise label of the current input device.
    - If a gamepad is connected: show its reported device name (first device).
    - If multiple pads: append "+N" for additional devices.
    - If no gamepad: show "Keyboard".
    """
    try:
        count = pygame.joystick.get_count()
        if count <= 0:
            return "Keyboard"
        name = JOYS[0].get_name() if JOYS else "Controller"
        name = name or "Controller"
        if count > 1:
            return f"{name} (+{count-1})"
        return name
    except Exception:
        return "Keyboard"


def process_analog_navigation(events) -> tuple:
    """
    Process analog stick events for navigation (supports arcade cabinets).
    Returns tuple: (vertical_movement, horizontal_movement)
    - vertical_movement: -1 (up), 0 (none), 1 (down)
    - horizontal_movement: -1 (left), 0 (none), 1 (right)

    Uses deadzone and repeat delay to prevent accidental inputs.
    """
    global last_analog_vertical_time, last_analog_horizontal_time
    global last_analog_vertical_state, last_analog_horizontal_state

    vertical = 0
    horizontal = 0
    current_time = pygame.time.get_ticks() / 1000.0

    for e in events:
        if e.type == pygame.JOYAXISMOTION:
            # Axis 0 = Left stick X (horizontal), Axis 1 = Left stick Y (vertical)
            if e.axis == 1:  # Vertical axis (left stick Y)
                if e.value < -ANALOG_DEADZONE:  # Up
                    new_state = -1
                elif e.value > ANALOG_DEADZONE:  # Down
                    new_state = 1
                else:
                    new_state = 0
                    last_analog_vertical_state = 0

                # Only trigger if state changed or enough time passed
                if new_state != 0:
                    if (new_state != last_analog_vertical_state or
                        current_time - last_analog_vertical_time >= ANALOG_REPEAT_DELAY):
                        vertical = new_state
                        last_analog_vertical_time = current_time
                        last_analog_vertical_state = new_state

            elif e.axis == 0:  # Horizontal axis (left stick X)
                if e.value < -ANALOG_DEADZONE:  # Left
                    new_state = -1
                elif e.value > ANALOG_DEADZONE:  # Right
                    new_state = 1
                else:
                    new_state = 0
                    last_analog_horizontal_state = 0

                # Only trigger if state changed or enough time passed
                if new_state != 0:
                    if (new_state != last_analog_horizontal_state or
                        current_time - last_analog_horizontal_time >= ANALOG_REPEAT_DELAY):
                        horizontal = new_state
                        last_analog_horizontal_time = current_time
                        last_analog_horizontal_state = new_state

    return (vertical, horizontal)


def draw_text(surf, text, font, color, pos):
    img = font.render(text, True, color)
    surf.blit(img, pos)


def wrap(text: str, width: int, font) -> List[str]:
    words = text.split()
    lines, line = [], ""
    for w in words:
        test = (line + " " + w).strip()
        if font.size(test)[0] <= width:
            line = test
        else:
            lines.append(line)
            line = w
    if line:
        lines.append(line)
    return lines


ICON_RENDER_CACHE: Dict[tuple, pygame.Surface] = {}


def _scale_and_style_icon(icon: pygame.Surface, w: int, h: int) -> pygame.Surface:
    """Scale icon and optionally invert colors for visibility.
    Uses cache keyed by (id(icon), w, h, mode).
    Control with env var BUA_ICON_INVERT: '0' (off), '1' (force), 'auto' (default).
    """
    mode = (os.environ.get("BUA_ICON_INVERT", "auto") or "auto").lower()
    key = (id(icon), w, h, mode)
    cached = ICON_RENDER_CACHE.get(key)
    if cached is not None:
        return cached
    try:
        scaled = pygame.transform.smoothscale(icon, (w, h))
    except Exception:
        scaled = pygame.transform.scale(icon, (w, h))

    def avg_luma(s: pygame.Surface) -> float:
        # Sample every 2px to keep it fast and skip transparent pixels
        w_, h_ = s.get_size()
        total = 0
        count = 0
        for yy in range(0, h_, 2):
            for xx in range(0, w_, 2):
                r, g, b, a = s.get_at((xx, yy))
                if a < 10:
                    continue
                total += 0.2126 * r + 0.7152 * g + 0.0722 * b
                count += 1
        return (total / max(1, count)) if count else 255.0

    def invert_inplace(s: pygame.Surface) -> None:
        w_, h_ = s.get_size()
        s.lock()
        try:
            for yy in range(h_):
                for xx in range(w_):
                    r, g, b, a = s.get_at((xx, yy))
                    if a == 0:
                        continue
                    s.set_at((xx, yy), (255 - r, 255 - g, 255 - b, a))
        finally:
            s.unlock()

    if mode == "1" or mode == "true" or mode == "on":
        out = scaled.copy()
        invert_inplace(out)
        ICON_RENDER_CACHE[key] = out
        return out
    if mode == "auto":
        l = avg_luma(scaled)
        # If icon is dark (low luma), invert to brighten on dark background
        if l < 90.0:
            out = scaled.copy()
            invert_inplace(out)
            ICON_RENDER_CACHE[key] = out
            return out
    ICON_RENDER_CACHE[key] = scaled
    return scaled


def draw_hints_line(surf, hint_text: str, font, color, pos):
    """Draw a hint line, replacing A/B/X/Y with icons when available.
    Accepts separators '|' or ',' and segments like 'A=toggle'.
    """
    x, y = pos
    segments = [s.strip() for s in re.split(r"[|,]", hint_text) if s.strip()]
    # Layout tuning
    sep_text = " | "
    icon_label_gap = 8  # px between icon/keycap and label
    segment_gap_extra = 4  # extra px after separator
    for i, seg in enumerate(segments):
        if "=" in seg:
            key, label = seg.split("=", 1)
            key = key.strip().upper()
 
            raw_label = label.strip()
 
            def capfirst(s: str) -> str:
 
                return s[:1].upper() + s[1:] if s else s
 
            label = capfirst(raw_label)
            # Remap logical key to current controller style
            mapped = STYLE_ICON_MAP.get(PAD_STYLE, STYLE_ICON_MAP["generic"]).get(key, key)
            if key == "START":
                mapped = "START"
            icon = BUTTON_ICONS.get(mapped) or BUTTON_ICONS.get(key)
            # Keyboard style: draw keycaps instead of icons
            if PAD_STYLE == "keyboard":
                kb = KEYBOARD_HINT_MAP.get(key) or KEYBOARD_HINT_MAP.get(mapped)
                if kb:
                    # Support combos like Ctrl+A
                    tokens = [t.strip() for t in kb.split("+")]
                    for t_i, tok in enumerate(tokens):
                        # draw keycap
                        pad_x = 6
                        pad_y = 2
                        txt_img = font.render(tok, True, color)
                        kw, kh = txt_img.get_width() + pad_x*2, txt_img.get_height() + pad_y*2
                        rect = pygame.Rect(x, y + (font.get_height() - kh)//2, kw, kh)
                        pygame.draw.rect(surf, (240, 243, 248), rect, border_radius=6)
                        pygame.draw.rect(surf, (120, 130, 150), rect, width=2, border_radius=6)
                        surf.blit(txt_img, (rect.x + pad_x, rect.y + pad_y))
                        x += kw
                        if t_i < len(tokens) - 1:
                            plus_img = font.render("+", True, color)
                            surf.blit(plus_img, (x + 4, y))
                            x += plus_img.get_width() + 8
                    if label:
                        # small gap before label text
                        x += icon_label_gap
                        img = font.render(label, True, color)
                        surf.blit(img, (x, y))
                        x += img.get_width()
                    # done with this segment — draw separator here to keep spacing
                    if i < len(segments) - 1:
                        sep_img = font.render(sep_text, True, color)
                        surf.blit(sep_img, (x, y))
                        x += sep_img.get_width() + segment_gap_extra
                    continue
                # If no kb mapping, fall back to icon/text below
            if icon is not None:
                # Preserve aspect ratio: scale by target height and derive width
                h = max(16, int(font.get_height() * 0.9))
                iw, ih = icon.get_width(), icon.get_height() or 1
                w = max(1, int(iw * (h / ih)))
                icon_s = _scale_and_style_icon(icon, w, h)
                surf.blit(icon_s, (x, y - (h - font.get_height()) // 2))
                x += w + icon_label_gap
                if label:
                    img = font.render(label, True, color)
                    surf.blit(img, (x, y))
                    x += img.get_width()
            else:
                txt = f"{key}={label}" if label else key
                img = font.render(txt, True, color)
                surf.blit(img, (x, y))
                x += img.get_width()
        else:
            img = font.render(seg, True, color)
            surf.blit(img, (x, y))
            x += img.get_width()
        if i < len(segments) - 1:
            sep_img = font.render(sep_text, True, color)
            surf.blit(sep_img, (x, y))
            x += sep_img.get_width() + segment_gap_extra

def draw_hints_block_right(surf, hint_text: str, font, color, pos, line_gap: int = 6):
    """Draw hints one per line, right-aligned to pos.x.
    Supports the same syntax as draw_hints_line for segments: 'A=Action | B=Back'.
    """
    rx, y = pos
    segments = [s.strip() for s in re.split(r"[|,]", hint_text) if s.strip()]

    def measure_and_draw(seg: str, draw: bool, y_draw: int) -> int:
        x_local = 0
        # Copy of single-segment rendering from draw_hints_line
        if "=" in seg:
            key, label = seg.split("=", 1)
            key = key.strip().upper()
            raw_label = label.strip()
            def capfirst(s: str) -> str:
                return s[:1].upper() + s[1:] if s else s
            label = capfirst(raw_label)
            mapped = STYLE_ICON_MAP.get(PAD_STYLE, STYLE_ICON_MAP["generic"]).get(key, key)
            if key == "START":
                mapped = "START"
            icon = BUTTON_ICONS.get(mapped) or BUTTON_ICONS.get(key)
            if PAD_STYLE == "keyboard":
                kb = KEYBOARD_HINT_MAP.get(key) or KEYBOARD_HINT_MAP.get(mapped)
                if kb:
                    tokens = [t.strip() for t in kb.split("+")]
                    for t_i, tok in enumerate(tokens):
                        txt_img = font.render(tok, True, color)
                        kw, kh = txt_img.get_width() + 12, txt_img.get_height() + 4
                        if draw:
                            rect = pygame.Rect(rx - (kw + x_local), y_draw + (font.get_height() - kh)//2, kw, kh)
                            pygame.draw.rect(surf, (240,243,248), rect, border_radius=6)
                            pygame.draw.rect(surf, (120,130,150), rect, width=2, border_radius=6)
                            surf.blit(txt_img, (rect.x + 6, rect.y + 2))
                        x_local += kw
                        if t_i < len(tokens) - 1:
                            plus_img = font.render("+", True, color)
                            if draw:
                                surf.blit(plus_img, (rx - (x_local + plus_img.get_width() + 8), y_draw))
                            x_local += plus_img.get_width() + 8
                    if label:
                        img = font.render(label, True, color)
                        if draw:
                            surf.blit(img, (rx - (x_local + 8 + img.get_width()), y_draw))
                        x_local += 8 + img.get_width()
                    return x_local
            if icon is not None:
                h = max(16, int(font.get_height() * 0.9))
                iw, ih = icon.get_width(), icon.get_height() or 1
                w = max(1, int(iw * (h / ih)))
                if draw:
                    icon_s = _scale_and_style_icon(icon, w, h)
                    surf.blit(icon_s, (rx - (x_local + w), y_draw - (h - font.get_height()) // 2))
                x_local += w + 8
                if label:
                    img = font.render(label, True, color)
                    if draw:
                        surf.blit(img, (rx - (x_local + img.get_width()), y_draw))
                    x_local += img.get_width()
                return x_local
            # fallback text
            txt = f"{key}={label}" if label else key
            img = font.render(txt, True, color)
            if draw:
                surf.blit(img, (rx - (x_local + img.get_width()), y_draw))
            x_local += img.get_width()
            return x_local
        else:
            img = font.render(seg, True, color)
            if draw:
                surf.blit(img, (rx - img.get_width(), y_draw))
            return img.get_width()

    y_cursor = y
    for seg in segments:
        w = measure_and_draw(seg, False, y_cursor)
        measure_and_draw(seg, True, y_cursor)
        y_cursor += font.get_height() + line_gap


def draw_persistent_hints(surf) -> None:
    """Draw persistent hints - currently disabled as hints are shown inline on each screen."""
    pass

# ------------------------------
# Process runner with live log
# ------------------------------

class Runner:
    def __init__(self):
        self.lines: List[str] = []
        self.proc: subprocess.Popen | None = None
        self.lock = threading.Lock()
        self.done = False
        self.returncode: int | None = None
        self.error_output: str = ""
        self.last_dialog_title: str | None = None
        self.last_dialog_text: str | None = None
        self.last_dialog_type: str | None = None  # Type of dialog (msgbox, yesno, menu)
        self.last_dialog_items: List[str] = []  # Menu items (tag|description pairs)
        self.last_dialog_resp_file: str | None = None  # Response file path
        self.detected_urls: List[str] = []  # URLs found during installation
        self.url_shown = False  # Track if we've already shown the URL dialog
        self.last_line: str = ""  # Track previous line for context
        self.menu_request: dict | None = None  # Menu selection request
        self.menu_response: str | None = None  # User's menu selection response

    def append(self, text: str):
        with self.lock:
            for ln in text.splitlines():
                # Intercept dialog markers emitted by our wrapper
                if ln.startswith("__BUA_DIALOG__"):
                    # Expected formats:
                    # __BUA_DIALOG__ type=<type> title_b64=<...> text_b64=<...> items_b64=<...> resp=<file>
                    # or fallback: __BUA_DIALOG__ type=<type> title=<...> text=<...> items=<...> resp=<file>
                    print(f"[BUA Python] Detected __BUA_DIALOG__ marker: {ln[:100]}")
                    try:
                        parts = ln.split()
                        kv = {}
                        for p in parts[1:]:
                            if "=" in p:
                                k, v = p.split("=", 1)
                                kv[k] = v

                        # Extract dialog type
                        self.last_dialog_type = kv.get("type", "msgbox")
                        print(f"[BUA Python] Parsed dialog type: {self.last_dialog_type}, resp_file: {kv.get('resp')}")

                        # Extract title
                        if "title_b64" in kv:
                            self.last_dialog_title = base64.b64decode(kv["title_b64"]).decode("utf-8", "ignore")
                        elif "title" in kv:
                            self.last_dialog_title = kv["title"]

                        # Extract text
                        if "text_b64" in kv:
                            decoded_text = base64.b64decode(kv["text_b64"]).decode("utf-8", "ignore")
                            self.last_dialog_text = decoded_text.replace("\\n", "\n")
                        elif "text" in kv:
                            self.last_dialog_text = kv["text"].replace("\\n", "\n")

                        # Extract menu items (pipe-separated)
                        if "items_b64" in kv:
                            decoded_items = base64.b64decode(kv["items_b64"]).decode("utf-8", "ignore")
                            self.last_dialog_items = decoded_items.split("|") if decoded_items else []
                        elif "items" in kv:
                            self.last_dialog_items = kv["items"].split("|") if kv["items"] else []

                        # Extract response file path
                        self.last_dialog_resp_file = kv.get("resp")

                    except Exception as e:
                        # If parsing fails, log the error
                        print(f"[BUA Python] Error parsing dialog marker: {e}")
                        import traceback
                        traceback.print_exc()
                    continue

                # Intercept menu selection requests
                if ln.startswith("__BUA_MENU__"):
                    # Format: __BUA_MENU__ title=<...> options=<key1:Label1,key2:Label2,...>
                    try:
                        parts = ln.split(None, 1)[1]  # Get everything after __BUA_MENU__
                        import shlex
                        kv = {}
                        for token in shlex.split(parts):
                            if "=" in token:
                                k, v = token.split("=", 1)
                                kv[k] = v

                        if "title" in kv and "options" in kv:
                            # Parse options: "key1:Label1,key2:Label2"
                            options = []
                            for opt in kv["options"].split(","):
                                if ":" in opt:
                                    key, label = opt.split(":", 1)
                                    options.append((key.strip(), label.strip()))

                            self.menu_request = {
                                "title": kv["title"],
                                "options": options
                            }
                    except Exception as e:
                        print(f"Error parsing menu request: {e}")
                    continue
                self.lines.append(ln)

                # Detect important URLs in output (authentication links, etc.)
                if ("http://" in ln or "https://" in ln) and ln.strip():
                    # Check if this is an important URL (authentication, login, visit, etc.)
                    ln_lower = ln.lower()
                    # Look for auth-related keywords in current or previous line
                    is_important = any(keyword in ln_lower or keyword in self.last_line.lower()
                                     for keyword in ["authenticate", "login", "visit", "authorization", "auth", "setup"])

                    # Exclude warning/config/download URLs and wget/curl output
                    is_excluded = any(keyword in ln_lower for keyword in [
                        "warning", "see http", "config",
                        "download", "downloading", "fetching", "getting",
                        "curl", "wget", "github.com", "raw.githubusercontent",
                        "resolving", "connecting", "saving to", "http request sent",
                        "wohlsoft.ru", "sourceforge.net",
                        ".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico"
                    ]) or ln.strip().startswith("--20")  # Exclude wget timestamps like --2025-11-13

                    if is_important and not is_excluded:
                        # Include context if previous line had relevant text
                        if "authenticate" in self.last_line.lower() or "visit" in self.last_line.lower():
                            self.detected_urls.append(self.last_line.strip())
                        self.detected_urls.append(ln.strip())

                self.last_line = ln

                # keep log manageable
                if len(self.lines) > 1000:
                    self.lines = self.lines[-1000:]

    def run(self, cmd: str):
        # Execute the command and wait for completion
        # Add 'wait' to ensure all background processes finish
        full_cmd = f"({cmd}); wait"

        # Create a PTY so the subprocess has a controlling terminal.
        # Scripts like foclabroc's newswitch.sh redirect to /dev/tty, which
        # requires a controlling terminal — without one bash errors with
        # "No such device or address".
        master_fd, slave_fd = pty.openpty()

        def set_controlling_tty():
            os.setsid()
            fcntl.ioctl(slave_fd, termios.TIOCSCTTY, 0)

        self.proc = subprocess.Popen(
            ["bash", "-c", full_cmd],
            stdin=slave_fd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            preexec_fn=set_controlling_tty,
            text=True,
            bufsize=1,
        )
        os.close(slave_fd)
        self._pty_master = master_fd  # keep open so slave doesn't get SIGHUP
        def reader():
            assert self.proc and self.proc.stdout
            output_lines = []
            for line in self.proc.stdout:
                stripped = line.rstrip("\n")
                self.append(stripped)
                output_lines.append(stripped)
            self.proc.wait()
            self.returncode = self.proc.returncode
            # Store last 10 lines for error display
            self.error_output = "\n".join(output_lines[-10:])
            try:
                os.close(self._pty_master)
            except Exception:
                pass
            self.done = True
        t = threading.Thread(target=reader, daemon=True)
        t.start()

    def kill(self):
        if self.proc and self.proc.poll() is None:
            try:
                self.proc.terminate()
            except Exception:
                pass


# ------------------------------
# Screens
# ------------------------------

class BaseScreen:
    def handle(self, events):
        pass
    def update(self):
        pass
    def draw(self):
        pass


class MenuScreen(BaseScreen):
    def __init__(self, title: str, items: List[Tuple[str, str]]):
        self.title = title
        # Keep an immutable copy for filtering
        self.all_items = list(items)
        self.items = list(items)
        self.idx = 0
        self.stats = self.calculate_stats() if title == "Batocera Unofficial Add-Ons" else None
        self.search_mode = False
        self.search_query = ""
        self.keyboard = OnScreenKeyboard()

    def calculate_stats(self):
        """Calculate installation statistics"""
        history = load_history()
        total_installed = len([k for k in history if any(e['success'] for e in history[k])])
        
        # Count by category
        category_stats = {}
        for cat_name, app_list in CATEGORIES.items():
            installed = sum(1 for app in app_list if is_installed(app))
            category_stats[cat_name] = (installed, len(app_list))
        
        return {
            'total_installed': total_installed,
            'total_available': len(APPS),
            'category_stats': category_stats
        }

    def handle(self, events):
        # If in search mode, route input to on-screen keyboard
        if self.search_mode:
            key = self.keyboard.handle(events)
            if key:
                if key == "BACKSPACE":
                    self.search_query = self.search_query[:-1]
                elif key == "ENTER":
                    # Submit global search
                    q = self.search_query.lower().strip()
                    self.search_mode = False
                    if q:
                        # Gather matches across all categories/apps
                        def matches(k: str) -> bool:
                            if q in k.lower():
                                return True
                            return q in DESCRIPTIONS.get(k, "").lower()
                        all_keys = sorted(APPS.keys())
                        results = [k for k in all_keys if matches(k)]
                        if results:
                            push_screen(GlobalSearchScreen(query=self.search_query, app_keys=results))
                        else:
                            push_screen(NoResultsScreen(self.search_query))
                    else:
                        # Empty query: just close keyboard
                        pass
                elif key == "EXIT":
                    # Cancel search entirely
                    self.search_mode = False
                    self.search_query = ""
                else:
                    self.search_query += key
            # While typing, ignore other inputs
            return

        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.items)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.items)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                # Toggle search on the main menu with X
                if e.key == pygame.K_x:
                    self.search_mode = True
                    self.search_query = ""
                    return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.items)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.items)
                # Keyboard A -> Enter (activate per hints)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.activate()
                if e.key == pygame.K_ESCAPE:
                    if self.title != "Batocera Unofficial Add-Ons":
                        pop_screen()
                    else:
                        clean_exit(0)
            if e.type == pygame.JOYHATMOTION:
                # D-Pad
                x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.items)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.items)
            if e.type == pygame.JOYBUTTONDOWN:
                # Normalize to logical buttons via BTN_*
                if e.button in (BTN_A,):
                    self.activate()
                if e.button in (BTN_B, BTN_BACK):
                    if self.title != "Batocera Unofficial Add-Ons":
                        pop_screen()
                if e.button in (BTN_START,):
                    self.activate()
                # X button enters search
                if e.button == BTN_X:
                    self.search_mode = True
                    self.search_query = ""
                    return

    def filter_items(self):
        """(Unused during global search) Retained for potential future filtering."""
        self.items = list(self.all_items)
        self.idx = 0

    def activate(self):
        name, _desc = self.items[self.idx]
        # Map translated names back to English category keys
        category_map = {
            t("games"): "Games",
            t("windows_freeware"): "Windows Freeware",
            t("game_utilities"): "Game Utilities",
            t("system_utilities"): "System Utilities",
            t("developer_tools"): "Developer Tools",
            t("docker_menu"): "Docker Menu",
        }

        if name == t("exit"):
            clean_exit(0)
        if name in SPECIAL_TOPLEVEL_RUN:
            cmd = SPECIAL_TOPLEVEL_RUN[name]
            push_screen(RunListScreen([(name, cmd)], title=name))
            return
        if name == t("custom_wine"):
            push_screen(WineTypeMenu())
            return
        if name == t("settings"):
            push_screen(SettingsScreen())
            return
        if name == t("updater"):
            push_screen(UpdaterScreen())
            return
        # category -> check list screen
        english_name = category_map.get(name, name)
        if english_name in CATEGORIES:
            apps = sorted(CATEGORIES[english_name])
            push_screen(ChecklistScreen(category=name, app_keys=apps))

    def draw(self):
        draw_background(screen)
        header_y = S(18)
        header_h = 0
        try:
            if WHEEL_SURF is not None:
                # --- Trim transparent padding first ---
                trimmed_rect = WHEEL_SURF.get_bounding_rect()  # auto-detect non-transparent area
                trimmed = WHEEL_SURF.subsurface(trimmed_rect).copy()

                # --- Wheel logo height (set to 100)
                target_h = S(100)
                scale = target_h / trimmed.get_height()
                target_w = int(trimmed.get_width() * scale)
                wheel = pygame.transform.smoothscale(trimmed, (target_w, target_h))

            # --- Draw centered horizontally or aligned as before ---
                x = (screen.get_width() - target_w) // 2
                screen.blit(wheel, (x, header_y))
                header_h = target_h
            else:
                draw_text(screen, self.title, FONT_BIG, FG, (40, 30))
                header_h = FONT_BIG.get_height()
        except Exception:
            draw_text(screen, self.title, FONT_BIG, FG, (40, 30))
            header_h = FONT_BIG.get_height()

        # Search overlay when typing
        if self.search_mode:
            search_box = pygame.Rect(S(40), header_y + header_h + S(10), W - S(80), S(50))
            pygame.draw.rect(screen, CARD, search_box, border_radius=8)
            pygame.draw.rect(screen, ACCENT, search_box, width=2, border_radius=8)
            # Keyboard draws its own input at the top
            self.keyboard.draw(screen, self.search_query)
            return

        # Show stats on main menu
        if self.stats:
            # Place stats under the header/banner
            stats_y = header_y + header_h + S(12)
            total_text = (
                f"{t('installed')}: {self.stats['total_installed']} {t('of')} {self.stats['total_available']} {t('addons')}"
                f"  |  A={t('hint_open')}  |  X={t('hint_search')}  |  Back={t('hint_back_settings')}  |  {t('input')}: {input_style_label()}"
            )
            draw_hints_line(screen, total_text, FONT_SMALL, ACCENT, (S(40), stats_y))

        list_y = (stats_y + S(35)) if self.stats else (header_y + header_h + S(20))

        # Create reverse mapping from translated to English category names
        category_map = {
            t("games"): "Games",
            t("windows_freeware"): "Windows Freeware",
            t("game_utilities"): "Game Utilities",
            t("system_utilities"): "System Utilities",
            t("developer_tools"): "Developer Tools",
            t("docker_menu"): "Docker Menu",
        }

        # Scrollable cards sized to fit the screen height
        total = len(self.items)
        row_pitch = S(70)
        row_h = S(60)
        bottom_pad = S(40)
        avail_h = max(0, H - list_y - bottom_pad)
        rows = min(total, get_visible_items(avail_h, row_pitch))
        top = 0 if total <= rows else max(0, min(self.idx - rows // 2, total - rows))
        view = self.items[top:top + rows]

        x = S(40)
        for i, (name, desc) in enumerate(view):
            actual_idx = top + i
            y = list_y + i * row_pitch
            rect = pygame.Rect(x, y, W - S(80), row_h)
            pygame.draw.rect(screen, CARD, rect, border_radius=12)
            if actual_idx == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=12)

            # Category name
            draw_text(screen, name, FONT, FG, (rect.x + S(16), rect.y + S(10)))

            # Show category stats if available
            # Map translated name back to English for stats lookup
            english_name = category_map.get(name, name)
            if self.stats and english_name in self.stats['category_stats']:
                installed, total = self.stats['category_stats'][english_name]
                stat_text = f"[{installed}/{total}]"
                stat_color = ACCENT if installed > 0 else MUTED
                draw_text(screen, stat_text, FONT_SMALL, stat_color, (rect.x + S(16), rect.y + S(32)))
                desc_x = rect.x + S(90)
            else:
                desc_x = rect.x + S(16)

            # Description - calculate available width properly
            available_width = rect.x + rect.w - desc_x - S(16)  # Leave 16px padding on right
            lines = wrap(desc, available_width, FONT_SMALL)
            for li, ln in enumerate(lines[:2]):
                draw_text(screen, ln, FONT_SMALL, MUTED, (desc_x, rect.y + S(34) + li*S(18)))
            
            # per-card hint removed (now shown in top bar)


class ConfirmDialog(BaseScreen):
    def __init__(self, title: str, message: List[str], on_confirm, on_cancel):
        self.title = title
        self.message = message  # List of lines
        self.on_confirm = on_confirm
        self.on_cancel = on_cancel
        self.selected = 0  # 0 = Yes, 1 = No

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        _analog_v, analog_h = process_analog_navigation(events)
        if analog_h != 0:  # Left or Right
            self.selected = 1 - self.selected

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_LEFT, pygame.K_RIGHT):
                    self.selected = 1 - self.selected
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):  # Confirm (Enter)
                    self.activate()
                if e.key == pygame.K_ESCAPE:  # Cancel (Esc)
                    self.on_cancel()
                    pop_screen()
            if e.type == pygame.JOYHATMOTION:
                x, _y = e.value
                if x != 0:
                    self.selected = 1 - self.selected
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):  # A or Start
                    self.activate()
                if e.button in (BTN_B, BTN_BACK):  # B or Back
                    self.on_cancel()
                    pop_screen()

    def activate(self):
        if self.selected == 0:
            self.on_confirm()
        else:
            self.on_cancel()
        pop_screen()

    def draw(self):
        draw_background(screen)
        
        # Semi-transparent overlay
        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        screen.blit(overlay, (0, 0))
        
        # Dialog box
        dialog_w = 800
        dialog_h = 300
        dialog_x = (W - dialog_w) // 2
        dialog_y = (H - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        pygame.draw.rect(screen, CARD, dialog_rect, border_radius=15)
        pygame.draw.rect(screen, ACCENT, dialog_rect, width=3, border_radius=15)
        
        # Title
        draw_text(screen, self.title, FONT_BIG, FG, (dialog_x + 30, dialog_y + 30))
        
        # Message lines
        msg_y = dialog_y + 80
        for line in self.message:
            draw_text(screen, line, FONT, MUTED, (dialog_x + 30, msg_y))
            msg_y += 30
        
        # Buttons
        button_y = dialog_y + dialog_h - 70
        button_w = 150
        button_h = 45
        
        # Yes button
        yes_x = dialog_x + dialog_w // 2 - button_w - 20
        yes_rect = pygame.Rect(yes_x, button_y, button_w, button_h)
        yes_color = ACCENT if self.selected == 0 else CARD
        pygame.draw.rect(screen, yes_color, border_radius=8, rect=yes_rect)
        if self.selected == 0:
            pygame.draw.rect(screen, FG, yes_rect, width=3, border_radius=8)
        draw_text(screen, t("yes"), FONT, FG, (yes_x + 50, button_y + 10))
        
        # No button
        no_x = dialog_x + dialog_w // 2 + 20
        no_rect = pygame.Rect(no_x, button_y, button_w, button_h)
        no_color = (255, 100, 100) if self.selected == 1 else CARD
        pygame.draw.rect(screen, no_color, border_radius=8, rect=no_rect)
        if self.selected == 1:
            pygame.draw.rect(screen, FG, no_rect, width=3, border_radius=8)
        draw_text(screen, t("no"), FONT, FG, (no_x + 55, button_y + 10))


class InfoDialog(BaseScreen):
    def __init__(self, title: str, message: List[str], on_close=None):
        self.title = title
        self.message = message
        self.on_close = on_close

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE, pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.on_close:
                        try:
                            self.on_close()
                        except Exception:
                            pass
                    pop_screen()
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_B, BTN_BACK, BTN_START):  # A/B/Back/Start
                    if self.on_close:
                        try:
                            self.on_close()
                        except Exception:
                            pass
                    pop_screen()

    def draw(self):
        draw_background(screen)

        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        screen.blit(overlay, (0, 0))

        dialog_w = min(W - S(120), S(900))
        dialog_h = min(H - S(120), S(600))
        dialog_x = (W - dialog_w) // 2
        dialog_y = (H - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        pygame.draw.rect(screen, CARD, dialog_rect, border_radius=15)
        pygame.draw.rect(screen, ACCENT, dialog_rect, width=3, border_radius=15)

        draw_text(screen, self.title, FONT_BIG, FG, (dialog_x + S(30), dialog_y + S(30)))

        # Message box area
        msg_rect = pygame.Rect(dialog_x + S(30), dialog_y + S(90), dialog_w - S(60), dialog_h - S(160))
        pygame.draw.rect(screen, (30, 34, 44), msg_rect, border_radius=10)

        # Render multi-line text with wrapping
        y = msg_rect.y + S(10)
        for raw_line in self.message:
            if not raw_line:
                y += S(8)
                continue
            for ln in wrap(raw_line, msg_rect.w - S(20), FONT):
                if y > msg_rect.bottom - S(20):
                    break
                draw_text(screen, ln, FONT, (210, 215, 225), (msg_rect.x + S(10), y))
                y += S(22)

        # OK button
        btn_w, btn_h = S(120), S(45)
        btn_rect = pygame.Rect(dialog_x + (dialog_w - btn_w)//2, dialog_y + dialog_h - S(60), btn_w, btn_h)
        pygame.draw.rect(screen, ACCENT, btn_rect, border_radius=8)
        draw_text(screen, t("ok"), FONT, FG, (btn_rect.x + (btn_w - FONT.size(t("ok"))[0])//2, btn_rect.y + S(10)))


class ChangelogDialog(BaseScreen):
    """Display changelog on first run when content exists"""
    def __init__(self):
        pass

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE, pygame.K_RETURN, pygame.K_KP_ENTER):
                    mark_changelog_shown()
                    pop_screen()
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_B, BTN_BACK, BTN_START):
                    mark_changelog_shown()
                    pop_screen()

    def draw(self):
        draw_background(screen)

        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        screen.blit(overlay, (0, 0))

        dialog_w = min(W - S(120), S(900))
        dialog_h = min(H - S(120), S(700))
        dialog_x = (W - dialog_w) // 2
        dialog_y = (H - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        pygame.draw.rect(screen, CARD, dialog_rect, border_radius=15)
        pygame.draw.rect(screen, ACCENT, dialog_rect, width=3, border_radius=15)

        # Title
        title_text = "What's New"
        draw_text(screen, title_text, FONT_BIG, FG, (dialog_x + S(30), dialog_y + S(30)))

        # Changelog content area
        msg_rect = pygame.Rect(dialog_x + S(30), dialog_y + S(90), dialog_w - S(60), dialog_h - S(160))
        pygame.draw.rect(screen, (30, 34, 44), msg_rect, border_radius=10)

        # Render changelog text with wrapping
        y = msg_rect.y + S(15)
        for raw_line in CHANGELOG.split('\n'):
            if not raw_line:
                y += S(8)
                continue
            for ln in wrap(raw_line, msg_rect.w - S(20), FONT):
                if y > msg_rect.bottom - S(20):
                    break
                draw_text(screen, ln, FONT, (210, 215, 225), (msg_rect.x + S(10), y))
                y += S(22)

        # Close button
        btn_w, btn_h = S(120), S(45)
        btn_rect = pygame.Rect(dialog_x + (dialog_w - btn_w)//2, dialog_y + dialog_h - S(60), btn_w, btn_h)
        pygame.draw.rect(screen, ACCENT, btn_rect, border_radius=8)
        btn_text = t("ok")
        draw_text(screen, btn_text, FONT, FG, (btn_rect.x + (btn_w - FONT.size(btn_text)[0])//2, btn_rect.y + S(10)))


class InteractiveDialog(BaseScreen):
    """Dialog for yes/no questions, menu selections, and checklists from bash scripts"""
    def __init__(self, dialog_type: str, title: str, message: str, items: List[str], resp_file: str):
        """
        dialog_type: 'yesno', 'menu', or 'checklist'
        title: Dialog title
        message: Dialog message/question
        items: For menu/checklist: list of alternating tags, descriptions, and status (on/off). For yesno: empty list.
        resp_file: Path to file where response should be written
        """
        self.dialog_type = dialog_type
        self.title = title
        self.message = message.split("\n")  # Split into lines for rendering
        self.resp_file = resp_file
        self.idx = 0
        self.scroll_offset = 0

        if dialog_type == "menu":
            # Parse items as alternating tag/description pairs
            self.options = []
            for i in range(0, len(items), 2):
                if i + 1 < len(items):
                    tag = items[i]
                    desc = items[i + 1]
                    self.options.append((tag, desc))
            self.checked = []  # Not used for menu
        elif dialog_type == "checklist":
            # Parse items as alternating tag/description/status triples
            self.options = []
            self.checked = []
            for i in range(0, len(items), 3):
                if i + 2 < len(items):
                    tag = items[i]
                    desc = items[i + 1]
                    status = items[i + 2]
                    self.options.append((tag, desc))
                    # Status is "on" or "off"
                    self.checked.append(status.lower() == "on")
        else:  # yesno
            self.options = [("0", "Yes"), ("1", "No")]
            self.checked = []

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key == pygame.K_SPACE:
                    # Toggle checkbox for checklist mode
                    if self.dialog_type == "checklist" and 0 <= self.idx < len(self.checked):
                        self.checked[self.idx] = not self.checked[self.idx]
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.select()
                if e.key == pygame.K_ESCAPE:
                    self.cancel()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button == BTN_X:
                    # Toggle checkbox with X button
                    if self.dialog_type == "checklist" and 0 <= self.idx < len(self.checked):
                        self.checked[self.idx] = not self.checked[self.idx]
                if e.button in (BTN_A, BTN_START):
                    self.select()
                if e.button in (BTN_B, BTN_BACK):
                    self.cancel()

    def select(self):
        """User confirmed selection"""
        if self.dialog_type == "checklist":
            # For checklist, return quoted list of selected tags
            selected = [self.options[i][0] for i in range(len(self.options)) if self.checked[i]]
            response = " ".join(f'"{tag}"' for tag in selected)
            self.write_response(response)
        else:
            # For menu/yesno, return single tag
            tag, _label = self.options[self.idx]
            self.write_response(tag)
        pop_screen()

    def cancel(self):
        """User cancelled - write cancel response"""
        if self.dialog_type == "yesno":
            self.write_response("1")  # No/cancel
        else:  # menu/checklist
            self.write_response("")  # Empty string for cancel
        pop_screen()

    def write_response(self, response: str):
        """Write response to file so bash script can continue"""
        try:
            with open(self.resp_file, "w") as f:
                f.write(response)
        except Exception as e:
            print(f"Error writing response to {self.resp_file}: {e}")

    def draw(self):
        draw_background(screen)

        # Semi-transparent overlay
        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        screen.blit(overlay, (0, 0))

        # Dialog box
        dialog_w = min(W - S(80), S(900))
        dialog_h = min(H - S(100), S(700))
        dialog_x = (W - dialog_w) // 2
        dialog_y = (H - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        pygame.draw.rect(screen, CARD, dialog_rect, border_radius=15)
        pygame.draw.rect(screen, ACCENT, dialog_rect, width=3, border_radius=15)

        # Title
        draw_text(screen, self.title, FONT_BIG, FG, (dialog_x + S(30), dialog_y + S(30)))

        # Message box area
        msg_y = dialog_y + S(80)
        msg_h = S(120)
        msg_rect = pygame.Rect(dialog_x + S(30), msg_y, dialog_w - S(60), msg_h)
        pygame.draw.rect(screen, (30, 34, 44), msg_rect, border_radius=10)

        # Render message text
        y = msg_rect.y + S(10)
        for raw_line in self.message:
            if not raw_line:
                y += S(8)
                continue
            for ln in wrap(raw_line, msg_rect.w - S(20), FONT):
                if y > msg_rect.bottom - S(20):
                    break
                draw_text(screen, ln, FONT, (210, 215, 225), (msg_rect.x + S(10), y))
                y += S(22)

        # Hints
        if self.dialog_type == "checklist":
            hint = f"X={t('hint_toggle') or 'Toggle'} | A={t('hint_confirm') or 'Confirm'} | B={t('hint_cancel') or 'Cancel'}"
        else:
            hint = f"A={t('hint_select') or 'Select'} | B={t('hint_cancel') or 'Cancel'}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (dialog_x + S(30), msg_rect.bottom + S(15)))

        # Options list area
        list_y = msg_rect.bottom + S(50)
        list_h = dialog_h - (list_y - dialog_y) - S(30)
        item_h = S(50)

        # Calculate scrolling
        visible_items = get_visible_items(list_h, item_h)

        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1

        max_scroll = max(0, len(self.options) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))

        # Draw options (only visible ones)
        for i in range(self.scroll_offset, min(len(self.options), self.scroll_offset + visible_items)):
            tag, label = self.options[i]
            display_index = i - self.scroll_offset
            opt_y = list_y + display_index * item_h

            opt_rect = pygame.Rect(dialog_x + S(30), opt_y, dialog_w - S(60), item_h - S(5))

            if i == self.idx:
                pygame.draw.rect(screen, SELECT, opt_rect, border_radius=8)
                pygame.draw.rect(screen, ACCENT, opt_rect, width=3, border_radius=8)
            else:
                pygame.draw.rect(screen, (30, 34, 44), opt_rect, border_radius=8)

            # Draw checkbox for checklist mode
            text_x = opt_rect.x + S(15)
            if self.dialog_type == "checklist":
                # Draw checkbox
                checkbox_size = S(20)
                checkbox_x = opt_rect.x + S(15)
                checkbox_y = opt_rect.y + (opt_rect.h - checkbox_size) // 2
                checkbox_rect = pygame.Rect(checkbox_x, checkbox_y, checkbox_size, checkbox_size)

                # Box outline
                pygame.draw.rect(screen, FG, checkbox_rect, width=2, border_radius=3)

                # Checkmark if checked
                if self.checked[i]:
                    # Draw X mark
                    pygame.draw.line(screen, ACCENT,
                                   (checkbox_x + S(4), checkbox_y + S(4)),
                                   (checkbox_x + checkbox_size - S(4), checkbox_y + checkbox_size - S(4)), 3)
                    pygame.draw.line(screen, ACCENT,
                                   (checkbox_x + checkbox_size - S(4), checkbox_y + S(4)),
                                   (checkbox_x + S(4), checkbox_y + checkbox_size - S(4)), 3)

                text_x = checkbox_x + checkbox_size + S(15)

            draw_text(screen, label, FONT, FG, (text_x, opt_rect.y + S(12)))

        # Draw scroll indicators if needed
        if len(self.options) > visible_items:
            # Show up arrow if not at top
            if self.scroll_offset > 0:
                arrow_up_y = list_y - S(15)
                pygame.draw.polygon(screen, ACCENT, [
                    (dialog_x + dialog_w // 2, arrow_up_y - S(10)),
                    (dialog_x + dialog_w // 2 - S(10), arrow_up_y),
                    (dialog_x + dialog_w // 2 + S(10), arrow_up_y)
                ])

            # Show down arrow if not at bottom
            if self.scroll_offset + visible_items < len(self.options):
                arrow_down_y = list_y + list_h + S(5)
                pygame.draw.polygon(screen, ACCENT, [
                    (dialog_x + dialog_w // 2, arrow_down_y + S(10)),
                    (dialog_x + dialog_w // 2 - S(10), arrow_down_y),
                    (dialog_x + dialog_w // 2 + S(10), arrow_down_y)
                ])


class MenuSelectionDialog(BaseScreen):
    def __init__(self, title: str, options: List[Tuple[str, str]], callback):
        """
        options: List of (key, label) tuples
        callback: Function to call with selected key
        """
        self.title = title
        self.options = options
        self.callback = callback
        self.idx = 0
        self.scroll_offset = 0

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.options)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.options)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.select()
                if e.key == pygame.K_ESCAPE:
                    pop_screen()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.select()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen()

    def select(self):
        key, _label = self.options[self.idx]
        self.callback(key)
        pop_screen()

    def draw(self):
        draw_background(screen)

        # Semi-transparent overlay
        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        screen.blit(overlay, (0, 0))

        # Dialog box
        dialog_w = min(W - S(80), S(800))
        dialog_h = min(H - S(100), S(600))
        dialog_x = (W - dialog_w) // 2
        dialog_y = (H - dialog_h) // 2
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_w, dialog_h)
        pygame.draw.rect(screen, CARD, dialog_rect, border_radius=15)
        pygame.draw.rect(screen, ACCENT, dialog_rect, width=3, border_radius=15)

        # Title
        draw_text(screen, self.title, FONT_BIG, FG, (dialog_x + S(30), dialog_y + S(30)))

        # Hints
        hint = f"A={t('hint_select')} | B={t('hint_return')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (dialog_x + S(30), dialog_y + S(70)))

        # Options list area
        list_y = dialog_y + S(110)
        list_h = dialog_h - S(150)

        # Calculate scrolling
        item_h = S(50)
        visible_items = get_visible_items(list_h, item_h)

        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1

        max_scroll = max(0, len(self.options) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))

        # Draw options
        for i in range(self.scroll_offset, min(len(self.options), self.scroll_offset + visible_items)):
            _key, label = self.options[i]
            display_index = i - self.scroll_offset
            opt_y = list_y + display_index * item_h

            opt_rect = pygame.Rect(dialog_x + S(30), opt_y, dialog_w - S(60), item_h - S(5))

            if i == self.idx:
                pygame.draw.rect(screen, SELECT, opt_rect, border_radius=8)
                pygame.draw.rect(screen, ACCENT, opt_rect, width=3, border_radius=8)
            else:
                pygame.draw.rect(screen, (30, 34, 44), opt_rect, border_radius=8)

            draw_text(screen, label, FONT, FG, (opt_rect.x + S(15), opt_rect.y + S(12)))


class WineTypeMenu(BaseScreen):
    """Menu for selecting Wine/Proton variant type"""
    def __init__(self):
        self.options = [
            ('vanilla', 'Wine & Proton (Vanilla)'),
            ('tkg', 'Wine-TKG-Staging'),
            ('wine-ge', 'Wine-GE Custom'),
            ('ge-proton', 'Proton-GE Custom'),
        ]
        self.idx = 0
        self.scroll_offset = 0
    
    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.select()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.select()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return
    
    def select(self):
        wine_type, _label = self.options[self.idx]
        push_screen(WineSelectionScreen(wine_type))
    
    def draw(self):
        draw_background(screen)
        
        draw_text(screen, "Select Wine/Proton Version", FONT_BIG, FG, (40, 30))
        draw_hints_line(screen, f"A={t('hint_select')} | B={t('hint_return')}", FONT_SMALL, ACCENT, (40, 70))
        
        # List of wine types
        base_y = 110
        item_h = 60
        list_h = H - base_y - 40
        visible_items = get_visible_items(list_h, item_h)
        
        # Auto-scroll to keep selection visible
        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1
        
        max_scroll = max(0, len(self.options) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))
        
        # Draw wine type options
        for i in range(self.scroll_offset, min(len(self.options), self.scroll_offset + visible_items)):
            _wine_type, label = self.options[i]
            display_idx = i - self.scroll_offset
            y = base_y + display_idx * item_h
            
            rect = pygame.Rect(40, y, W - 80, item_h - 5)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            
            if i == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            
            draw_text(screen, label, FONT, FG, (rect.x + 14, rect.y + 18))


class WineSelectionScreen(BaseScreen):
    """Screen for selecting Wine/Proton versions from GitHub releases"""
    def __init__(self, wine_type: str):
        """
        wine_type: 'vanilla', 'tkg', 'wine-ge', or 'ge-proton'
        """
        self.wine_type = wine_type
        self.title = {
            'vanilla': 'Wine & Proton (Vanilla)',
            'tkg': 'Wine-TKG-Staging',
            'wine-ge': 'Wine-GE Custom',
            'ge-proton': 'Proton-GE Custom'
        }.get(wine_type, wine_type)
        
        self.versions = []
        self.idx = 0
        self.scroll_offset = 0
        self.loading = True
        self.error = None
        self.selected_version = None
        
        # Start background fetch
        threading.Thread(target=self._fetch_versions, daemon=True).start()
    
    def _fetch_versions(self):
        """Fetch available wine versions from GitHub API"""
        try:
            import json
            
            repos = {
                'vanilla': ('Kron4ek/Wine-Builds', None),
                'tkg': ('Kron4ek/Wine-Builds', 'staging-tkg'),
                'wine-ge': ('GloriousEggroll/wine-ge-custom', None),
                'ge-proton': ('GloriousEggroll/proton-ge-custom', None)
            }
            
            owner_repo, filter_str = repos.get(self.wine_type, ('Kron4ek/Wine-Builds', None))
            
            api_url = f"https://api.github.com/repos/{owner_repo}/releases?per_page=100"
            req = urllib.request.Request(api_url, headers={"User-Agent": "BUA"})
            
            with urllib.request.urlopen(req, timeout=10) as response:
                releases = json.loads(response.read().decode('utf-8'))
            
            # Filter and sort versions
            for release in releases:
                tag = release.get('tag_name', '')
                name = release.get('name', tag)
                
                # Apply filter if needed
                if filter_str and not any(filter_str in asset.get('name', '') for asset in release.get('assets', [])):
                    continue
                
                # Check for valid assets
                if any(asset.get('name', '').endswith(('.tar.xz', '.tar.gz')) for asset in release.get('assets', [])):
                    self.versions.append({'tag': tag, 'name': name})
            
            if not self.versions:
                self.error = "No versions found"
            
        except Exception as e:
            self.error = f"Error fetching versions: {str(e)[:100]}"
        finally:
            self.loading = False
    
    def handle(self, events):
        if self.loading or not self.versions:
            for e in events:
                if e.type == pygame.QUIT:
                    pygame.quit(); sys.exit(0)
                if e.type == pygame.KEYDOWN:
                    if e.key == pygame.K_ESCAPE:
                        pop_screen(); return
                if e.type == pygame.JOYBUTTONDOWN:
                    if e.button in (BTN_B, BTN_BACK):
                        pop_screen(); return
            return
        
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.versions)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.versions)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.select_version()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.versions)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.versions)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.select_version()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return
    
    def select_version(self):
        """Install selected wine version"""
        version = self.versions[self.idx]
        tag = version['tag']

        # Build inline installation script based on wine type
        repos = {
            'vanilla': ('Kron4ek/Wine-Builds', 'amd64.tar.xz', None),
            'tkg': ('Kron4ek/Wine-Builds', 'amd64.tar.xz', 'staging-tkg'),
            'wine-ge': ('GloriousEggroll/wine-ge-custom', 'x86_64.tar.xz', None),
            'ge-proton': ('GloriousEggroll/proton-ge-custom', 'tar.gz', None)
        }

        repo, file_ext, filter_str = repos.get(self.wine_type, ('Kron4ek/Wine-Builds', 'amd64.tar.xz', None))

        # Build filter clause for asset selection
        if filter_str:
            filter_clause = f'| select(.name | contains("{filter_str}"))'
        else:
            filter_clause = ''

        # Create inline installation script
        # Build the jq filter with proper escaping
        jq_filter = f'.[] | select(.tag_name == "{tag}") | .assets[] {filter_clause} | select(.name | endswith("{file_ext}")) | .browser_download_url'

        install_script = f'''set -e
INSTALL_DIR="/userdata/system/wine/custom/"
VERSION="{tag}"
REPO="{repo}"
FILE_EXT="{file_ext}"

echo "Fetching release information for $VERSION..."
release_data=$(curl -s "https://api.github.com/repos/$REPO/releases?per_page=100")

echo "Finding download URL..."
url=$(echo "$release_data" | jq -r '{jq_filter}' | head -n1)

if [[ -z "$url" ]]; then
    echo "No compatible download found for $VERSION"
    exit 1
fi

echo "Creating directory..."
mkdir -p "$INSTALL_DIR/wine-$VERSION"
cd "$INSTALL_DIR/wine-$VERSION"

echo "Downloading $VERSION from $url..."
wget -q --tries=10 --no-check-certificate --no-cache --no-cookies --show-progress -O "wine-$VERSION.$FILE_EXT" "$url"

if [ -f "wine-$VERSION.$FILE_EXT" ]; then
    echo "Unpacking Wine $VERSION..."
    tar --strip-components=1 -xf "wine-$VERSION.$FILE_EXT"
    rm "wine-$VERSION.$FILE_EXT"
    echo "Installation of Wine $VERSION complete!"
else
    echo "Failed to download Wine $VERSION"
    exit 1
fi'''

        push_screen(RunListScreen([(f"{self.title} - {tag}", install_script)], title=self.title))
    
    def draw(self):
        draw_background(screen)
        
        if self.loading:
            draw_text(screen, f"{self.title} - Loading...", FONT_BIG, FG, (40, 30))
            draw_text(screen, "Fetching available versions from GitHub...", FONT, MUTED, (40, 100))
            return
        
        if self.error:
            draw_text(screen, f"{self.title} - Error", FONT_BIG, (255, 120, 120), (40, 30))
            draw_text(screen, self.error, FONT, MUTED, (40, 100))
            draw_hints_line(screen, f"B={t('hint_return')}", FONT_SMALL, ACCENT, (40, 70))
            return
        
        draw_text(screen, self.title, FONT_BIG, FG, (40, 30))
        draw_hints_line(screen, f"A={t('hint_select')} | B={t('hint_return')}", FONT_SMALL, ACCENT, (40, 70))
        
        # List of versions
        base_y = 110
        item_h = 50
        list_h = H - base_y - 40
        visible_items = get_visible_items(list_h, item_h)
        
        # Auto-scroll to keep selection visible
        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1
        
        max_scroll = max(0, len(self.versions) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))
        
        # Draw version items
        for i in range(self.scroll_offset, min(len(self.versions), self.scroll_offset + visible_items)):
            version = self.versions[i]
            display_idx = i - self.scroll_offset
            y = base_y + display_idx * item_h
            
            rect = pygame.Rect(40, y, W - 80, item_h - 5)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            
            if i == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            
            draw_text(screen, f"{version['name']}", FONT, FG, (rect.x + 14, rect.y + 8))
            draw_text(screen, f"Tag: {version['tag']}", FONT_SMALL, MUTED, (rect.x + 14, rect.y + 28))
        
        # Draw scroll indicators
        if len(self.versions) > visible_items:
            if self.scroll_offset > 0:
                draw_text(screen, "▲ More above", FONT_SMALL, MUTED, (40, base_y - 25))
            if self.scroll_offset + visible_items < len(self.versions):
                draw_text(screen, "▼ More below", FONT_SMALL, MUTED, (40, H - 30))


class ChecklistScreen(BaseScreen):
    def __init__(self, category: str, app_keys: List[str]):
        global SELECTED_APPS
        self.category = category
        self.all_items = app_keys
        self.items = app_keys  # Filtered list
        self.idx = 0
        # Use global SELECTED_APPS, initialize new keys if needed
        for k in self.all_items:
            if k not in SELECTED_APPS:
                SELECTED_APPS[k] = False
        self.queue_message = ""
        self.queue_message_time = 0
        self.search_mode = False
        self.search_query = ""
        self.last_action_time = 0
        self.action_cooldown = 0.2  # 200ms cooldown to prevent double inputs
        self.keyboard = OnScreenKeyboard()

    def handle(self, events):
        current_time = pygame.time.get_ticks() / 1000.0
        # Category screens do not support on-screen keyboard search

        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.items)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.items)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen()
                    return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.items)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.items)
                # Match hints: Enter toggles selection (A)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if current_time - self.last_action_time > self.action_cooldown:
                        key = self.items[self.idx]
                        # Special handling for Custom Wine - show wine type menu instead
                        if key == "Custom Wine":
                            push_screen(WineTypeMenu())
                        else:
                            SELECTED_APPS[key] = not SELECTED_APPS[key]
                        self.last_action_time = current_time
                # A to select all / deselect all (keyboard)
                if e.key == pygame.K_a:
                    if all(SELECTED_APPS.get(k, False) for k in self.items):
                        for key in self.items:
                            SELECTED_APPS[key] = False
                    else:
                        for key in self.items:
                            SELECTED_APPS[key] = True
                # Space opens the queue/add action (Start)
                if e.key == pygame.K_SPACE:
                    if current_time - self.last_action_time > self.action_cooldown:
                        self.install_selected()
                        self.last_action_time = current_time
                # (Removed keyboard Y shortcut; A handles select all per hints)
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.items)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.items)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A,):  # A
                    if current_time - self.last_action_time > self.action_cooldown:
                        key = self.items[self.idx]
                        # Special handling for Custom Wine - show wine type menu instead
                        if key == "Custom Wine":
                            push_screen(WineTypeMenu())
                        else:
                            SELECTED_APPS[key] = not SELECTED_APPS[key]
                        self.last_action_time = current_time
                if e.button in (BTN_START,):  # Start
                    if current_time - self.last_action_time > self.action_cooldown:
                        self.install_selected()
                        self.last_action_time = current_time
                if e.button in (BTN_B, BTN_BACK):  # B/Back
                    pop_screen(); return
                if e.button == BTN_Y:  # Y button -> toggle select all
                    if all(SELECTED_APPS.get(k, False) for k in self.items):
                        for key in self.items:
                            SELECTED_APPS[key] = False
                    else:
                        for key in self.items:
                            SELECTED_APPS[key] = True

    def filter_items(self):
        """
        Filter the visible app list (by key or description) within this category.
        Previously this mistakenly filtered TOP_LEVEL tuples, breaking search.
        """
        q = self.search_query.lower().strip()
        if not q:
            self.items = list(self.all_items)
        else:
            def matches(k: str) -> bool:
                if q in k.lower():
                    return True
                return q in DESCRIPTIONS.get(k, "").lower()
            self.items = [k for k in self.all_items if matches(k)]
        self.idx = 0

    def install_selected(self):
        selected_items = [(k, APPS[k]) for k, v in SELECTED_APPS.items() if v]

        if selected_items:
            # Check if any are already installed
            already_installed = [(k, cmd) for k, cmd in selected_items if is_installed(k)]
            not_installed = [(k, cmd) for k, cmd in selected_items if not is_installed(k)]
            
            if already_installed and not not_installed:
                # All selected are already installed - show confirmation
                names = [k for k, _ in already_installed]
                last_date = get_last_install_date(names[0])
                
                if len(already_installed) == 1:
                    msg = [
                        f"{names[0]} {t('previously_installed')}",
                        f"{t('last_installed')} {last_date}",
                        "",
                        t("install_again")
                    ]
                else:
                    msg = [
                        f"{len(already_installed)} {t('selected_installed')}",
                        f"{t('last_prefix')} {last_date})",
                        "",
                        t("install_them_again")
                    ]
                
                def on_confirm():
                    for item in already_installed:
                        if item not in INSTALL_QUEUE:
                            INSTALL_QUEUE.append(item)
                    for k in SELECTED_APPS:
                        SELECTED_APPS[k] = False
                    self.queue_message = f"{t('added')} {len(already_installed)} {t('to_queue')}"
                    self.queue_message_time = pygame.time.get_ticks() / 1000.0
                
                def on_cancel():
                    pass

                push_screen(ConfirmDialog(t("reinstall_confirmation"), msg, on_confirm, on_cancel))
                
            else:
                # Add all to queue (with confirmation if some are installed)
                if already_installed:
                    names = ", ".join([k for k, _ in already_installed[:3]])
                    if len(already_installed) > 3:
                        names += f" {t('and')} {len(already_installed) - 3} {t('more')}"

                    msg = [
                        f"{t('some_installed')} {names}",
                        "",
                        f"{t('items_to_queue')}"
                    ]
                    
                    def on_confirm():
                        for item in selected_items:
                            if item not in INSTALL_QUEUE:
                                INSTALL_QUEUE.append(item)
                        for k in SELECTED_APPS:
                            SELECTED_APPS[k] = False
                        self.queue_message = f"{t('added')} {len(selected_items)} {t('to_queue')}"
                        self.queue_message_time = pygame.time.get_ticks() / 1000.0

                    def on_cancel():
                        pass

                    push_screen(ConfirmDialog(t("add_to_queue"), msg, on_confirm, on_cancel))
                else:
                    # None installed, add directly
                    for item in selected_items:
                        if item not in INSTALL_QUEUE:
                            INSTALL_QUEUE.append(item)
                    for k in SELECTED_APPS:
                        SELECTED_APPS[k] = False
                    self.queue_message = f"{t('added')} {len(selected_items)} {t('to_queue')}"
                    self.queue_message_time = pygame.time.get_ticks() / 1000.0
        else:
            # No items selected - show queue
            push_screen(QueueScreen())

    def draw(self):
        draw_background(screen)
        draw_text(screen, f"{self.category}", FONT_BIG, FG, (40, 30))

        # Show queue count and installation stats
        installed_count = sum(1 for k in self.all_items if is_installed(k))

        # Normal view (search disabled at category level)
        any_selected = any(SELECTED_APPS.get(k, False) for k in self.items) if self.items else False
        all_selected = all(SELECTED_APPS.get(k, False) for k in self.items) if self.items else False
        y_label = t("hint_remove_all") if all_selected else t("hint_add_all")
        start_label = t("hint_start") if any_selected else t("queue")
        queue_text = (
            f"{t('queue')}: {len(INSTALL_QUEUE)} | {t('installed')}: {installed_count}/{len(self.all_items)} "
            f"| A={t('hint_toggle')} | Y={y_label} | Start={start_label} | B={t('hint_return')} | Back={t('hint_back_settings')}"
        )
        draw_hints_line(screen, queue_text, FONT_SMALL, ACCENT, (S(40), S(70)))
        base_y = S(110)
        
        # Show temporary message if items were just added to queue
        current_time = pygame.time.get_ticks() / 1000.0
        if self.queue_message and (current_time - self.queue_message_time) < 2.0:
            msg_color = ACCENT
            draw_text(screen, self.queue_message, FONT, msg_color, (40, base_y))
            base_y += 40
        
        # Items list
        if not self.items:
            draw_text(screen, t("no_addons_category"), FONT, MUTED, (40, base_y))
            return

        # scroll logic
        item_pitch = S(55)
        avail_h = H - base_y - S(40)
        rows = min(len(self.items), get_visible_items(avail_h, item_pitch))
        top = max(0, min(self.idx - rows//2, len(self.items)-rows))
        view = self.items[top:top+rows]
        
        for i, key in enumerate(view):
            actual_idx = top + i
            rect = pygame.Rect(S(40), base_y + i*S(55), W - S(80), S(50))
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if actual_idx == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)

            # checkbox
            box = pygame.Rect(rect.x + S(14), rect.y + S(12), S(24), S(24))
            pygame.draw.rect(screen, FG if SELECTED_APPS[key] else MUTED, box, width=2)
            if SELECTED_APPS[key]:
                pygame.draw.line(screen, FG, (box.x + S(4), box.centery), (box.centerx, box.bottom - S(5)), 3)
                pygame.draw.line(screen, FG, (box.centerx, box.bottom - S(5)), (box.right - S(4), box.y + S(5)), 3)
            
            # "Already installed" indicator
            installed = is_installed(key)
            if installed:
                # Small green dot indicator
                dot_x = box.right + S(8)
                dot_y = box.y + S(4)
                pygame.draw.circle(screen, ACCENT, (dot_x, dot_y), S(5))
            
            # labels
            name_x = box.right + (S(20) if installed else S(12))
            draw_text(screen, key, FONT, FG, (name_x, rect.y + S(8)))
            desc = DESCRIPTIONS.get(key, "")
            if desc:
                draw_text(screen, desc, FONT_SMALL, MUTED, (name_x, rect.y + S(30)))
        
        # no search keyboard on category screens


class GlobalSearchScreen(BaseScreen):
    def __init__(self, query: str, app_keys: List[str]):
        global SELECTED_APPS
        self.query = query
        self.all_items = app_keys  # flat list of matching keys
        self.items = app_keys
        self.idx = 0
        # Use global SELECTED_APPS, initialize new keys if needed
        for k in self.all_items:
            if k not in SELECTED_APPS:
                SELECTED_APPS[k] = False
        self.queue_message = ""
        self.queue_message_time = 0
        self.last_action_time = 0
        self.action_cooldown = 0.2
        # Build grouped flat list with non-selectable headers
        self.key_to_cat = {}
        for cat, keys in CATEGORIES.items():
            for k in keys:
                if k in self.all_items and k not in self.key_to_cat:
                    self.key_to_cat[k] = cat
        # Any keys not in CATEGORIES fall into 'Other'
        for k in self.all_items:
            if k not in self.key_to_cat:
                self.key_to_cat[k] = 'Other'
        self.collapsed = set()  # categories currently collapsed
        self.flat = self._build_flat_grouped(self.all_items)

    def _build_flat_grouped(self, app_keys: List[str]):
        grouped: Dict[str, List[str]] = {}
        for k in app_keys:
            grouped.setdefault(self.key_to_cat.get(k, 'Other'), []).append(k)
        # Sort categories by name and items alphabetically
        flat = []
        for cat in sorted(grouped.keys()):
            keys = sorted(grouped[cat])
            flat.append(("header", cat, len(keys)))
            if cat not in self.collapsed:
                for k in keys:
                    flat.append(("app", k))
        return flat

    def handle(self, events):
        current_time = pygame.time.get_ticks() / 1000.0

        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.flat)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.flat)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.flat)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.flat)
                if e.key == pygame.K_x:
                    self.toggle_header()
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if current_time - self.last_action_time > self.action_cooldown and self.flat:
                        item = self.flat[self.idx]
                        if item[0] == "app":
                            key = item[1]
                            SELECTED_APPS[key] = not SELECTED_APPS[key]
                            self.last_action_time = current_time
                # A toggles select all in current view (keyboard)
                if e.key == pygame.K_a:
                    # Build list of visible app keys
                    visible_apps = [it[1] for it in self.flat if it[0] == "app"]
                    if all(SELECTED_APPS.get(k, False) for k in visible_apps):
                        for k in visible_apps:
                            SELECTED_APPS[k] = False
                    else:
                        for k in visible_apps:
                            SELECTED_APPS[k] = True
                if e.key == pygame.K_SPACE:
                    if current_time - self.last_action_time > self.action_cooldown:
                        self.install_selected()
                        self.last_action_time = current_time
                # No 'select all' via keyboard; Y is reserved on gamepad only
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.flat)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.flat)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A,):  # A
                    if current_time - self.last_action_time > self.action_cooldown and self.flat:
                        item = self.flat[self.idx]
                        if item[0] == "app":
                            key = item[1]
                            SELECTED_APPS[key] = not SELECTED_APPS[key]
                            self.last_action_time = current_time
                if e.button == BTN_X:  # X -> collapse/expand category
                    self.toggle_header()
                if e.button in (BTN_START,):  # Start -> install
                    if current_time - self.last_action_time > self.action_cooldown:
                        self.install_selected()
                        self.last_action_time = current_time
                if e.button in (BTN_B, BTN_BACK):  # B/Back
                    pop_screen(); return

    def toggle_header(self):
        if not self.flat:
            return
        item = self.flat[self.idx]
        if item[0] == "header":
            cat = item[1]
            if cat in self.collapsed:
                self.collapsed.remove(cat)
            else:
                self.collapsed.add(cat)
            self.flat = self._build_flat_grouped(self.all_items)
            # Keep selection on the same header if possible
            for i, it in enumerate(self.flat):
                if it[0] == "header" and it[1] == cat:
                    self.idx = i
                    break

    def install_selected(self):
        selected_items = [(k, APPS[k]) for k, v in SELECTED_APPS.items() if v]
        if not selected_items:
            push_screen(QueueScreen()); return
        for item in selected_items:
            if item not in INSTALL_QUEUE:
                INSTALL_QUEUE.append(item)
        for k in SELECTED_APPS:
            SELECTED_APPS[k] = False
        self.queue_message = f"Added {len(selected_items)} item(s) to queue"
        self.queue_message_time = pygame.time.get_ticks() / 1000.0

    def draw(self):
        draw_background(screen)
        title = f"{t('search_results')}: '{self.query}'"
        draw_text(screen, title, FONT_BIG, FG, (40, 30))

        any_selected = any(SELECTED_APPS.values())
        start_label = t("hint_start") if any_selected else t("queue")
        count_text = (
            f"{t('found')} {len(self.all_items)} add-ons | {t('queue')}: {len(INSTALL_QUEUE)} | "
            f"A={t('hint_toggle')}, Start={start_label}, X={t('hint_collapse_expand')}, B={t('hint_return')} | Back={t('hint_back_settings')}"
        )
        draw_hints_line(screen, count_text, FONT_SMALL, ACCENT, (40, 70))

        base_y = S(110)
        current_time = pygame.time.get_ticks() / 1000.0
        if self.queue_message and (current_time - self.queue_message_time) < 2.0:
            draw_text(screen, self.queue_message, FONT, ACCENT, (40, base_y))
            base_y += 40

        if not self.all_items:
            draw_text(screen, t("no_search_match"), FONT, MUTED, (40, base_y + 20))
            # Icon hint for returning (avoid repetition)
            draw_hints_line(screen, f"B={t('hint_return')}", FONT_SMALL, ACCENT, (40, base_y + 55))
            return

        item_pitch = S(58)
        avail_h = H - base_y - S(40)
        rows = min(len(self.flat), get_visible_items(avail_h, item_pitch))
        top = max(0, min(self.idx - rows//2, len(self.flat)-rows))
        view = self.flat[top:top+rows]

        for i, item in enumerate(view):
            actual_idx = top + i
            if item[0] == "header":
                cat = item[1]
                count = item[2]
                rect = pygame.Rect(S(40), base_y + i*S(58), W - S(80), S(40))
                pygame.draw.rect(screen, CARD, rect, border_radius=8)
                if actual_idx == self.idx:
                    pygame.draw.rect(screen, SELECT, rect, width=2, border_radius=8)
                # ASCII indicators for collapsed/expanded
                prefix = ">" if cat in self.collapsed else "v"
                draw_text(screen, f"{prefix} {cat} [{count}]", FONT, FG, (rect.x + S(12), rect.y + S(8)))
                continue

            # app row
            key = item[1]
            rect = pygame.Rect(S(40), base_y + i*S(58), W - S(80), S(50))
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if actual_idx == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)

            # checkbox
            box = pygame.Rect(rect.x + S(14), rect.y + S(12), S(24), S(24))
            pygame.draw.rect(screen, FG if SELECTED_APPS[key] else MUTED, box, width=2)
            if SELECTED_APPS[key]:
                pygame.draw.line(screen, FG, (box.x + S(4), box.centery), (box.centerx, box.bottom - S(5)), 3)
                pygame.draw.line(screen, FG, (box.centerx, box.bottom - S(5)), (box.right - S(4), box.y + S(5)), 3)

            # Installed indicator
            installed = is_installed(key)
            if installed:
                dot_x = box.right + S(8)
                dot_y = box.y + S(4)
                pygame.draw.circle(screen, ACCENT, (dot_x, dot_y), S(5))

            name_x = box.right + (S(20) if installed else S(12))
            draw_text(screen, key, FONT, FG, (name_x, rect.y + S(8)))
            desc = DESCRIPTIONS.get(key, "")
            if desc:
                draw_text(screen, desc, FONT_SMALL, MUTED, (name_x, rect.y + S(30)))


class NoResultsScreen(BaseScreen):
    def __init__(self, query: str):
        self.query = query

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_ESCAPE):
                    pop_screen(); return
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_B, BTN_BACK, BTN_START):
                    pop_screen(); return

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("search_results"), FONT_BIG, FG, (40, 30))
        draw_text(screen, f"{t('no_addons_found')} '{self.query}'.", FONT, MUTED, (40, 90))
        # Use concise icon-based hint
        draw_hints_line(screen, f"B={t('hint_return')} | Back={t('hint_back_settings')}", FONT_SMALL, ACCENT, (40, 130))

class QueueScreen(BaseScreen):
    def __init__(self):
        self.idx = 0

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1 and INSTALL_QUEUE:  # Down
            self.idx = (self.idx + 1) % (len(INSTALL_QUEUE) + 1)
        elif analog_v == -1 and INSTALL_QUEUE:  # Up
            self.idx = (self.idx - 1) % (len(INSTALL_QUEUE) + 1)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    if INSTALL_QUEUE:
                        self.idx = (self.idx + 1) % (len(INSTALL_QUEUE) + 1)
                if e.key in (pygame.K_UP,):
                    if INSTALL_QUEUE:
                        self.idx = (self.idx - 1) % (len(INSTALL_QUEUE) + 1)
                # Reorder with PageUp/PageDown (keyboard)
                if e.key == pygame.K_PAGEUP:
                    self.move_item(-1)
                if e.key == pygame.K_PAGEDOWN:
                    self.move_item(1)
                # Clear via Y key
                if e.key == pygame.K_y:
                    # Clear entire queue
                    INSTALL_QUEUE.clear()
                    self.idx = 0
                # Enter key behavior: if on START row, start install; otherwise remove item
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.idx == len(INSTALL_QUEUE) and INSTALL_QUEUE:
                        # On START row - begin install
                        self.start_install()
                    elif 0 <= self.idx < len(INSTALL_QUEUE):
                        # On queue item - remove it
                        INSTALL_QUEUE.pop(self.idx)
                        if self.idx >= len(INSTALL_QUEUE) and self.idx > 0:
                            self.idx -= 1
                # Space key always starts install if queue has items
                if e.key == pygame.K_SPACE:
                    if INSTALL_QUEUE:
                        self.start_install()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1 and INSTALL_QUEUE:
                    self.idx = (self.idx + 1) % (len(INSTALL_QUEUE) + 1)
                elif y == 1 and INSTALL_QUEUE:
                    self.idx = (self.idx - 1) % (len(INSTALL_QUEUE) + 1)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A,):  # A - remove item or start install
                    if self.idx == len(INSTALL_QUEUE) and INSTALL_QUEUE:
                        self.start_install()
                    elif 0 <= self.idx < len(INSTALL_QUEUE):
                        INSTALL_QUEUE.pop(self.idx)
                        if self.idx >= len(INSTALL_QUEUE) and self.idx > 0:
                            self.idx -= 1
                # LB/RB for moving items within the queue
                if e.button == BTN_LB:  # LB
                    self.move_item(-1)
                if e.button == BTN_RB:  # RB
                    self.move_item(1)
                if e.button == BTN_Y:  # Y -> clear entire queue
                    INSTALL_QUEUE.clear()
                    self.idx = 0
                if e.button in (BTN_START,):  # Start - begin install
                    if INSTALL_QUEUE:
                        self.start_install()
                if e.button in (BTN_B, BTN_BACK):  # B/Back
                    pop_screen(); return

    def start_install(self):
        if INSTALL_QUEUE:
            jobs = list(INSTALL_QUEUE)
            INSTALL_QUEUE.clear()
            push_screen(RunListScreen(jobs, title=t("installing_from_queue")))

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("installation_queue"), FONT_BIG, FG, (40, 30))

        if not INSTALL_QUEUE:
            draw_text(screen, t("queue_empty"), FONT, MUTED, (40, 100))
            # Icon hint for returning
            draw_hints_line(screen, f"B={t('hint_return')} | Back={t('hint_back_settings')}", FONT_SMALL, ACCENT, (40, 140))
            draw_text(screen, t("queue_add_items"), FONT_SMALL, ACCENT, (40, 170))
        else:
            on_start_row = (self.idx == len(INSTALL_QUEUE)) and bool(INSTALL_QUEUE)
            a_label = t("hint_start") if on_start_row else t("hint_remove")
            hint = (
                f"{t('queue_items').replace('X', str(len(INSTALL_QUEUE)))} | A={a_label} | "
                f"LB={t('hint_move_up')} | RB={t('hint_move_down')} | Y={t('hint_clear')} | Start={t('hint_begin')} | B={t('hint_return')} | Back={t('hint_back_settings')}"
            )
            draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))

            base_y = 110
            # Scrollable queue list including the Start row as the last item
            item_pitch = 55
            avail_h = H - base_y - 40
            total_rows = len(INSTALL_QUEUE) + 1  # include Start row
            rows = min(total_rows, get_visible_items(avail_h, item_pitch))
            if total_rows <= rows:
                top = 0
            else:
                top = max(0, min(self.idx - rows // 2, total_rows - rows))

            visible_rows = min(rows, total_rows - top)
            for i in range(visible_rows):
                r_index = top + i
                y = base_y + i * 55
                if r_index < len(INSTALL_QUEUE):
                    # Queue item
                    name, _cmd = INSTALL_QUEUE[r_index]
                    rect = pygame.Rect(40, y, W - 80, 48)
                    pygame.draw.rect(screen, CARD, rect, border_radius=10)
                    if r_index == self.idx:
                        pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
                    draw_text(screen, f"{r_index + 1}. {name}", FONT, FG, (rect.x + 16, rect.y + 12))
                else:
                    # Start row
                    start_rect = pygame.Rect(40, y, W - 80, 55)
                    pygame.draw.rect(screen, ACCENT if self.idx == len(INSTALL_QUEUE) else CARD, start_rect, border_radius=10)
                    if self.idx == len(INSTALL_QUEUE):
                        pygame.draw.rect(screen, SELECT, start_rect, width=3, border_radius=10)
                    draw_text(screen, f">>> {t('start_install')} ({len(INSTALL_QUEUE)} {t('items_lowercase')}) <<<", FONT, FG, (start_rect.x + 16, start_rect.y + 15))
    def move_item(self, delta: int):
        # Move the currently selected queue item up/down
        if 0 <= self.idx < len(INSTALL_QUEUE):
            new_idx = max(0, min(self.idx + delta, len(INSTALL_QUEUE) - 1))
            if new_idx != self.idx:
                item = INSTALL_QUEUE.pop(self.idx)
                INSTALL_QUEUE.insert(new_idx, item)
                self.idx = new_idx


class RunListScreen(BaseScreen):
    def __init__(self, jobs: List[Tuple[str, str]], title: str = None):
        self.jobs = jobs
        self.title = title if title is not None else t("running_installers")
        self.runner = Runner()
        self.current = 0
        self.started = False
        self.all_finished = False
        self.spinner_frame = 0
        self.spinner_chars = ["|", "/", "-", "\\"]
        self.job_results = []  # Track success/failure of each job
        self.show_log = False  # Toggle to show error log
        self.pulse_offset = 0  # For animated progress bar pulse

    def start_next(self):
        if self.current >= len(self.jobs):
            self.all_finished = True
            return
        name, cmd = self.jobs[self.current]
        # Create a fresh runner for each job
        self.runner = Runner()

        # Wrap all 'dialog' calls globally to capture end-of-install messages
        dialog_wrap = ""
        if not os.environ.get("BUA_DISABLE_DIALOG_WRAP"):
            dialog_wrap = (
                # Save original stderr to fd9 before any script redirections can change fd2.
                # This ensures __BUA_DIALOG__ markers always reach BUA's pipe even when
                # scripts use fd-swapping patterns like '3>&1 1>&2 2>&3' or '2>&1 >/dev/tty'
                # (as used by foclabroc's newswitch.sh for language/mode selection).
                "exec 9>&2; "
                "function dialog(){ "
                "echo '[BUA] Dialog called with:' \"$@\" >&9; "
                "local dtype=\"\" title=\"\" text=\"\" menu_items=\"\"; "
                "local next_title=0 next_text=0 skip_count=0 skip_backtitle=0; "
                "for arg in \"$@\"; do "
                "  case \"$arg\" in "
                "    --title) next_title=1 ;; "
                "    --backtitle) skip_backtitle=1 ;; "
                "    --msgbox) dtype=\"msgbox\"; next_text=1 ;; "
                "    --infobox) dtype=\"infobox\"; next_text=1 ;; "
                "    --yesno) dtype=\"yesno\"; next_text=1 ;; "
                "    --menu) dtype=\"menu\"; next_text=1 ;; "
                "    --checklist) dtype=\"checklist\"; next_text=1 ;; "
                "    --stdout|--clear) ;; "
                "    *) "
                "      if [ $skip_backtitle -eq 1 ]; then skip_backtitle=0; "
                "      elif [ $next_title -eq 1 ]; then title=\"$arg\"; next_title=0; "
                "      elif [ $next_text -eq 1 ]; then text=\"$arg\"; next_text=0; skip_count=3; "
                "      elif [ $skip_count -gt 0 ]; then skip_count=$((skip_count - 1)); "
                "      elif [ \"$dtype\" = \"menu\" ] || [ \"$dtype\" = \"checklist\" ]; then "
                "        if [ -z \"$menu_items\" ]; then menu_items=\"$arg\"; else menu_items=\"$menu_items|$arg\"; fi; "
                "      fi ;; "
                "  esac; "
                "done; "
                "if [ -n \"$dtype\" ]; then "
                "  echo '[BUA] Detected dtype:' \"$dtype\" 'title:' \"$title\" >&9; "
                "  echo '[BUA] Menu items:' \"$menu_items\" >&9; "
                "  local resp_file=\"/tmp/bua_dialog_$$.resp\"; rm -f \"$resp_file\"; "
                "  if command -v base64 >/dev/null 2>&1; then "
                "    t_b64=$(printf %s \"$title\" | base64 -w0 2>/dev/null || printf %s \"$title\" | base64); "
                "    m_b64=$(printf %s \"$text\" | base64 -w0 2>/dev/null || printf %s \"$text\" | base64); "
                "    i_b64=$(printf %s \"$menu_items\" | base64 -w0 2>/dev/null || printf %s \"$menu_items\" | base64); "
                "    echo '[BUA] Emitting marker with resp file:' \"$resp_file\" >&9; "
                "    echo __BUA_DIALOG__ type=$dtype title_b64=$t_b64 text_b64=$m_b64 items_b64=$i_b64 resp=$resp_file >&9; "
                "  else "
                "    echo __BUA_DIALOG__ type=$dtype title=\"$title\" text=\"$text\" items=\"$menu_items\" resp=$resp_file >&9; "
                "  fi; "
                "  if [ \"$dtype\" = \"infobox\" ]; then "
                "    echo '[BUA] Infobox - continuing immediately' >&9; "
                "    echo 0 > \"$resp_file\"; sleep 0.05; rm -f \"$resp_file\"; return 0; "
                "  fi; "
                "  while [ ! -f \"$resp_file\" ]; do sleep 0.1; done; "
                "  local result=$(cat \"$resp_file\"); rm -f \"$resp_file\"; "
                "  if [ \"$dtype\" = \"yesno\" ]; then "
                "    if [ \"$result\" = \"0\" ]; then return 0; else return 1; fi; "
                "  elif [ \"$dtype\" = \"menu\" ] || [ \"$dtype\" = \"checklist\" ]; then "
                # Echo result to both fd1 and fd2: fd1 handles normal $() capture,
                # fd2 handles the swapped 3>&1 1>&2 2>&3 pattern used by foclabroc.
                "    if [ -n \"$result\" ]; then echo \"$result\"; echo \"$result\" >&2; return 0; else return 1; fi; "
                "  else "
                "    return 0; "
                "  fi; "
                "fi; "
                "return 0; }; export -f dialog; "
            )

        # Wrap curl to intercept ES refresh calls (curl http://127.0.0.1:1234/reloadgames)
        es_wrap = (
            "function curl(){ "
            "if echo \"$@\" | grep -q '127.0.0.1:1234/reloadgames'; then "
            "echo '[BUA] Deferring ES refresh until batch complete'; return 0; "
            "else command curl \"$@\"; fi; }; "
            "export -f curl; "
        )

        # Wrap batocera-save-overlay to suppress reboot prompts
        overlay_wrap = (
            "function batocera-save-overlay(){ "
            "echo '[BUA] Saving overlay...'; "
            "command batocera-save-overlay \"$@\" 2>&1 | grep -v 'reboot'; "
            "return 0; }; "
            "export -f batocera-save-overlay; "
        )

        # Wrap whiptail, zenity, and other dialog tools to auto-answer prompts
        # This prevents installers from opening interactive windows that require manual exit
        interactive_wrap = (
            "function whiptail(){ "
            "echo '[BUA] Auto-answering whiptail dialog'; "
            "return 0; }; "
            "export -f whiptail; "
            "function zenity(){ "
            "echo '[BUA] Auto-answering zenity dialog'; "
            "return 0; }; "
            "export -f zenity; "
            "function kdialog(){ "
            "echo '[BUA] Auto-answering kdialog'; "
            "return 0; }; "
            "export -f kdialog; "
            "function xdialog(){ "
            "echo '[BUA] Auto-answering xdialog'; "
            "return 0; }; "
            "export -f xdialog; "
        )

        # Wrap dangerous system commands that installers shouldn't call.
        # This shell snippet is injected before running installer scripts.
        system_wrap = r"""\
# Create a temporary shim dir and small killall/pkill wrappers
REAL_KILLALL=$(command -v killall || echo /usr/bin/killall)
REAL_PKILL=$(command -v pkill || echo /usr/bin/pkill)
BUA_TMPBIN=$(mktemp -d /tmp/bua_bin.XXXX)

printf '%s\n' '#!/bin/sh' "REAL=$REAL_KILLALL" \
  'echo "$(date --iso-8601=seconds) [BUA-SHIM] killall $$ $PPID: \"$@\" PATH=\"$PATH\"" >> /tmp/bua_killall.log' \
  'for arg in "$@"; do' \
  '  if [ "$arg" = "emulationstation" ] || [ "$arg" = "pcmanfm" ]; then' \
  '   echo "[BUA] Blocked killall for critical process: \"$arg\""' \
  '    if [ "$arg" = "emulationstation" ]; then touch /tmp/bua_killall_es_deferred; fi' \
  '    exit 0' \
  '  fi' \
  'done' \
  'exec "$REAL" "$@"' > "$BUA_TMPBIN/killall"

printf '%s\n' '#!/bin/sh' "REAL=$REAL_PKILL" \
  'echo "$(date --iso-8601=seconds) [BUA-SHIM] pkill $$ $PPID: \"$@\" PATH=\"$PATH\"" >> /tmp/bua_killall.log' \
  'for arg in "$@"; do' \
  '  if [ "$arg" = "emulationstation" ] || [ "$arg" = "pcmanfm" ]; then' \
  '    echo "[BUA] Blocked pkill for critical process: \"$arg\""' \
  '    if [ "$arg" = "emulationstation" ]; then touch /tmp/bua_killall_es_deferred; fi' \
  '    exit 0' \
  '  fi' \
  'done' \
  'exec "$REAL" "$@"' > "$BUA_TMPBIN/pkill"

chmod +x "$BUA_TMPBIN/killall" "$BUA_TMPBIN/pkill"

# Ensure we remove the temporary shim dir when the injected subshell exits
trap 'rm -rf "$BUA_TMPBIN"' EXIT

# Prepend our shim to PATH so child processes resolve it first
export PATH="$BUA_TMPBIN:$PATH"

# Also provide a harmless desktop function for sourced scripts
desktop() { echo "[BUA] Blocked desktop mode switch during installation"; return 0; }
export -f desktop
"""

        # Provide every BUA installer with the common registration helper.
        registration_wrap = get_bua_registration_shell_helper()

        # Add debug markers to track execution
        debug_start = f"echo '[BUA] Starting installation: {name}'; "
        debug_end = "; echo '[BUA] Installation finished'"

        # Prefer the converted registration-aware installer when one is
        # explicitly mapped. Unmapped packages retain the original BUA command.
        dev_adapter = get_dev_registration_adapter(name)

        if dev_adapter and "BUA_PARENT_UPDATE=1;" not in cmd:
            cmd = "source " + repr(dev_adapter)

        # Special handling for curl | bash commands - inject wrappers into the piped script
        if "curl" in cmd and "|" in cmd and "bash" in cmd:
            # Download script to temp file, prepend wrappers, then execute
            # This ensures the dialog wrapper is available to the downloaded script
            parts = cmd.split("|", 1)
            if len(parts) == 2:
                curl_part = parts[0].strip()
                wrapper_code = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}{registration_wrap}"
                cmd = (
                    f"{debug_start}"
                    f"TMPSCRIPT=$(mktemp); "
                    f"{curl_part} > \"$TMPSCRIPT\"; "
                    f"( {wrapper_code} source \"$TMPSCRIPT\" ); "
                    f"rm -f \"$TMPSCRIPT\""
                    f"{debug_end}"
                )
            else:
                cmd = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}{registration_wrap}{debug_start}{cmd}{debug_end}"
        else:
            cmd = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}{registration_wrap}{debug_start}{cmd}{debug_end}"

        self.runner.run(cmd)
        self.started = True

    def handle(self, events):
        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    self.runner.kill(); pop_screen(); return
                if e.key == pygame.K_x:  # X to toggle log view
                    self.show_log = not self.show_log
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_B, BTN_BACK):  # B/Back
                    self.runner.kill(); pop_screen(); return
                if e.button in (BTN_A, BTN_START):  # A/Start to continue
                    if self.all_finished:
                        pop_screen(); return
                if e.button in (BTN_X,):  # X button to toggle log
                    self.show_log = not self.show_log

    def update(self):
        if self.all_finished:
            return

        # Check if a menu selection is requested
        if not self.runner.done and self.runner.menu_request and not self.runner.menu_response:
            menu_data = self.runner.menu_request

            def on_select(key):
                self.runner.menu_response = key
                # Send the response to the script via stdin
                if self.runner.proc and self.runner.proc.stdin:
                    try:
                        self.runner.proc.stdin.write(f"{key}\n")
                        self.runner.proc.stdin.flush()
                    except Exception as e:
                        print(f"Error sending menu response: {e}")

            push_screen(MenuSelectionDialog(
                title=menu_data["title"],
                options=menu_data["options"],
                callback=on_select
            ))
            # Clear the request so we don't show it again
            self.runner.menu_request = None

        # Check if URLs have been detected during installation (e.g., auth links)
        if not self.runner.done and not self.runner.url_shown and self.runner.detected_urls:
            # Show URLs in a dialog while installation is still running
            job_name = self.jobs[self.current][0]
            push_screen(InfoDialog(title=job_name, message=self.runner.detected_urls[-10:]))
            self.runner.url_shown = True

        # Check if msgbox/infobox is requested (use InfoDialog for these)
        if not self.runner.done and self.runner.last_dialog_type in ("msgbox", "infobox") and self.runner.last_dialog_resp_file:
            title = self.runner.last_dialog_title or ""
            text = self.runner.last_dialog_text or ""
            resp_file = self.runner.last_dialog_resp_file

            def on_close_msgbox():
                # Write "0" to response file when user closes msgbox
                try:
                    with open(resp_file, "w") as f:
                        f.write("0")
                except Exception as e:
                    print(f"Error writing msgbox response: {e}")

            push_screen(InfoDialog(title=title, message=text.split("\n"), on_close=on_close_msgbox))

            # Clear the dialog so we don't show it again
            self.runner.last_dialog_type = None
            self.runner.last_dialog_title = None
            self.runner.last_dialog_text = None
            self.runner.last_dialog_resp_file = None

        # Check if an interactive dialog (yesno/menu/checklist) is requested
        elif not self.runner.done and self.runner.last_dialog_type in ("yesno", "menu", "checklist") and self.runner.last_dialog_resp_file:
            dtype = self.runner.last_dialog_type
            title = self.runner.last_dialog_title or ""
            text = self.runner.last_dialog_text or ""
            items = self.runner.last_dialog_items
            resp_file = self.runner.last_dialog_resp_file

            # Show interactive dialog
            push_screen(InteractiveDialog(dtype, title, text, items, resp_file))

            # Clear the dialog so we don't show it again
            self.runner.last_dialog_type = None
            self.runner.last_dialog_title = None
            self.runner.last_dialog_text = None
            self.runner.last_dialog_resp_file = None

        if not self.started:
            self.start_next()
        else:
            if self.runner.done:
                # Record result
                rc = self.runner.returncode
                success = rc == 0
                self.job_results.append(success)

                # Save to history
                job_name = self.jobs[self.current][0]
                # Check if this is an uninstall job
                if "(Uninstall)" in job_name:
                    # Remove from history if uninstall succeeded
                    if success:
                        # Extract app name (remove " (Uninstall)" suffix)
                        app_name = job_name.replace(" (Uninstall)", "")
                        mark_uninstalled(app_name)
                        remove_package_state(app_name)
                else:
                    # Regular install - mark as installed
                    mark_installed(job_name, success)

                    # A successful BUA install/update becomes the new
                    # package revision baseline.
                    if success and job_name in APPS:
                        # Consume application metadata emitted by the
                        # installer itself. This records the exact upstream
                        # application release that was installed.
                        registered = apply_install_registration(
                            job_name,
                            self.runner.lines
                        )

                        if not registered:
                            # Global fallback: the install succeeded, so query
                            # the same converted adapter in registration-only
                            # mode and record the identity that was just installed.
                            snapshot = get_catalog_registration_snapshot(
                                job_name
                            )

                            if snapshot.get("supported"):
                                registration = (
                                    snapshot.get("registration") or {}
                                )

                                if registration:
                                    marker = (
                                        "__BUA_REGISTER__="
                                        + json.dumps(
                                            registration,
                                            sort_keys=True,
                                            separators=(",", ":"),
                                        )
                                    )

                                    source_label = (
                                        "generic_catalog"
                                        if str(
                                            snapshot.get("source") or ""
                                        ).startswith(("http://", "https://"))
                                        else "registration_adapter"
                                    )

                                    registered = apply_install_registration(
                                        job_name,
                                        [marker],
                                        registration_source=source_label,
                                    )

                            if not registered:
                                print(
                                    f"[BUA] Unable to determine installed "
                                    f"application identity for {job_name}"
                                )
                # If the installer emitted a dialog message, show it as an in-app message box
                if self.runner.last_dialog_title or self.runner.last_dialog_text:
                    title = self.runner.last_dialog_title or job_name
                    text = self.runner.last_dialog_text or ""
                    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
                    push_screen(InfoDialog(title=title, message=lines))
                # If installation succeeded and output contains URLs, show them
                elif success:
                    # Look for URLs in the last 20 lines of output
                    url_lines = []
                    for line in self.runner.lines[-20:]:
                        # Internal package-registration metadata is consumed
                        # by apply_install_registration(), never shown to users.
                        if line.strip().startswith(BUA_REGISTRATION_PREFIX):
                            continue

                        # Detect http/https URLs
                        if "http://" in line or "https://" in line:
                            url_lines.append(line.strip())
                    # If we found URLs, show them in a dialog
                    if url_lines:
                        push_screen(InfoDialog(title=job_name, message=url_lines))
                # Refresh top-level menu stats after every install
                try:
                    for _s in SCREENS:
                        if isinstance(_s, MenuScreen):
                            _s.stats = _s.calculate_stats()
                except Exception:
                    pass
                
                self.current += 1
                self.started = False
                if self.current < len(self.jobs):
                    pass  # Continue to next job
                else:
                    self.all_finished = True

    def draw(self):
        draw_background(screen)
        
        # If showing log, display it instead of progress
        if self.show_log:
            draw_text(screen, t("installation_log"), FONT_BIG, FG, (40, 30))
            # Icon hints: X hides log, B returns
            draw_hints_line(screen, f"X={t('hint_hide_log')} | B={t('hint_return')} | Back={t('hint_back_settings')}", FONT_SMALL, ACCENT, (40, 70))
            log_rect = pygame.Rect(40, 90, W-80, H-140)
            pygame.draw.rect(screen, CARD, log_rect, border_radius=12)
            
            with self.runner.lock:
                visible_lines = [
                    line
                    for line in self.runner.lines
                    if not line.strip().startswith(
                        BUA_REGISTRATION_PREFIX
                    )
                ]
                view = visible_lines[-35:]
            y = log_rect.y + 12
            for ln in view:
                if y > log_rect.bottom - 20:
                    break
                draw_text(screen, ln, FONT_SMALL, (210, 215, 225), (log_rect.x+12, y))
                y += 18
            return
        
        draw_text(screen, self.title, FONT_BIG, FG, (40, 30))
        draw_hints_line(screen, f"B={t('hint_return')} | X={t('hint_view_log')} | Back={t('hint_back_settings')}", FONT_SMALL, ACCENT, (40, 70))
        
        # Progress info with spinner
        progress_y = 100
        total_jobs = len(self.jobs)
        completed = len(self.job_results)

        if self.started and not self.runner.done:
            # Animate spinner
            self.spinner_frame = (self.spinner_frame + 1) % (len(self.spinner_chars) * 3)
            spinner = self.spinner_chars[self.spinner_frame // 3]
            status_text = f"{spinner} {t('installing')} {completed + 1} of {total_jobs}: {self.jobs[self.current][0]}"
        elif self.all_finished:
            status_text = t("all_complete")
        else:
            status_text = t("preparing")

        draw_text(screen, status_text, FONT, FG, (40, progress_y))
        
        # Summary count
        success_count = sum(self.job_results) if self.job_results else 0
        fail_count = len(self.job_results) - success_count if self.job_results else 0
        summary = f"{t('completed')}: {completed}/{total_jobs}"
        if fail_count > 0:
            summary += f" ({success_count} {t('succeeded')}, {fail_count} {t('failed')})"
        draw_text(screen, summary, FONT_SMALL, MUTED, (40, progress_y + 30))
        
        # Installation list with large cards
        list_y = progress_y + 80
        draw_text(screen, t("installation_queue_title"), FONT, FG, (40, list_y))

        # Auto-scroll to keep current job visible
        max_visible = 8
        if self.started and self.current < len(self.jobs):
            # Center the current job in the visible range
            start_idx = max(0, min(self.current - max_visible // 2, len(self.jobs) - max_visible))
        else:
            start_idx = 0

        card_y = list_y + 40
        visible_jobs = self.jobs[start_idx:start_idx + max_visible]

        for i, (name, _cmd) in enumerate(visible_jobs):
            actual_idx = start_idx + i
            if i >= max_visible:
                break
            
            # Large card for each item
            card_rect = pygame.Rect(40, card_y, W - 80, 60)
            pygame.draw.rect(screen, CARD, card_rect, border_radius=10)
            
            # Status indicator box on left
            box = pygame.Rect(card_rect.x + 20, card_rect.y + 15, 26, 26)

            if actual_idx < len(self.job_results):
                # Job completed - show success or failure
                if self.job_results[actual_idx]:
                    # Success - green checkmark
                    pygame.draw.rect(screen, (100, 255, 100), box, width=2)
                    pygame.draw.line(screen, (100, 255, 100), (box.x+4, box.centery), (box.centerx, box.bottom-5), 3)
                    pygame.draw.line(screen, (100, 255, 100), (box.centerx, box.bottom-5), (box.right-4, box.y+5), 3)
                    status_color = (100, 255, 100)
                    status_text = t("completed")
                else:
                    # Failed - red X
                    pygame.draw.rect(screen, (255, 100, 100), box, width=2)
                    pygame.draw.line(screen, (255, 100, 100), (box.x+4, box.y+4), (box.right-4, box.bottom-4), 3)
                    pygame.draw.line(screen, (255, 100, 100), (box.right-4, box.y+4), (box.x+4, box.bottom-4), 3)
                    status_color = (255, 100, 100)
                    status_text = t("failed")

                # Highlight the card if selected
                if actual_idx == self.current - 1 and self.started:
                    pygame.draw.rect(screen, status_color, card_rect, width=2, border_radius=10)

            elif actual_idx == self.current and self.started:
                # Currently installing - animated box
                pygame.draw.rect(screen, (255, 200, 100), card_rect, width=3, border_radius=10)
                pygame.draw.rect(screen, (255, 200, 100), box, width=2)
                # Pulsing fill
                pulse = abs(((self.spinner_frame * 2) % 60) - 30) / 30.0
                inner_size = int(12 * pulse)
                if inner_size > 0:
                    inner_rect = box.inflate(-inner_size, -inner_size)
                    pygame.draw.rect(screen, (255, 200, 100), inner_rect)
                status_color = (255, 200, 100)
                status_text = t("installing")
            else:
                # Pending - gray empty box
                pygame.draw.rect(screen, MUTED, box, width=2)
                status_color = MUTED
                status_text = t("queued")

            # Item name
            draw_text(screen, name, FONT, FG if actual_idx <= self.current else MUTED, (box.right + 16, card_rect.y + 10))

            # Status text
            draw_text(screen, status_text, FONT_SMALL, status_color, (box.right + 16, card_rect.y + 33))

            card_y += 65

        # Show "... and X more" indicator if there are items below the visible range
        remaining_below = len(self.jobs) - (start_idx + len(visible_jobs))
        if remaining_below > 0:
            draw_text(screen, t("and_more_items").format(count=remaining_below), FONT_SMALL, MUTED, (60, card_y))


# ------------------------------
# Updater Screen
# ------------------------------

def parse_github_raw_url(cmd: str):
    """Extract (owner, repo, branch, path) from a GitHub raw URL inside a shell cmd.
    Supports both github.com/.../raw/... and raw.githubusercontent.com forms.
    Returns None if cannot parse.
    """
    try:
        # Find first URL-looking token
        parts = cmd.split()
        url = None
        for p in parts:
            if p.startswith("http://") or p.startswith("https://"):
                url = p
                break
        if not url:
            return None
        u = urlparse(url)
        if u.netloc == "github.com":
            # /{owner}/{repo}/raw/{branch}/{path...}
            # or /{owner}/{repo}/raw/refs/heads/{branch}/{path}
            seg = [s for s in u.path.split("/") if s]
            if len(seg) >= 5 and seg[2] == "raw":
                owner, repo = seg[0], seg[1]
                if seg[3] == "refs" and len(seg) >= 7 and seg[4] == "heads":
                    branch = seg[5]
                    path = "/".join(seg[6:])
                else:
                    branch = seg[3]
                    path = "/".join(seg[4:])
                return owner, repo, branch, path
        if u.netloc == "raw.githubusercontent.com":
            # /{owner}/{repo}/{branch}/{path...}
            seg = [s for s in u.path.split("/") if s]
            if len(seg) >= 4:
                owner, repo, branch = seg[0], seg[1], seg[2]
                # refs/heads/<branch>
                if branch == "refs" and len(seg) >= 5 and seg[3] == "heads":
                    branch = seg[4]
                    path = "/".join(seg[5:])
                else:
                    path = "/".join(seg[3:])
                return owner, repo, branch, path
    except Exception:
        return None
    return None


# Cache for SCRIPT_DATES.md content
_SCRIPT_DATES_CACHE: Dict[str, str] | None = None

def get_script_dates() -> Dict[str, str]:
    """Fetch and parse SCRIPT_DATES.md, returning a dict of {path: date_string}"""
    global _SCRIPT_DATES_CACHE

    if _SCRIPT_DATES_CACHE is not None:
        return _SCRIPT_DATES_CACHE

    _SCRIPT_DATES_CACHE = {}
    try:
        script_dates_url = "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/SCRIPT_DATES.md"
        req = urllib.request.Request(script_dates_url, headers={"User-Agent": "BUA-Updater"})
        with urllib.request.urlopen(req, timeout=10) as resp:
            content = resp.read().decode("utf-8", "ignore")
            # Parse markdown table format: | `path/to/file.sh` | YYYY-MM-DD |
            for line in content.splitlines():
                line = line.strip()
                if not line.startswith("|") or line.count("|") < 3:
                    continue
                parts = [p.strip() for p in line.split("|")]
                if len(parts) >= 3:
                    # parts[0] is empty (before first |)
                    # parts[1] is the path wrapped in backticks
                    # parts[2] is the date
                    file_path = parts[1].strip("`").strip()
                    date_str = parts[2].strip()
                    # Skip header rows and separator rows
                    if file_path and date_str and date_str != "N/A" and not file_path.startswith("-") and file_path != "File":
                        _SCRIPT_DATES_CACHE[file_path] = date_str
    except Exception:
        pass

    return _SCRIPT_DATES_CACHE


def github_latest_commit_date(owner: str, repo: str, branch: str, path: str) -> float | None:
    """Return epoch seconds of the latest commit date for a file path on a branch.

    Uses SCRIPT_DATES.md instead of GitHub API for better performance and reliability.
    """
    try:
        dates_dict = get_script_dates()
        date_str = dates_dict.get(path)

        if not date_str:
            return None

        # Parse ISO format: "2025-11-27 20:52:39 +0000"
        # Split to get just the datetime part without timezone
        date_parts = date_str.rsplit(' ', 1)[0]  # Remove timezone offset
        dt = datetime.strptime(date_parts, "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
        return dt.timestamp()
    except Exception:
        return None



GLOBAL_MANIFEST_PATH = Path(
    "/userdata/system/add-ons/bua/updater/catalog/global/"
    "global-update-manifest.json"
)

GLOBAL_MANIFEST_FINGERPRINT_PATH = Path(
    "/userdata/system/add-ons/bua/updater/catalog/global/"
    "catalog-apps-fingerprint.txt"
)

GLOBAL_MANIFEST_BUILDER = Path(
    "/userdata/system/add-ons/bua/updater/catalog/"
    "build_global_update_manifest.py"
)


def get_live_apps_fingerprint() -> str:
    """
    Return a stable fingerprint of the complete live BUA APPS catalog.

    Any app addition, removal, rename, or installer-command change
    changes this fingerprint.
    """
    import hashlib

    payload = json.dumps(
        sorted(
            (
                str(app),
                str(command),
            )
            for app, command in APPS.items()
        ),
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")

    return hashlib.sha256(
        payload
    ).hexdigest()


def ensure_global_manifest_current() -> Dict:
    """
    Rebuild the canonical global update manifest only when the live
    APPS catalog has changed.

    This runs inside the Updater scan thread, so network work does not
    block the pygame UI thread.
    """
    result = {
        "rebuilt": False,
        "current": False,
        "error": None,
    }

    live_fingerprint = (
        get_live_apps_fingerprint()
    )

    saved_fingerprint = ""

    try:
        saved_fingerprint = (
            GLOBAL_MANIFEST_FINGERPRINT_PATH
            .read_text(
                encoding="utf-8"
            )
            .strip()
        )
    except Exception:
        pass

    # Also verify that the manifest actually exists.
    if (
        GLOBAL_MANIFEST_PATH.is_file()
        and saved_fingerprint
        == live_fingerprint
    ):
        result["current"] = True
        return result

    if not GLOBAL_MANIFEST_BUILDER.is_file():
        result["error"] = (
            "Global manifest builder is missing"
        )
        return result

    try:
        process = subprocess.run(
            [
                sys.executable,
                str(GLOBAL_MANIFEST_BUILDER),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300,
        )
    except Exception as exc:
        result["error"] = (
            f"Manifest rebuild failed: {exc}"
        )
        return result

    if process.returncode != 0:
        output = (
            process.stdout
            or ""
        ).strip()

        result["error"] = (
            "Manifest rebuild exited "
            f"{process.returncode}"
        )

        if output:
            result["error"] += (
                ": "
                + output[-500:]
            )

        return result

    if not GLOBAL_MANIFEST_PATH.is_file():
        result["error"] = (
            "Manifest rebuild completed but "
            "no manifest was produced"
        )
        return result

    try:
        GLOBAL_MANIFEST_FINGERPRINT_PATH.write_text(
            live_fingerprint + "\n",
            encoding="utf-8",
        )
    except Exception as exc:
        result["error"] = (
            "Manifest rebuilt but fingerprint "
            f"could not be saved: {exc}"
        )

        # The rebuilt manifest itself is still usable.
        result["rebuilt"] = True
        result["current"] = True
        return result

    # Registration snapshots may have been generated from the old
    # catalog. Force subsequent version checks to use the new manifest.
    REGISTRATION_SNAPSHOT_CACHE.clear()

    result["rebuilt"] = True
    result["current"] = True
    return result


# Global GitHub cache that persists across UpdaterScreen instances
# This prevents "unknown API error" when re-entering the updater
GITHUB_CACHE: Dict[str, tuple] = {}  # {app: (status, needs_update, detail)}


class UpdaterScreen(BaseScreen):
    """
    Two-stage updater:

      1. Select installed BUA apps to scan.
      2. Scan only those apps and show the normal update checklist.
    """

    PHASE_SCAN_SELECT = "scan_select"
    PHASE_SCANNING = "scanning"
    PHASE_RESULTS = "results"

    def __init__(self):
        global _SCRIPT_DATES_CACHE

        _SCRIPT_DATES_CACHE = None

        self.items: List[
            Tuple[str, str, bool, str]
        ] = []

        self.idx = 0
        self.selected: Dict[str, bool] = {}
        self.loading = False
        self.error: str | None = None
        self.needs_rescan = False

        self.uninstalling_app: str | None = None
        self.runner: Runner | None = None

        self.phase = self.PHASE_SCAN_SELECT
        self.scan_target_count = 0

        self._prepare_scan_selection()


    def _get_installed_apps(self) -> List[str]:
        """
        Return all installed apps known to the BUA catalog/history.
        """
        json_installed = [
            k
            for k in APPS.keys()
            if is_installed(k)
        ]

        dir_installed_dict = (
            scan_installed_addons_directory()
        )

        installed_apps = list(
            set(
                json_installed
                + list(
                    dir_installed_dict.keys()
                )
            )
        )

        installed_apps = [
            app
            for app in installed_apps
            if app in APPS
        ]

        installed_apps.sort(
            key=str.lower
        )

        return installed_apps


    def _prepare_scan_selection(self):
        """
        Initial updater screen: checklist of installed BUA apps.
        Nothing is selected by default.
        """
        self.phase = self.PHASE_SCAN_SELECT
        self.loading = False
        self.error = None
        self.idx = 0
        self.scan_target_count = 0

        installed_apps = (
            self._get_installed_apps()
        )

        self.items = [
            (
                app,
                "Select to scan",
                True,
                "",
            )
            for app in installed_apps
        ]

        self.selected = {
            app: False
            for app in installed_apps
        }


    def _toggle_select_all(self):
        """
        Select all installed apps, or deselect all if all are
        currently selected.
        """
        if (
            self.phase
            != self.PHASE_SCAN_SELECT
            or self.loading
            or not self.items
        ):
            return

        apps = [
            item[0]
            for item in self.items
        ]

        all_selected = bool(apps) and all(
            self.selected.get(app, False)
            for app in apps
        )

        new_value = not all_selected

        for app in apps:
            self.selected[app] = new_value


    def _start_selected_scan(self):
        """
        Begin update checking only for apps selected on the
        first-stage checklist.
        """
        if (
            self.loading
            or self.phase
            != self.PHASE_SCAN_SELECT
        ):
            return

        selected_apps = [
            app
            for app, enabled
            in self.selected.items()
            if enabled
        ]

        if not selected_apps:
            push_screen(
                InfoDialog(
                    t("updater"),
                    [
                        "Select at least one installed "
                        "application to scan."
                    ],
                )
            )
            return

        selected_apps.sort(
            key=str.lower
        )

        self.phase = self.PHASE_SCANNING
        self.loading = True
        self.error = None
        self.idx = 0
        self.scan_target_count = len(
            selected_apps
        )

        # Keep a visible list while scanning.
        self.items = [
            (
                app,
                "Waiting to scan",
                False,
                "",
            )
            for app in selected_apps
        ]

        self.selected = {}

        threading.Thread(
            target=lambda: self._scan_selected(
                selected_apps,
                use_cache=False,
            ),
            daemon=True,
        ).start()


    def _scan_selected(
        self,
        installed_apps: List[str],
        use_cache: bool = False,
    ):
        """
        Scan only the apps explicitly selected by the user.
        """
        try:
            manifest_refresh = (
                ensure_global_manifest_current()
            )

            if manifest_refresh.get("error"):
                print(
                    "[BUA] Global manifest refresh: "
                    + str(
                        manifest_refresh.get(
                            "error"
                        )
                    )
                )

            elif manifest_refresh.get(
                "rebuilt"
            ):
                print(
                    "[BUA] Global update manifest "
                    "rebuilt for current APPS catalog"
                )

            results = []

            for app in installed_apps:
                if (
                    use_cache
                    and app in GITHUB_CACHE
                ):
                    (
                        status,
                        needs,
                        detail,
                    ) = GITHUB_CACHE[app]

                    results.append(
                        (
                            app,
                            status,
                            needs,
                            detail,
                        )
                    )
                    continue

                blocked = (
                    get_blocked_source_status(
                        app
                    )
                )

                if blocked:
                    status = "Blocked source"
                    needs = False

                    detail = (
                        blocked.get("reason")
                        or blocked.get("source")
                        or
                        "Required source is unavailable"
                    )

                    GITHUB_CACHE[app] = (
                        status,
                        needs,
                        detail,
                    )

                    results.append(
                        (
                            app,
                            status,
                            needs,
                            detail,
                        )
                    )
                    continue

                app_status = (
                    get_app_version_status(app)
                )

                app_state = (
                    app_status.get("status")
                )

                installed_version = (
                    app_status.get(
                        "installed_version"
                    )
                    or ""
                )

                latest_version = (
                    app_status.get(
                        "latest_version"
                    )
                    or ""
                )

                details = []

                if (
                    app_state
                    == "update_available"
                ):
                    (
                        update_cmd,
                        update_error,
                    ) = (
                        build_parent_update_command(
                            app
                        )
                    )

                    if update_cmd:
                        status = t(
                            "update_available"
                        )
                        needs = True
                    else:
                        status = (
                            "Update recipe unavailable"
                        )
                        needs = False

                    if (
                        installed_version
                        and latest_version
                    ):
                        details.append(
                            f"{installed_version} "
                            f"-> {latest_version}"
                        )

                    elif latest_version:
                        details.append(
                            f"Latest "
                            f"{latest_version}"
                        )

                    if update_error:
                        details.append(
                            update_error
                        )

                    detail = " | ".join(
                        details
                    )

                elif app_state == "current":
                    status = t(
                        "up_to_date"
                    )
                    needs = False

                    if installed_version:
                        details.append(
                            f"Version "
                            f"{installed_version}"
                        )

                    detail = " | ".join(
                        details
                    )

                else:
                    status = (
                        "App version unknown"
                    )
                    needs = False

                    if installed_version:
                        details.append(
                            f"Installed "
                            f"{installed_version}"
                        )

                    if latest_version:
                        details.append(
                            f"Latest "
                            f"{latest_version}"
                        )

                    app_error = (
                        app_status.get(
                            "error"
                        )
                    )

                    if app_error:
                        details.append(
                            app_error
                        )

                    detail = " | ".join(
                        details
                    )

                GITHUB_CACHE[app] = (
                    status,
                    needs,
                    detail,
                )

                results.append(
                    (
                        app,
                        status,
                        needs,
                        detail,
                    )
                )

            # Updates first, then alphabetical.
            results.sort(
                key=lambda x: (
                    not x[2],
                    x[0].lower(),
                )
            )

            self.items = results

            # Preserve current updater behavior:
            # available updates begin selected.
            self.selected = {
                app: needs
                for (
                    app,
                    _status,
                    needs,
                    _detail,
                ) in self.items
                if needs
            }

            self.idx = 0
            self.phase = self.PHASE_RESULTS

        except Exception as e:
            self.error = str(e)
            self.phase = self.PHASE_RESULTS

        finally:
            self.loading = False


    def rescan(self, use_cache=True):
        """
        Return to the app-selection checklist after an uninstall or
        when a fresh scan selection is requested.
        """
        self._prepare_scan_selection()


    def handle(self, events):
        analog_v, _analog_h = (
            process_analog_navigation(
                events
            )
        )

        if (
            not self.loading
            and self.items
        ):
            if analog_v == 1:
                self.idx = min(
                    self.idx + 1,
                    len(self.items) - 1,
                )

            elif analog_v == -1:
                self.idx = max(
                    self.idx - 1,
                    0,
                )

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)

            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen()
                    return

                if e.key == pygame.K_DOWN:
                    if (
                        not self.loading
                        and self.items
                    ):
                        self.idx = min(
                            self.idx + 1,
                            len(self.items) - 1,
                        )

                if e.key == pygame.K_UP:
                    if (
                        not self.loading
                        and self.items
                    ):
                        self.idx = max(
                            self.idx - 1,
                            0,
                        )

                if e.key in (
                    pygame.K_RETURN,
                    pygame.K_KP_ENTER,
                ):
                    if (
                        not self.loading
                        and self.items
                    ):
                        app = (
                            self.items[
                                self.idx
                            ][0]
                        )

                        selectable = (
                            self.phase
                            == self.PHASE_SCAN_SELECT
                            or bool(
                                self.items[
                                    self.idx
                                ][2]
                            )
                        )

                        if selectable:
                            self.selected[app] = (
                                not self.selected.get(
                                    app,
                                    False,
                                )
                            )

                # Keyboard X = Select All /
                # Deselect All on scan-selection screen.
                if e.key == pygame.K_x:
                    self._toggle_select_all()

                # Existing keyboard Start equivalent.
                if e.key == pygame.K_SPACE:
                    if not self.loading:
                        if (
                            self.phase
                            == self.PHASE_SCAN_SELECT
                        ):
                            self._start_selected_scan()

                        elif (
                            self.phase
                            == self.PHASE_RESULTS
                        ):
                            self.queue_updates()

            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value

                if y == -1:
                    self.idx = min(
                        self.idx + 1,
                        max(
                            0,
                            len(self.items) - 1,
                        ),
                    )

                elif y == 1:
                    self.idx = max(
                        self.idx - 1,
                        0,
                    )

            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (
                    BTN_B,
                    BTN_BACK,
                ):
                    pop_screen()
                    return

                if e.button == BTN_A:
                    if (
                        not self.loading
                        and self.items
                    ):
                        app = (
                            self.items[
                                self.idx
                            ][0]
                        )

                        selectable = (
                            self.phase
                            == self.PHASE_SCAN_SELECT
                            or bool(
                                self.items[
                                    self.idx
                                ][2]
                            )
                        )

                        if selectable:
                            self.selected[app] = (
                                not self.selected.get(
                                    app,
                                    False,
                                )
                            )

                # X = Select All / Deselect All.
                if e.button == BTN_X:
                    self._toggle_select_all()

                if e.button == BTN_START:
                    if not self.loading:
                        if (
                            self.phase
                            == self.PHASE_SCAN_SELECT
                        ):
                            self._start_selected_scan()

                        elif (
                            self.phase
                            == self.PHASE_RESULTS
                        ):
                            self.queue_updates()

                if e.button == BTN_Y:
                    if (
                        not self.loading
                        and self.items
                    ):
                        self.uninstall_app()


    def uninstall_app(self):
        """
        Uninstall the currently highlighted app inline.
        """
        if (
            self.loading
            or not self.items
            or self.uninstalling_app
        ):
            return

        app = self.items[self.idx][0]
        cmd = APPS.get(app)

        if not cmd:
            return

        uninstall_cmd = (
            get_uninstall_command(
                cmd,
                app,
            )
        )

        if not uninstall_cmd:
            push_screen(
                InfoDialog(
                    t("uninstall"),
                    [
                        t(
                            "uninstall_error"
                        )
                    ],
                )
            )
            return

        self.uninstalling_app = app
        self.runner = Runner()
        self.runner.run(
            uninstall_cmd
        )


    def queue_updates(self):
        if (
            self.loading
            or self.phase
            != self.PHASE_RESULTS
        ):
            return

        selected_apps = [
            app
            for app in self.selected
            if self.selected.get(
                app,
                False,
            )
        ]

        if not selected_apps:
            push_screen(
                InfoDialog(
                    t("updater"),
                    [
                        t(
                            "nothing_selected_update"
                        )
                    ],
                )
            )
            return

        unavailable = []

        for app in selected_apps:
            cmd, error = (
                build_parent_update_command(
                    app
                )
            )

            if not cmd:
                unavailable.append(
                    f"{app}: "
                    f"{error or 'No update recipe'}"
                )
                continue

            item = (app, cmd)

            if item not in INSTALL_QUEUE:
                INSTALL_QUEUE.append(item)

        if not INSTALL_QUEUE:
            push_screen(
                InfoDialog(
                    t("updater"),
                    unavailable
                    or [
                        "No selected applications "
                        "have a parent-source "
                        "update recipe."
                    ],
                )
            )
            return

        pop_screen()
        push_screen(
            QueueScreen()
        )


    def update(self):
        if (
            self.needs_rescan
            and not self.loading
        ):
            self.needs_rescan = False
            self.rescan()

        if (
            self.uninstalling_app
            and self.runner
            and self.runner.done
        ):
            success = (
                self.runner.returncode
                == 0
            )

            if success:
                mark_uninstalled(
                    self.uninstalling_app
                )

                remove_package_state(
                    self.uninstalling_app
                )

            self.uninstalling_app = None
            self.runner = None

            # Return to installed-app selection
            # so the removed app disappears.
            self.rescan()


    def draw(self):
        draw_background(screen)

        draw_text(
            screen,
            t("updater_title"),
            FONT_BIG,
            FG,
            (40, 30),
        )

        hint_parts = []

        if (
            self.phase
            == self.PHASE_SCAN_SELECT
        ):
            selected_count = sum(
                1
                for value
                in self.selected.values()
                if value
            )

            total_count = len(
                self.items
            )

            all_selected = bool(
                self.items
            ) and (
                selected_count
                == total_count
            )

            hint_parts.append(
                f"A={t('hint_toggle')}"
            )

            hint_parts.append(
                "X="
                + (
                    "Deselect All"
                    if all_selected
                    else "Select All"
                )
            )

            hint_parts.append(
                "Start=Scan Selected"
            )

        elif (
            self.phase
            == self.PHASE_RESULTS
        ):
            current_needs = False

            if (
                not self.loading
                and self.items
            ):
                try:
                    current_needs = bool(
                        self.items[
                            self.idx
                        ][2]
                    )
                except Exception:
                    pass

            if current_needs:
                hint_parts.append(
                    f"A={t('hint_toggle')}"
                )

            hint_parts.append(
                f"Y={t('hint_uninstall')}"
            )

            hint_parts.append(
                "Start=Update Selected"
            )

        hint_parts.append(
            f"B={t('hint_return')}"
        )

        draw_hints_line(
            screen,
            " | ".join(hint_parts),
            FONT_SMALL,
            ACCENT,
            (40, 70),
        )

        if self.loading:
            if (
                self.phase
                == self.PHASE_SCANNING
            ):
                draw_text(
                    screen,
                    (
                        "Scanning selected "
                        f"applications "
                        f"({self.scan_target_count})..."
                    ),
                    FONT,
                    MUTED,
                    (40, 100),
                )
            else:
                draw_text(
                    screen,
                    t("scanning_updates"),
                    FONT,
                    MUTED,
                    (40, 100),
                )

            return

        if self.error:
            draw_text(
                screen,
                f"{t('error')}: "
                f"{self.error}",
                FONT,
                (255, 120, 120),
                (40, 100),
            )
            return

        if not self.items:
            draw_text(
                screen,
                t("no_installed"),
                FONT,
                MUTED,
                (40, 100),
            )
            return

        if (
            self.phase
            == self.PHASE_SCAN_SELECT
        ):
            selected_count = sum(
                1
                for value
                in self.selected.values()
                if value
            )

            draw_text(
                screen,
                (
                    "Choose installed apps to scan "
                    f"({selected_count}/"
                    f"{len(self.items)} selected)"
                ),
                FONT_SMALL,
                MUTED,
                (40, 96),
            )

            base_y = 125

        else:
            base_y = 110

        item_pitch = 55
        avail_h = H - base_y - 40

        rows = min(
            len(self.items),
            get_visible_items(
                avail_h,
                item_pitch,
            ),
        )

        top = max(
            0,
            min(
                self.idx - rows // 2,
                max(
                    0,
                    len(self.items) - rows,
                ),
            ),
        )

        view = self.items[
            top:top + rows
        ]

        for i, (
            app,
            status,
            needs,
            detail,
        ) in enumerate(view):

            actual = top + i

            rect = pygame.Rect(
                40,
                base_y + i * item_pitch,
                W - 80,
                50,
            )

            pygame.draw.rect(
                screen,
                CARD,
                rect,
                border_radius=10,
            )

            if actual == self.idx:
                pygame.draw.rect(
                    screen,
                    SELECT,
                    rect,
                    width=3,
                    border_radius=10,
                )

            selectable = (
                self.phase
                == self.PHASE_SCAN_SELECT
                or needs
            )

            box = pygame.Rect(
                rect.x + 14,
                rect.y + 12,
                24,
                24,
            )

            if selectable:
                pygame.draw.rect(
                    screen,
                    (
                        FG
                        if self.selected.get(
                            app,
                            False,
                        )
                        else MUTED
                    ),
                    box,
                    width=2,
                )

                if self.selected.get(
                    app,
                    False,
                ):
                    pygame.draw.line(
                        screen,
                        FG,
                        (
                            box.x + 4,
                            box.centery,
                        ),
                        (
                            box.centerx,
                            box.bottom - 5,
                        ),
                        3,
                    )

                    pygame.draw.line(
                        screen,
                        FG,
                        (
                            box.centerx,
                            box.bottom - 5,
                        ),
                        (
                            box.right - 4,
                            box.y + 5,
                        ),
                        3,
                    )

                name_x = (
                    box.right + 12
                )

            else:
                name_x = (
                    rect.x + 14
                )

            draw_text(
                screen,
                app,
                FONT,
                FG,
                (
                    name_x,
                    rect.y + 8,
                ),
            )

            if (
                self.uninstalling_app
                == app
                and self.runner
            ):
                if self.runner.done:
                    status_text = (
                        "Uninstall complete"
                        if (
                            self.runner.returncode
                            == 0
                        )
                        else
                        "Uninstall failed"
                    )
                else:
                    status_text = (
                        "Uninstalling..."
                    )

                draw_text(
                    screen,
                    status_text,
                    FONT_SMALL,
                    ACCENT,
                    (
                        name_x,
                        rect.y + 30,
                    ),
                )

            elif (
                self.phase
                == self.PHASE_SCAN_SELECT
            ):
                draw_text(
                    screen,
                    "Installed",
                    FONT_SMALL,
                    MUTED,
                    (
                        name_x,
                        rect.y + 30,
                    ),
                )

            else:
                color = (
                    ACCENT
                    if needs
                    else MUTED
                )

                suffix = (
                    f" — {detail}"
                    if detail
                    else ""
                )

                draw_text(
                    screen,
                    status + suffix,
                    FONT_SMALL,
                    color,
                    (
                        name_x,
                        rect.y + 30,
                    ),
                )


class OnScreenKeyboard:
    def __init__(self):
        # Use space-separated rows so each character is an individual key
        self.keys = [
            "Q W E R T Y U I O P",
            "A S D F G H J K L",
            "Z X C V B N M",
            "SPACE BACKSPACE",
            "ENTER EXIT",
        ]
        self.key_width = S(80)
        self.key_height = S(60)
        self.margin = S(10)
        self.selected_row = 0
        self.selected_col = 0

    def handle(self, events):
        for e in events:
            if e.type == pygame.KEYDOWN:
                # Direct physical keyboard typing support
                if pygame.K_a <= e.key <= pygame.K_z:
                    return chr(e.key - pygame.K_a + ord('A'))
                if pygame.K_0 <= e.key <= pygame.K_9:
                    return chr(e.key - pygame.K_0 + ord('0'))
                if e.key == pygame.K_SPACE:
                    return " "
                if e.key == pygame.K_BACKSPACE:
                    return "BACKSPACE"
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    return "ENTER"
                if e.key == pygame.K_ESCAPE:
                    return "EXIT"

                # Navigate OSK with arrows; select with A
                if e.key == pygame.K_DOWN:
                    self.selected_row = min(self.selected_row + 1, len(self.keys) - 1)
                    self.selected_col = min(self.selected_col, len(self.keys[self.selected_row].split()) - 1)
                if e.key == pygame.K_UP:
                    self.selected_row = max(self.selected_row - 1, 0)
                    self.selected_col = min(self.selected_col, len(self.keys[self.selected_row].split()) - 1)
                if e.key == pygame.K_RIGHT:
                    self.selected_col = min(self.selected_col + 1, len(self.keys[self.selected_row].split()) - 1)
                if e.key == pygame.K_LEFT:
                    self.selected_col = max(self.selected_col - 1, 0)
                if e.key == pygame.K_a:
                    return self.select_key()
            if e.type == pygame.JOYHATMOTION:
                x, y = e.value
                if y == -1:
                    self.selected_row = min(self.selected_row + 1, len(self.keys) - 1)
                    self.selected_col = min(self.selected_col, len(self.keys[self.selected_row].split()) - 1)
                elif y == 1:
                    self.selected_row = max(self.selected_row - 1, 0)
                    self.selected_col = min(self.selected_col, len(self.keys[self.selected_row].split()) - 1)
                if x == 1:
                    self.selected_col = min(self.selected_col + 1, len(self.keys[self.selected_row].split()) - 1)
                elif x == -1:
                    self.selected_col = max(self.selected_col - 1, 0)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):  # A or Start -> select
                    return self.select_key()
                if e.button in (BTN_B, BTN_BACK):  # B/Back -> exit keyboard
                    return "EXIT"
        return None

    def select_key(self):
        row = self.keys[self.selected_row].split()
        key = row[self.selected_col]
        if key == "SPACE":
            return " "
        elif key == "BACKSPACE":
            return "BACKSPACE"
        elif key == "ENTER":
            return "ENTER"
        elif key == "EXIT":
            return "EXIT"
        else:
            return key

    def draw(self, surf, current_text: str = ""):
        # Draw semi-transparent overlay
        overlay = pygame.Surface((W, H))
        overlay.set_alpha(180)
        overlay.fill(BG)
        surf.blit(overlay, (0, 0))

        # Compute dynamic box size to fully cover keys (with variable widths)
        padding = S(40)
        total_rows = len(self.keys)

        def key_w(k: str) -> int:
            # Uniform sizing: all letters use key_width;
            # SPACE, BACKSPACE, ENTER, EXIT use the same wider width
            if k in ("SPACE", "BACKSPACE", "ENTER", "EXIT"):
                return self.key_width * 2
            return self.key_width

        # Width of each row using variable key widths
        row_widths = []
        for row in self.keys:
            cols = row.split()
            w = sum(key_w(k) for k in cols) + max(0, len(cols) - 1) * self.margin
            row_widths.append(w)
        keys_block_width = max(row_widths) if row_widths else 0
        keys_height = total_rows * self.key_height + max(0, total_rows - 1) * self.margin

        # Include input field and spacing inside the box height
        input_h = S(50)
        input_spacing = S(20)
        box_width = keys_block_width + 2 * padding
        box_height = input_h + input_spacing + keys_height + 2 * padding
        box_x = (W - box_width) // 2
        box_y = (H - box_height) // 2
        pygame.draw.rect(surf, CARD, (box_x, box_y, box_width, box_height), border_radius=15)
        pygame.draw.rect(surf, ACCENT, (box_x, box_y, box_width, box_height), width=3, border_radius=15)

        # Text input field at the top of the keyboard box
        input_rect = pygame.Rect(box_x + S(20), box_y + S(20), box_width - S(40), input_h)
        pygame.draw.rect(surf, (30, 34, 44), input_rect, border_radius=8)
        pygame.draw.rect(surf, ACCENT, input_rect, width=2, border_radius=8)
        draw_text(surf, f"{t('search')}: {current_text}_", FONT, FG, (input_rect.x + S(12), input_rect.y + S(10)))

        # Draw keys centered per row inside box
        x_start = box_x + padding
        y_start = input_rect.bottom + input_spacing
        for row_idx, row in enumerate(self.keys):
            cols = row.split()
            row_width = sum(key_w(k) for k in cols) + max(0, len(cols) - 1) * self.margin
            row_x_offset = (keys_block_width - row_width) // 2
            cx = x_start + row_x_offset
            for col_idx, key in enumerate(cols):
                w = key_w(key)
                rect = pygame.Rect(
                    cx,
                    y_start + row_idx * (self.key_height + self.margin),
                    w,
                    self.key_height,
                )
                # Draw key background
                pygame.draw.rect(surf, CARD, rect, border_radius=8)
                # Draw selection border if selected
                if row_idx == self.selected_row and col_idx == self.selected_col:
                    pygame.draw.rect(surf, SELECT, rect, width=3, border_radius=8)
                # Center the key label
                label = FONT.render(key, True, FG)
                lx = rect.x + (rect.w - label.get_width()) // 2
                ly = rect.y + (rect.h - label.get_height()) // 2
                surf.blit(label, (lx, ly))
                cx += w + self.margin


# ------------------------------
# Screen stack helpers and queue
# ------------------------------

SCREENS: List[BaseScreen] = []
INSTALL_QUEUE: List[Tuple[str, str]] = []  # Global queue for installs
SELECTED_APPS: Dict[str, bool] = {}  # Global selections that persist across category navigation

class SettingsScreen(BaseScreen):
    def __init__(self):
        self.items = [
            (t("controller_layout"), t("controller_layout_desc")),
            (t("configure_buttons"), t("configure_buttons_desc")),
            (t("language"), t("language_desc")),
            (t("cards_per_page"), t("cards_per_page_desc")),
        ]
        self.idx = 0

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.items)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.items)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE,):
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.items)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.items)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.activate()
            if e.type == pygame.JOYHATMOTION:
                x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.items)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.items)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.activate()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return

    def activate(self):
        name = self.items[self.idx][0]
        if name == t("controller_layout"):
            push_screen(ControllerLayoutScreen())
        elif name == t("configure_buttons"):
            ok = run_manual_button_mapper()
            msg = [t("controller_mapped") if ok else t("mapping_canceled")]
            push_screen(InfoDialog(t("settings_title"), msg))
        elif name == t("language"):
            push_screen(LanguageScreen())
        elif name == t("cards_per_page"):
            push_screen(CardsPerPageScreen())

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("settings_title"), FONT_BIG, FG, (40, 30))
        hint = f"A={t('hint_open')} | B={t('hint_return')} | Back={t('hint_close_settings')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))
        base_y = 110
        y = base_y
        card_w = min(W - S(80), S(900))
        card_x = (W - card_w) // 2
        pad_y = S(10)
        gap = S(6)
        spacing = S(12)
        for i, (name, desc) in enumerate(self.items):
            name_img = FONT.render(name, True, FG)
            desc_img = FONT_SMALL.render(desc, True, MUTED) if desc else None
            content_h = name_img.get_height() + ((gap + desc_img.get_height()) if desc_img else 0)
            rect_h = max(S(60), content_h + pad_y * 2)
            rect = pygame.Rect(card_x, y, card_w, rect_h)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if i == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            nx = rect.x + S(14)
            ny = rect.y + pad_y
            screen.blit(name_img, (nx, ny))
            if desc_img:
                dy = ny + name_img.get_height() + gap
                screen.blit(desc_img, (nx, dy))
            y += rect_h + spacing


class ControllerLayoutScreen(BaseScreen):
    def __init__(self):
        self.options = [
            (t("auto_detected"), "auto"),
            ("Xbox", "xbox"),
            ("PlayStation", "playstation"),
            ("Nintendo", "nintendo"),
            ("Generic", "generic"),
        ]
        style = PAD_STYLE_USER_OVERRIDE if PAD_STYLE_USER_OVERRIDE else "auto"
        self.idx = next((i for i, (_n, v) in enumerate(self.options) if v == style), 0)

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.options)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.options)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE,):
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.apply_choice()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.apply_choice()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return

    def apply_choice(self):
        _label, val = self.options[self.idx]
        set_pad_style_choice(val)
        msg = [f"{t('layout_set_to')} {PAD_STYLE}"]
        push_screen(InfoDialog(t("settings"), msg))

    def draw(self):
        draw_background(screen)
        title = t("controller_layout_title")
        draw_text(screen, title, FONT_BIG, FG, (40, 30))
        hint = f"A={t('hint_select')} | B={t('hint_return')} | Back={t('hint_back_settings')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))

        base_y = 110
        card_w = min(W - S(80), S(900))
        card_x = (W - card_w) // 2
        draw_text(screen, f"{t('device')}: {input_style_label()}", FONT_SMALL, MUTED, (card_x, base_y))
        draw_text(screen, f"{t('current')}: {PAD_STYLE}", FONT_SMALL, MUTED, (card_x, base_y + 24))
        base_y += 48
        for i, (label, _val) in enumerate(self.options):
            rect = pygame.Rect(card_x, base_y + i*48, card_w, 42)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if i == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            draw_text(screen, label, FONT, FG, (rect.x + 14, rect.y + 8))


class LanguageScreen(BaseScreen):
    def __init__(self):
        self.options = get_available_languages()  # List of (name, code, native_name) tuples
        # Find current language index
        self.idx = next((i for i, (_n, code, _native) in enumerate(self.options) if code == CURRENT_LANGUAGE), 0)
        self.scroll_offset = 0

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.options)
            self.adjust_scroll()
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.options)
            self.adjust_scroll()

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                    self.adjust_scroll()
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                    self.adjust_scroll()
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.apply_choice()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                    self.adjust_scroll()
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
                    self.adjust_scroll()
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.apply_choice()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return

    def adjust_scroll(self):
        """Adjust scroll offset to keep selected item visible"""
        item_height = 48
        list_h = H - 180
        visible_items = get_visible_items(list_h, item_height)

        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1

        # Clamp scroll offset
        max_scroll = max(0, len(self.options) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))

    def apply_choice(self):
        global CURRENT_LANGUAGE, TRANSLATIONS, TOP_LEVEL
        _name, code, native = self.options[self.idx]

        # Save and load the new language
        save_language(code)

        # Refresh TOP_LEVEL menu with new translations
        TOP_LEVEL = get_top_level()

        # Update all screens in the stack with new translations
        for screen in SCREENS:
            if isinstance(screen, MenuScreen):
                screen.title = t("main_title")
                screen.items = TOP_LEVEL
                # Recalculate stats to update translated strings
                if screen.stats:
                    screen.stats = screen.calculate_stats()
            elif isinstance(screen, SettingsScreen):
                # Refresh settings items with new translations
                screen.items = [
                    (t("controller_layout"), t("controller_layout_desc")),
                    (t("configure_buttons"), t("configure_buttons_desc")),
                    (t("language"), t("language_desc")),
                    (t("resolution"), t("resolution_desc")),
                ]

        msg = [f"{t('language')}: {native}"]
        push_screen(InfoDialog(t("settings_title"), msg))

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("language"), FONT_BIG, FG, (40, 30))
        hint = f"A={t('hint_select')} | B={t('hint_return')} | Back={t('hint_back_settings')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))

        base_y = 110
        card_w = min(W - S(80), S(900))
        card_x = (W - card_w) // 2

        # Get current language's native name for display
        current_native = next((native for _name, code, native in self.options if code == CURRENT_LANGUAGE), CURRENT_LANGUAGE.upper())
        draw_text(screen, f"{t('current')}: {current_native}", FONT_SMALL, MUTED, (card_x, base_y))
        base_y += 36

        # Calculate visible area
        item_height = 48
        visible_start_y = base_y
        visible_end_y = H - 40

        # Only render visible items
        for i in range(len(self.options)):
            display_idx = i - self.scroll_offset
            y_pos = base_y + display_idx * item_height

            # Skip items outside visible area
            if y_pos + item_height < visible_start_y or y_pos > visible_end_y:
                continue

            _name, _code, native = self.options[i]
            rect = pygame.Rect(card_x, y_pos, card_w, 42)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if i == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)

            # Show native language name
            display_text = native
            text_surf = FONT.render(display_text, True, FG)
            screen.blit(text_surf, (rect.x + 14, rect.y + 8))


class CardsPerPageScreen(BaseScreen):
    def __init__(self):
        # Options for number of cards per page
        self.options = [
            ("Auto", "auto"),
            ("3", "3"),
            ("4", "4"),
            ("5", "5"),
            ("6", "6"),
            ("7", "7"),
            ("8", "8"),
            ("9", "9"),
            ("10", "10"),
        ]
        self.idx = 0
        self.scroll_offset = 0
        # Find current setting
        for i, (label, value) in enumerate(self.options):
            if value == CARDS_PER_PAGE:
                self.idx = i
                break

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.options)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.options)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE,):
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.apply_choice()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.apply_choice()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return

    def apply_choice(self):
        label, value = self.options[self.idx]
        save_cards_per_page(value)
        msg = [f"{t('cards_per_page')}: {label}"]
        push_screen(InfoDialog(t("settings_title"), msg))

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("cards_per_page"), FONT_BIG, FG, (40, 30))
        hint = f"A={t('hint_select')} | B={t('hint_return')} | Back={t('hint_close_settings')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))

        base_y = 110
        card_w = min(W - S(80), S(900))
        card_x = (W - card_w) // 2

        # Show current setting
        current_label = CARDS_PER_PAGE
        for label, value in self.options:
            if value == CARDS_PER_PAGE:
                current_label = label
                break

        status_text = f"{t('current')}: {current_label}"
        status_img = FONT_SMALL.render(status_text, True, MUTED)
        screen.blit(status_img, (card_x, base_y))

        # List items with scrolling
        visible_start_y = base_y + 40
        visible_end_y = H - 40
        item_height = 52
        pad_y = S(10)

        list_h = visible_end_y - visible_start_y
        visible_items = get_visible_items(list_h, item_height)

        # Auto-scroll to keep selection visible
        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1

        y = visible_start_y
        for i in range(self.scroll_offset, min(len(self.options), self.scroll_offset + visible_items)):
            label, value = self.options[i]
            is_selected = (i == self.idx)
            is_current = (value == CARDS_PER_PAGE)

            rect = pygame.Rect(card_x, y, card_w, item_height - 4)
            pygame.draw.rect(screen, CARD, rect, border_radius=8)
            if is_selected:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=8)

            text_x = rect.x + S(14)
            text_y = rect.y + pad_y

            # Draw label
            label_img = FONT.render(label, True, FG)
            screen.blit(label_img, (text_x, text_y))

            # Show checkmark for current setting
            if is_current:
                check_img = FONT.render("✓", True, ACCENT)
                check_x = rect.x + card_w - check_img.get_width() - S(14)
                screen.blit(check_img, (check_x, text_y))

            y += item_height


class ResolutionScreen(BaseScreen):
    def __init__(self):
        # Common resolution options (including CRT resolutions)
        self.options = [
            ("Native (Borderless)", 0, 0),
            ("640x480", 640, 480),
            ("800x600", 800, 600),
            ("1024x768", 1024, 768),
            ("1280x960", 1280, 960),
            ("1280x1024", 1280, 1024),
            ("1600x1200", 1600, 1200),
            ("800x480", 800, 480),
            ("1024x600", 1024, 600),
            ("1280x720", 1280, 720),
            ("1280x800", 1280, 800),
            ("1366x768", 1366, 768),
            ("1600x900", 1600, 900),
            ("1920x1080", 1920, 1080),
            ("2560x1440", 2560, 1440),
            ("3840x2160", 3840, 2160),
        ]
        self.idx = 0
        self.scroll_offset = 0
        # Find current resolution
        current_w, current_h = W, H
        for i, (label, w, h) in enumerate(self.options):
            if label == "Native (Borderless)" and not load_saved_resolution():
                self.idx = i
                break
            elif w == current_w and h == current_h:
                self.idx = i
                break

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if analog_v == 1:  # Down
            self.idx = (self.idx + 1) % len(self.options)
        elif analog_v == -1:  # Up
            self.idx = (self.idx - 1) % len(self.options)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key in (pygame.K_ESCAPE,):
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    self.idx = (self.idx + 1) % len(self.options)
                if e.key in (pygame.K_UP,):
                    self.idx = (self.idx - 1) % len(self.options)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.apply_choice()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = (self.idx + 1) % len(self.options)
                elif y == 1:
                    self.idx = (self.idx - 1) % len(self.options)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_A, BTN_START):
                    self.apply_choice()
                if e.button in (BTN_B, BTN_BACK):
                    pop_screen(); return

    def apply_choice(self):
        # Display is now fixed at 1280x720 with SCALED|FULLSCREEN to prevent KMS corruption
        # Resolution changes are disabled for safe operation on Batocera KMS/DRM backend
        msg = [
            "Resolution is fixed at 1280x720 for safe operation.",
            "The display uses pygame.SCALED to fit your screen",
            "without changing the video mode or corrupting KMS."
        ]
        push_screen(InfoDialog(t("settings_title"), msg))

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("resolution"), FONT_BIG, FG, (40, 30))
        hint = f"A={t('hint_select')} | B={t('hint_return')} | Back={t('hint_close_settings')}"
        draw_hints_line(screen, hint, FONT_SMALL, ACCENT, (40, 70))

        base_y = 110
        card_w = min(W - S(80), S(900))
        card_x = (W - card_w) // 2

        # Show current resolution
        saved_res = load_saved_resolution()
        if saved_res:
            current_label = f"{saved_res[0]}x{saved_res[1]}"
        else:
            current_label = "Native (Borderless)"

        draw_text(screen, f"{t('current')}: {current_label} ({W}x{H})", FONT_SMALL, MUTED, (card_x, base_y))
        base_y += 36

        # Calculate visible area
        item_height = 52
        visible_start_y = base_y
        visible_end_y = H - 40
        list_h = visible_end_y - visible_start_y
        visible_items = get_visible_items(list_h, item_height)

        # Auto-scroll to keep selection visible
        if self.idx < self.scroll_offset:
            self.scroll_offset = self.idx
        elif self.idx >= self.scroll_offset + visible_items:
            self.scroll_offset = self.idx - visible_items + 1

        # Clamp scroll offset
        max_scroll = max(0, len(self.options) - visible_items)
        self.scroll_offset = max(0, min(self.scroll_offset, max_scroll))

        # Draw resolution options (only visible ones)
        for i in range(self.scroll_offset, min(len(self.options), self.scroll_offset + visible_items)):
            label, _w, _h = self.options[i]
            display_index = i - self.scroll_offset
            card_y = base_y + display_index * item_height

            # Skip if outside visible area
            if card_y + 48 < visible_start_y or card_y > visible_end_y:
                continue

            rect = pygame.Rect(card_x, card_y, card_w, 48)

            # Highlight selection
            if i == self.idx:
                pygame.draw.rect(screen, CARD, rect, border_radius=10)
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            else:
                pygame.draw.rect(screen, CARD, rect, border_radius=10)

            # Show resolution label
            text_surf = FONT.render(label, True, FG)
            screen.blit(text_surf, (rect.x + 14, rect.y + 8))


def push_screen(s: BaseScreen):
    SCREENS.append(s)

def pop_screen():
    if SCREENS:
        SCREENS.pop()


def main():
    push_screen(MenuScreen(t("main_title"), TOP_LEVEL))

    # Check for controller mapping before showing changelog
    if not _apply_saved_button_map_if_any():
        try:
            _auto = os.environ.get("BUA_AUTOMAP_ON_FIRST_RUN", "1").strip() in ("1","true","yes")
            if pygame.joystick.get_count() > 0 and _auto:
                run_manual_button_mapper()
        except Exception:
            pass

    # Show changelog if there's new content
    if should_show_changelog():
        push_screen(ChangelogDialog())

    while True:
        events = pygame.event.get()
        # Handle window resize for windowed mode
        # React to device add/remove and resizing
        global PAD_STYLE, JOYS, LAST_JOY_COUNT
        curr_count = pygame.joystick.get_count()
        if curr_count != LAST_JOY_COUNT:
            # Rebuild joystick handles
            JOYS = [pygame.joystick.Joystick(i) for i in range(curr_count)]
            for j in JOYS:
                try:
                    j.init()
                except Exception:
                    pass
            LAST_JOY_COUNT = curr_count
            PAD_STYLE = detect_pad_style()
            update_button_mapping()

        open_settings = False
        for ev in events:
            if ev.type == pygame.VIDEORESIZE and os.environ.get("BUA_WINDOWED"):
                handle_resize(ev.w, ev.h)
            # Pygame 2 joy hotplug events
            if ev.type in (getattr(pygame, 'JOYDEVICEADDED', None), getattr(pygame, 'JOYDEVICEREMOVED', None)):
                PAD_STYLE = detect_pad_style()
                update_button_mapping()
                # If a controller was just added and no mapping exists, prompt user to map it
                if ev.type == getattr(pygame, 'JOYDEVICEADDED', None):
                    if pygame.joystick.get_count() > 0 and not _load_saved_button_map():
                        # Check if auto-mapping is enabled (default yes)
                        _auto = os.environ.get("BUA_AUTOMAP_ON_FIRST_RUN", "1").strip() in ("1","true","yes")
                        if _auto:
                            try:
                                ok = run_manual_button_mapper()
                                if ok:
                                    msg = [t("controller_mapped") if hasattr(t, '__call__') else "Controller mapped successfully!"]
                                    push_screen(InfoDialog(t("settings_title") if hasattr(t, '__call__') else "Settings", msg))
                            except Exception:
                                pass
            # Global: Back opens Settings
            if ev.type == pygame.JOYBUTTONDOWN:
                try:
                    if ev.button == BTN_BACK:
                        open_settings = True
                except Exception:
                    pass
            # Keyboard AltGr (Right Alt) acts as Back -> open Settings
            if ev.type == pygame.KEYDOWN:
                try:
                    if ev.key == pygame.K_RALT:
                        open_settings = True
                except Exception:
                    pass
        # If requested, open Settings and consume the Back event for this frame
        if open_settings:
            try:
                top = SCREENS[-1] if SCREENS else None
                if not isinstance(top, (SettingsScreen, ControllerLayoutScreen)):
                    push_screen(SettingsScreen())
                # Filter out Back button events so Settings doesn't immediately close
                events = [e for e in events if not (
                    (getattr(e, 'type', None) == pygame.JOYBUTTONDOWN and getattr(e, 'button', None) == BTN_BACK)
                    or (getattr(e, 'type', None) == pygame.KEYDOWN and getattr(e, 'key', None) == pygame.K_RALT)
                )]
            except Exception:
                pass
        if not SCREENS:
            break
        curr = SCREENS[-1]
        curr.handle(events)
        curr.update()
        curr.draw()
        # Persistent hints overlay across all screens
        draw_persistent_hints(screen)
        pygame.display.flip()
        clock.tick(60)


def play_splash_and_load():
    """Play splash video while loading assets and translations in background."""
    import tempfile

    # Start background loading immediately
    loading_complete = threading.Event()

    def load_in_background():
        """Load translations and assets in background."""
        try:
            # Load translations
            load_language()
            # Load cards per page preference
            load_saved_cards_per_page()
            # Load assets (images, icons)
            init_assets()
        except Exception as e:
            print(f"[BUA] Error loading assets: {e}")
        finally:
            loading_complete.set()

    print("[BUA] Loading assets in background...")
    loader_thread = threading.Thread(target=load_in_background, daemon=True)
    loader_thread.start()

    # Download and play splash video while loading
    splash_url = "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/extra/splash.mp4"
    splash_file = None

    try:
        # Check if cached splash exists
        if os.path.exists(SPLASH_CACHE_FILE):
            print("[BUA] Using cached splash video")
            splash_file = SPLASH_CACHE_FILE
        else:
            # Download splash with retry logic
            print("[BUA] Downloading splash video...")
            splash_data = fetch_url_with_retry(
                splash_url,
                headers={"User-Agent": "BUA-Splash"},
                timeout=5,
                retries=2
            )

            # Save to cache
            try:
                os.makedirs(os.path.dirname(SPLASH_CACHE_FILE), exist_ok=True)
                with open(SPLASH_CACHE_FILE, 'wb') as f:
                    f.write(splash_data)
                splash_file = SPLASH_CACHE_FILE
                print(f"[BUA] Splash video cached to {SPLASH_CACHE_FILE}")
            except Exception as e:
                # If caching fails, use temp file
                print(f"[BUA] Could not cache splash: {e}, using temp file")
                with tempfile.NamedTemporaryFile(suffix=".mp4", delete=False) as f:
                    f.write(splash_data)
                    splash_file = f.name

        if splash_file:
            print(f"[BUA] Playing splash video...")

        # Play video in the pygame window using cv2
        try:
            import cv2

            video = cv2.VideoCapture(splash_file)
            fps = video.get(cv2.CAP_PROP_FPS) or 30
            frame_delay = 1.0 / fps

            global screen
            video_running = True
            last_frame_time = 0

            while video_running and not loading_complete.is_set():
                current_time = pygame.time.get_ticks() / 1000.0

                # Only read next frame if enough time has passed
                if current_time - last_frame_time >= frame_delay:
                    ret, frame = video.read()

                    if not ret:
                        # Loop video
                        video.set(cv2.CAP_PROP_POS_FRAMES, 0)
                        continue

                    # Convert BGR to RGB
                    frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

                    # Scale frame to screen size
                    frame = cv2.resize(frame, (screen.get_width(), screen.get_height()))

                    # Transpose for pygame
                    frame = frame.swapaxes(0, 1)

                    # Convert to pygame surface and display
                    frame_surface = pygame.surfarray.make_surface(frame)

                    # Center the frame on screen
                    x = (screen.get_width() - frame_surface.get_width()) // 2
                    y = (screen.get_height() - frame_surface.get_height()) // 2

                    # Display frame centered
                    screen.fill((0, 0, 0))  # Clear screen with black
                    screen.blit(frame_surface, (x, y))
                    pygame.display.flip()

                    last_frame_time = current_time

                # Handle events to prevent freezing
                for event in pygame.event.get():
                    if event.type == pygame.QUIT:
                        video_running = False

                pygame.time.Clock().tick(60)

            video.release()

        except (ImportError, Exception) as e:
            print(f"[BUA] Could not play video with cv2: {e}, showing loading screen instead")
            # Show a simple loading screen if ffplay not available (e.g., on Windows)
            # Use existing screen instead of creating new unsafe fullscreen mode
            splash_screen = screen
            splash_screen.fill((20, 24, 31))

            # Show loading text
            font = pygame.font.Font(None, 72)
            text = font.render("Loading...", True, (235, 242, 247))
            text_rect = text.get_rect(center=(splash_screen.get_width() // 2, splash_screen.get_height() // 2))
            splash_screen.blit(text, text_rect)
            pygame.display.flip()

            loading_complete.wait()

        # Clean up temp file only (not cached file)
        if splash_file and splash_file != SPLASH_CACHE_FILE:
            try:
                os.unlink(splash_file)
            except:
                pass

    except Exception as e:
        print(f"[BUA] Could not download/play splash video: {e}")
        print(f"[BUA] Showing loading screen fallback")
        # Show a simple loading screen as fallback
        try:
            splash_screen = screen
            splash_screen.fill((20, 24, 31))
            font = pygame.font.Font(None, 72)
            text = font.render("Loading...", True, (235, 242, 247))
            text_rect = text.get_rect(center=(splash_screen.get_width() // 2, splash_screen.get_height() // 2))
            splash_screen.blit(text, text_rect)
            pygame.display.flip()
        except:
            pass
        # Just wait for loading without video
        loading_complete.wait()

    # Wait for loading to complete if not already done
    loading_complete.wait()

    # Initialize TOP_LEVEL now that translations are loaded
    global TOP_LEVEL
    TOP_LEVEL = get_top_level()

    # Set window caption now that translations are loaded
    pygame.display.set_caption(t('main_title'))

    print("[BUA] Ready!")

def setup_custom_service_handler():
    """Check if custom_service_handler exists, download if missing, and enable it."""
    SERVICE_FILE = "/userdata/system/services/custom_service_handler"
    SERVICE_URL = "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/custom_service_handler"

    try:
        # Check if service file already exists
        if os.path.exists(SERVICE_FILE):
            print("[BUA] custom_service_handler already exists")
            return

        print("[BUA] Downloading custom_service_handler...")

        # Ensure services directory exists
        os.makedirs("/userdata/system/services", exist_ok=True)

        # Download the service file
        req = urllib.request.Request(SERVICE_URL, headers={"User-Agent": "BUA-Installer"})
        with urllib.request.urlopen(req, timeout=10) as response:
            service_content = response.read()

        # Write service file
        with open(SERVICE_FILE, 'wb') as f:
            f.write(service_content)

        # Make it executable
        os.chmod(SERVICE_FILE, 0o755)

        print("[BUA] custom_service_handler downloaded successfully")

        # Enable and start the service
        subprocess.run(["batocera-services", "enable", "custom_service_handler"],
                      check=False, timeout=10, capture_output=True)
        subprocess.run(["batocera-services", "start", "custom_service_handler"],
                      check=False, timeout=10, capture_output=True)

        print("[BUA] custom_service_handler enabled and started")

    except Exception as e:
        print(f"[BUA] Could not setup custom_service_handler: {e}")

def live_update():
    symlink_manager_path = "/userdata/system/services/symlink_manager"
    update_tag = "# Updated 11/12/25"

    # If script exists and contains the update tag, nothing to do
    if os.path.exists(symlink_manager_path):
        try:
            with open(symlink_manager_path, "r", encoding="utf-8") as f:
                contents = f.read()
            if update_tag in contents:
                return
        except Exception as e:
            print(f"[BUA] Could not read symlink_manager for update check: {e}")

    # Live-update / reinstall BUA silently
    try:
        subprocess.run(
            ["bash", "-lc", "curl -L install.batoaddons.app | bash"],
            check=False
        )
    except Exception as e:
        print(f"[BUA] Failed to reinstall BUA from install.batoaddons.app: {e}")

    # Ensure usercustomize.py is present (BUA Python hook for add-on generators)
    usercustomize_path = f"/userdata/system/.local/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages/usercustomize.py"
    if not os.path.exists(usercustomize_path):
        try:
            os.makedirs(os.path.dirname(usercustomize_path), exist_ok=True)
            subprocess.run(
                ["curl", "-fLs", "-o", usercustomize_path,
                 "https://raw.githubusercontent.com/batocera-unofficial-addons/batocera-unofficial-addons/main/app/usercustomize.py"],
                check=False
            )
        except Exception as e:
            print(f"[BUA] Failed to install usercustomize.py: {e}")
def check_symlink_manager_and_warn():
    symlink_manager_path = "/userdata/system/services/symlink_manager"

    # If symlink_manager is present, nothing to do
    if os.path.exists(symlink_manager_path):
        return

    # Re-run the BUA installer (non-fatal if it fails)
    try:
        subprocess.run(
            ["bash", "-lc", "curl -L install.batoaddons.app | bash"],
            check=False
        )
    except Exception as e:
        print(f"[BUA] Failed to reinstall BUA from install.batoaddons.app: {e}")

    # Simple BUA-style modal message using pygame
    title = "Reinstallation Required"
    body_lines = [
        "You've run the RGS install script since installing BUA!",
        "",
        "BUA has reinstalled, but previous application installs",
        "will need to be installed again.",
        "",
    ]

    # Blocking loop until user acknowledges
    clock = pygame.time.Clock()
    acknowledged = False

    while not acknowledged:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                clean_exit(0)

            if event.type == pygame.KEYDOWN:
                if event.key in (
                    pygame.K_RETURN,
                    pygame.K_KP_ENTER,
                    pygame.K_SPACE,
                    pygame.K_ESCAPE,
                ):
                    acknowledged = True

            if event.type == pygame.JOYBUTTONDOWN:
                if event.button in (BTN_A, BTN_B, BTN_START):
                    acknowledged = True

        # Draw background + centered card
        draw_background(screen)

        cx, cy = W // 2, H // 2
        box_w = min(S(800), W - S(80))
        box_h = S(280)
        rect = pygame.Rect(cx - box_w // 2, cy - box_h // 2, box_w, box_h)

        pygame.draw.rect(screen, CARD, rect, border_radius=16)
        pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=16)

        # Title
        draw_text(
            screen,
            title,
            FONT,
            FG,
            (rect.x + S(20), rect.y + S(20)),
        )

        # Body text
        y = rect.y + S(70)
        for line in body_lines:
            draw_text(
                screen,
                line,
                FONT_SMALL,
                FG if line else MUTED,
                (rect.x + S(20), y),
            )
            y += S(26)

        pygame.display.flip()
        clock.tick(60)


def repair_optional_integrations():
    """Reapply optional BUA integration patches without blocking startup."""
    patchers = [
        "/userdata/system/add-ons/bua/updater/integrations/apply_switch_nextendo.py",
    ]

    for patcher in patchers:
        if not os.path.isfile(patcher):
            continue

        try:
            result = subprocess.run(
                [sys.executable, patcher],
                check=False,
                timeout=15,
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                print(f"[BUA] Integration repair OK: {os.path.basename(patcher)}")
            else:
                print(
                    f"[BUA] Integration repair returned "
                    f"{result.returncode}: {os.path.basename(patcher)}"
                )

        except Exception as e:
            print(
                f"[BUA] Optional integration repair failed "
                f"for {os.path.basename(patcher)}: {e}"
            )


if __name__ == "__main__":
    try:
        # Run live update block before anything else
        live_update_block()

        # Reapply optional BUA integrations that upstream app updates
        # or reinstalls may have replaced.
        repair_optional_integrations()

        play_splash_and_load()
        main()
    except KeyboardInterrupt:
        pass
    finally:
        # Check if killall emulationstation was deferred during installation
        # If so, run it now instead of just refreshing
        try:
            import subprocess
            import os

            if os.path.exists("/tmp/bua_killall_es_deferred"):
                print("[BUA] Running deferred killall for EmulationStation...")
                subprocess.run(["killall", "-9", "emulationstation"],
                             check=False, timeout=10, capture_output=True)
                # Clean up the flag file
                try:
                    os.remove("/tmp/bua_killall_es_deferred")
                except:
                    pass
            else:
                # Just refresh EmulationStation gamelist
                print("[BUA] Refreshing EmulationStation gamelists...")
                subprocess.run(["curl", "http://127.0.0.1:1234/reloadgames"],
                             check=False, timeout=10, capture_output=True)
        except Exception as e:
            print(f"[BUA] Could not refresh ES: {e}")


