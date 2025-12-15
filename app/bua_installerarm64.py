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
from datetime import datetime, timezone
from urllib.parse import urlparse
import urllib.request
import urllib.parse
import time
from typing import Dict, List, Tuple
import hashlib

# ------------------------------
# Changelog
# ------------------------------
# Edit this section to add changelog entries. Leave empty to disable.
# This will be shown once to users when they first launch after an update.

CHANGELOG = """
- Persistent Selection Queue
App selections now persist across category navigation! You can now select apps from multiple categories and process them all in one queue.

- Resolution Settings
Runs with no resolution change by default. If a change is needed, this can be done in the resolution settings.

- Improved Update System
Faster and more reliable update checking.

- New Apps
Added RunImage Desktop, NZP, RGSX, and Raspberry Pi Imager.

- Brought ARM64 menu in line with x86_64 version.
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
        # Example: Setup custom_service_handler
        setup_custom_service_handler()

        # Add more live update tasks here as needed
        # Example:
        # fix_legacy_configs()
        # update_system_files()

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

def get_uninstall_command(install_cmd: str) -> str:
    """Convert an installation command to an uninstall command.
    Replaces .sh with _uninstall.sh in the URL.

    Example:
    https://.../ 7zip/7zip.sh -> https://.../7zip/7zip_uninstall.sh
    """
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

APPS: Dict[str, str] = {
    "Amazon Luna": bua("amazonluna/amazonluna-arm64.sh"),
    "Celeste 64": bua("celeste64/celeste64.sh"),
    "Chiaki": bua("chiaki/chiaki.sh"),
    "Conty": bua("conty/conty.sh"),
    "Sunshine": bua("sunshine/sunshine-arm64.sh"),
    "Dark Mode": bua("dark/dark.sh"),
    "Desktop (Docker)": bua("desktop/desktop.sh"),
    "VClean": bua("vclean/vclean.sh"),
    "Docker": bua("docker/docker.sh"),
    "RunImage Desktop": bua("desktop/ri-desktop.sh"),
    "F1": bua("f1/f1.sh"),
    "Firefox": bua("firefox/firefox-arm64.sh"),
    "FreeTube": bua("freetube/freetube.sh"),
    "Greenlight": bua("greenlight/greenlight_arm64.sh"),
    "IPTV Nator": bua("iptvnator/iptvnator.sh"),
    "Minecraft": bua("minecraft/bedrock.sh"),
    "Nazi Zombies Portable": bua("nzp/nzp.sh"),
    "PortMaster": bua("portmaster/portmaster.sh"),
    "Raspberry Pi Imager": bua("rpi/rpi.sh"),
    "RGSX": "curl -L bit.ly/rgsx-install | sh",
    "Soar": bua("soar/soar.sh"),
    "Super Mario X": bua("supermariox/supermariox.sh"),
    "SuperTuxKart": bua("supertuxkart/supertuxkart.sh"),
    "Tailscale": bua("tailscale/tailscale.sh"),
    "Telegraf": bua("telegraf/telegraf.sh"),
    "Vesktop": bua("vesktop/vesktop.sh"),
    "WayVNC": bua("wayvnc/wayvnc.sh"),
    "WayVNC Headless": bua("wayvnc_headless/wayvnc_headless.sh"),
}

# --- Integrated Docker app installers ---
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
    "Amazon Luna": "Amazon Luna game streaming client.",
    "Celeste 64": "Free 3D platformer (requires OpenGL 3.2)",
    "Chiaki": "PS4/PS5 Remote Play client.",
    "Conty": "Standalone Linux distro container.",
    "Sunshine": "Self-hosted game streaming server (host for Moonlight).",
    "Dark Mode": "Toggle F1 dark mode",
    "Desktop (Docker)": "Desktop mode, requires Docker",
    "VClean": "Service to clean the Batocera version string (removes extra flags)",
    "Docker": "Docker/Podman/Portainer AIO.",
    "RunImage Desktop": "RunImage-based desktop with overlay support",
    "F1": "Ports shortcut to file manager",
    "Firefox": "Mozilla Firefox browser.",
    "FreeTube": "Privacy-minded YouTube client",
    "Greenlight": "Client for xCloud and Xbox streaming.",
    "IPTV Nator": "IPTV client for watching live TV.",
    "Minecraft": "Minecraft: Bedrock Edition.",
    "Nazi Zombies Portable": "Classic Nazi Zombies on modern platforms",
    "PortMaster": "Download and manage games on handhelds.",
    "Raspberry Pi Imager": "Flash OS images to USB and SD cards.",
    "RGSX": "Retro Game Sets Xtra. A free, user-friendly ROM downloader for Batocera",
    "Soar": "Soar package manager (integrated with BUA)",
    "Super Mario X": "Fan-made Super Mario tribute",
    "SuperTuxKart": "Free and open-source kart racer.",
    "Tailscale": "VPN service for secure Batocera connections.",
    "Telegraf": "Server agent for collecting and reporting metrics.",
    "Vesktop": "Discord client for Batocera.",
    "WayVNC": "WayVNC for remote access",
    "WayVNC Headless": "WayVNC for headless systems",
    "CasaOS": "Simple home server UI and app store",
    "UmbrelOS": "Self-hosted OS with app marketplace",
    "Arch KDE (Webtop)": "Arch Linux desktop in browser (noVNC)",
    "Ubuntu MATE (Webtop)": "Ubuntu MATE desktop in browser (noVNC)",
    "Alpine XFCE (Webtop)": "Alpine XFCE desktop in browser (noVNC)",
    "Jellyfin": "Open-source media server",
    "Emby": "Media server and streaming",
    "Arr-In-One": "All-in-one media management stack",
    "Arr-In-One Downloaders": "Downloaders companion stack",
}


CATEGORIES: Dict[str, List[str]] = {
    "Games": [
        "Minecraft", "Super Mario X", "SuperTuxKart", "Celeste 64", "Nazi Zombies Portable"
    ],
    "Game Utilities": [
        "PortMaster", "Chiaki", "Greenlight", "Amazon Luna", "RGSX"
    ],
    "System Utilities": [
        "Tailscale", "Telegraf", "Vesktop", "IPTV Nator", "FreeTube",
        "F1", "Firefox", "Desktop (Docker)", "RunImage Desktop", "Raspberry Pi Imager"
    ],
    "Developer Tools": [
        "Conty", "Docker", "Soar", "WayVNC", "WayVNC Headless", "Dark Mode", "VClean"
    ],
    "Docker Menu": [
        "CasaOS", "UmbrelOS", "Arch KDE (Webtop)", "Ubuntu MATE (Webtop)",
        "Alpine XFCE (Webtop)", "Jellyfin", "Emby", "Arr-In-One",
        "Arr-In-One Downloaders"
    ],
}

def get_top_level() -> List[Tuple[str, str]]:
    """Generate top-level menu items with current language translations"""
    return [
        (t("games"), t("games_desc")),
        (t("game_utilities"), t("game_utilities_desc")),
        (t("system_utilities"), t("system_utilities_desc")),
        (t("developer_tools"), t("developer_tools_desc")),
        (t("docker_menu"), t("docker_menu_desc")),
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

        self.proc = subprocess.Popen(
            ["bash", "-c", full_cmd],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
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
                        # Special handling for Custom Wine - run directly instead of selecting
                        if key == "Custom Wine":
                            push_screen(RunListScreen([(key, APPS[key])], title=key))
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
                        # Special handling for Custom Wine - run directly instead of selecting
                        if key == "Custom Wine":
                            push_screen(RunListScreen([(key, APPS[key])], title=key))
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
                "function dialog(){ "
                "echo '[BUA] Dialog called with:' \"$@\" >&2; "
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
                "  echo '[BUA] Detected dtype:' \"$dtype\" 'title:' \"$title\" >&2; "
                "  echo '[BUA] Menu items:' \"$menu_items\" >&2; "
                "  local resp_file=\"/tmp/bua_dialog_$$.resp\"; rm -f \"$resp_file\"; "
                "  if command -v base64 >/dev/null 2>&1; then "
                "    t_b64=$(printf %s \"$title\" | base64 -w0 2>/dev/null || printf %s \"$title\" | base64); "
                "    m_b64=$(printf %s \"$text\" | base64 -w0 2>/dev/null || printf %s \"$text\" | base64); "
                "    i_b64=$(printf %s \"$menu_items\" | base64 -w0 2>/dev/null || printf %s \"$menu_items\" | base64); "
                "    echo '[BUA] Emitting marker with resp file:' \"$resp_file\" >&2; "
                "    echo __BUA_DIALOG__ type=$dtype title_b64=$t_b64 text_b64=$m_b64 items_b64=$i_b64 resp=$resp_file >&2; "
                "  else "
                "    echo __BUA_DIALOG__ type=$dtype title=\"$title\" text=\"$text\" items=\"$menu_items\" resp=$resp_file >&2; "
                "  fi; "
                "  if [ \"$dtype\" = \"infobox\" ]; then "
                "    echo '[BUA] Infobox - continuing immediately' >&2; "
                "    echo 0 > \"$resp_file\"; sleep 0.05; rm -f \"$resp_file\"; return 0; "
                "  fi; "
                "  while [ ! -f \"$resp_file\" ]; do sleep 0.1; done; "
                "  local result=$(cat \"$resp_file\"); rm -f \"$resp_file\"; "
                "  if [ \"$dtype\" = \"yesno\" ]; then "
                "    if [ \"$result\" = \"0\" ]; then return 0; else return 1; fi; "
                "  elif [ \"$dtype\" = \"menu\" ] || [ \"$dtype\" = \"checklist\" ]; then "
                "    if [ -n \"$result\" ]; then echo \"$result\"; return 0; else return 1; fi; "
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

        # Add debug markers to track execution
        debug_start = f"echo '[BUA] Starting installation: {name}'; "
        debug_end = "; echo '[BUA] Installation finished'"

        # Special handling for curl | bash commands - inject wrappers into the piped script
        if "curl" in cmd and "|" in cmd and "bash" in cmd:
            # Download script to temp file, prepend wrappers, then execute
            # This ensures the dialog wrapper is available to the downloaded script
            parts = cmd.split("|", 1)
            if len(parts) == 2:
                curl_part = parts[0].strip()
                wrapper_code = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}"
                cmd = (
                    f"{debug_start}"
                    f"TMPSCRIPT=$(mktemp); "
                    f"{curl_part} > \"$TMPSCRIPT\"; "
                    f"( {wrapper_code} source \"$TMPSCRIPT\" ); "
                    f"rm -f \"$TMPSCRIPT\""
                    f"{debug_end}"
                )
            else:
                cmd = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}{debug_start}{cmd}{debug_end}"
        else:
            cmd = f"{dialog_wrap}{es_wrap}{overlay_wrap}{interactive_wrap}{system_wrap}{debug_start}{cmd}{debug_end}"

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
                else:
                    # Regular install - mark as installed
                    mark_installed(job_name, success)
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
                view = self.runner.lines[-35:]
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


# Global GitHub cache that persists across UpdaterScreen instances
# This prevents "unknown API error" when re-entering the updater
GITHUB_CACHE: Dict[str, tuple] = {}  # {app: (status, needs_update, detail)}


class UpdaterScreen(BaseScreen):
    def __init__(self):
        global _SCRIPT_DATES_CACHE
        # Invalidate SCRIPT_DATES cache on each updater screen entry to get fresh data
        _SCRIPT_DATES_CACHE = None

        self.items: List[Tuple[str, str, bool, str]] = []  # (app, status_text, needs_update, detail)
        self.idx = 0
        self.selected: Dict[str, bool] = {}
        self.loading = True
        self.error: str | None = None
        self.needs_rescan = False
        self.uninstalling_app: str | None = None  # Track which app is being uninstalled
        self.runner: Runner | None = None  # Runner for inline uninstall
        threading.Thread(target=self._scan, daemon=True).start()

    def _scan(self, use_cache=False):
        try:
            # Get apps from JSON history
            json_installed = [k for k in APPS.keys() if is_installed(k)]

            # Scan directory for apps not in JSON (returns dict: app_name -> mtime)
            dir_installed_dict = scan_installed_addons_directory()

            # Combine both lists, removing duplicates
            installed_apps = list(set(json_installed + list(dir_installed_dict.keys())))
            installed_apps.sort()

            results = []
            for app in installed_apps:
                # If using cache and we have cached data for this app, reuse it
                if use_cache and app in GITHUB_CACHE:
                    status, needs, detail = GITHUB_CACHE[app]
                    results.append((app, status, needs, detail))
                    continue

                # Otherwise, fetch from GitHub API
                cmd = APPS.get(app, "")
                parsed = parse_github_raw_url(cmd)
                last_date_str = get_last_install_date(app)
                last_ts = 0.0
                is_from_directory_only = (last_date_str is None or last_date_str == "")

                if last_date_str:
                    try:
                        last_ts = datetime.strptime(last_date_str, "%Y-%m-%d %H:%M:%S").timestamp()
                    except Exception:
                        last_ts = 0.0
                if parsed:
                    owner, repo, branch, path = parsed
                    remote_ts = github_latest_commit_date(owner, repo, branch, path)
                    if remote_ts is None:
                        status = t("unknown_api_error")
                        needs = False
                        detail = f"{owner}/{repo}:{branch}/{path}"
                    else:
                        if remote_ts > last_ts + 1:  # small skew tolerance
                            status = t("update_available")
                            needs = True
                            detail = time.strftime("%Y-%m-%d %H:%M", time.gmtime(remote_ts))
                        else:
                            # Show special status for directory-only apps with their directory timestamp
                            if is_from_directory_only:
                                status = "Installed (no history)"
                                # Use directory modification time if available
                                dir_mtime = dir_installed_dict.get(app)
                                if dir_mtime:
                                    detail = time.strftime("%Y-%m-%d %H:%M", time.localtime(dir_mtime))
                                else:
                                    detail = ""
                            else:
                                status = t("up_to_date")
                                detail = time.strftime("%Y-%m-%d %H:%M", time.gmtime(remote_ts))
                            needs = False
                else:
                    status = t("unknown_source")
                    needs = False
                    detail = ""

                # Cache the result globally
                GITHUB_CACHE[app] = (status, needs, detail)
                results.append((app, status, needs, detail))

            # Sort: updates first, then by name
            results.sort(key=lambda x: (not x[2], x[0].lower()))
            self.items = results
            self.selected = {app: needs for app, _s, needs, _d in self.items if needs}
        except Exception as e:
            self.error = str(e)
        finally:
            self.loading = False

    def rescan(self, use_cache=True):
        """Trigger a rescan of installed apps (uses cache by default to avoid GitHub API calls)"""
        self.loading = True
        self.items = []
        self.idx = 0
        self.selected = {}
        self.error = None
        threading.Thread(target=lambda: self._scan(use_cache=use_cache), daemon=True).start()

    def handle(self, events):
        # Process analog stick for navigation (arcade cabinet support)
        analog_v, _analog_h = process_analog_navigation(events)
        if not self.loading and self.items:
            if analog_v == 1:  # Down
                self.idx = min(self.idx + 1, len(self.items) - 1)
            elif analog_v == -1:  # Up
                self.idx = max(self.idx - 1, 0)

        for e in events:
            if e.type == pygame.QUIT:
                clean_exit(0)
            if e.type == pygame.KEYDOWN:
                if e.key == pygame.K_ESCAPE:
                    pop_screen(); return
                if e.key in (pygame.K_DOWN,):
                    if not self.loading and self.items:
                        self.idx = min(self.idx + 1, len(self.items)-1)
                if e.key in (pygame.K_UP,):
                    if not self.loading and self.items:
                        self.idx = max(self.idx - 1, 0)
                if e.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if not self.loading and self.items:
                        app = self.items[self.idx][0]
                        needs_update = self.items[self.idx][2]
                        if needs_update:
                            # Toggle selection for apps that need updates
                            self.selected[app] = not self.selected.get(app, False)
                if e.key == pygame.K_SPACE:  # Start on keyboard
                    if not self.loading:
                        self.queue_updates()
            if e.type == pygame.JOYHATMOTION:
                _x, y = e.value
                if y == -1:
                    self.idx = min(self.idx + 1, max(0, len(self.items)-1))
                elif y == 1:
                    self.idx = max(self.idx - 1, 0)
            if e.type == pygame.JOYBUTTONDOWN:
                if e.button in (BTN_B, BTN_BACK):  # B/Back
                    pop_screen(); return
                if e.button in (BTN_A,):  # A toggle
                    if not self.loading and self.items:
                        app = self.items[self.idx][0]
                        needs_update = self.items[self.idx][2]
                        if needs_update:
                            # Toggle selection for apps that need updates
                            self.selected[app] = not self.selected.get(app, False)
                if e.button in (BTN_START,):  # Start -> queue updates
                    if not self.loading:
                        self.queue_updates()
                if e.button in (BTN_Y,):  # Y -> uninstall current app
                    if not self.loading and self.items:
                        self.uninstall_app()

    def uninstall_app(self):
        """Uninstall the currently selected app inline"""
        if self.loading or not self.items or self.uninstalling_app:
            return
        app = self.items[self.idx][0]
        cmd = APPS.get(app)
        if not cmd:
            return

        # Generate uninstall command
        uninstall_cmd = get_uninstall_command(cmd)
        if not uninstall_cmd:
            push_screen(InfoDialog(t("uninstall"), [t("uninstall_error")]))
            return

        # Start inline uninstall
        self.uninstalling_app = app
        self.runner = Runner()
        self.runner.run(uninstall_cmd)

    def queue_updates(self):
        if self.loading:
            return
        # Get all apps that are selected (either auto-selected on load or manually toggled)
        selected_apps = [app for app in self.selected if self.selected.get(app, False)]
        if not selected_apps:
            push_screen(InfoDialog(t("updater"), [t("nothing_selected_update")]))
            return
        for app in selected_apps:
            cmd = APPS.get(app)
            if cmd:
                item = (app, cmd)
                if item not in INSTALL_QUEUE:
                    INSTALL_QUEUE.append(item)
        pop_screen()  # close updater
        push_screen(QueueScreen())

    def update(self):
        """Check if we need to rescan after returning from uninstall"""
        if self.needs_rescan and not self.loading:
            self.needs_rescan = False
            self.rescan()

        # Check if inline uninstall finished
        if self.uninstalling_app and self.runner and self.runner.done:
            success = self.runner.returncode == 0
            if success:
                # Remove from history
                mark_uninstalled(self.uninstalling_app)
            self.uninstalling_app = None
            self.runner = None
            # Trigger rescan to refresh list
            self.rescan()

    def draw(self):
        draw_background(screen)
        draw_text(screen, t("updater_title"), FONT_BIG, FG, (40, 30))
        current_needs = False
        if not self.loading and self.items:
            try:
                current_needs = bool(self.items[self.idx][2])
            except Exception:
                current_needs = False
        hint_parts = []
        if current_needs:
            hint_parts.append(f"A={t('hint_toggle')}")
        hint_parts.append(f"Y={t('hint_uninstall')}")
        hint_parts.append(f"Start={t('hint_queue')}")
        hint_parts.append(f"B={t('hint_return')}")
        hint_parts.append(f"Back={t('hint_back_settings')}")
        draw_hints_line(screen, " | ".join(hint_parts), FONT_SMALL, ACCENT, (40, 70))

        if self.loading:
            draw_text(screen, t("scanning_updates"), FONT, MUTED, (40, 100))
            return
        if self.error:
            draw_text(screen, f"{t('error')}: {self.error}", FONT, (255, 120, 120), (40, 100))
            return
        if not self.items:
            draw_text(screen, t("no_installed"), FONT, MUTED, (40, 100))
            return

        base_y = 110
        item_pitch = 55
        avail_h = H - base_y - 40
        rows = min(len(self.items), get_visible_items(avail_h, item_pitch))
        top = max(0, min(self.idx - rows//2, max(0, len(self.items)-rows)))
        view = self.items[top:top+rows]

        for i, (app, status, needs, detail) in enumerate(view):
            actual = top + i
            rect = pygame.Rect(40, base_y + i*55, W - 80, 50)
            pygame.draw.rect(screen, CARD, rect, border_radius=10)
            if actual == self.idx:
                pygame.draw.rect(screen, SELECT, rect, width=3, border_radius=10)
            # checkbox only for needs==True
            box = pygame.Rect(rect.x + 14, rect.y + 12, 24, 24)
            if needs:
                pygame.draw.rect(screen, FG if self.selected.get(app, False) else MUTED, box, width=2)
                if self.selected.get(app, False):
                    pygame.draw.line(screen, FG, (box.x+4, box.centery), (box.centerx, box.bottom-5), 3)
                    pygame.draw.line(screen, FG, (box.centerx, box.bottom-5), (box.right-4, box.y+5), 3)
                name_x = box.right + 12
            else:
                name_x = rect.x + 14
            draw_text(screen, app, FONT, FG, (name_x, rect.y + 8))
            # status + detail - or show uninstall progress if uninstalling
            if self.uninstalling_app == app and self.runner:
                # Show uninstall progress
                if self.runner.done:
                    status_text = "Uninstall complete" if self.runner.returncode == 0 else "Uninstall failed"
                else:
                    status_text = "Uninstalling..."
                draw_text(screen, status_text, FONT_SMALL, ACCENT, (name_x, rect.y + 30))
            else:
                color = ACCENT if needs else MUTED
                suffix = f" — {detail}" if detail else ""
                draw_text(screen, status + suffix, FONT_SMALL, color, (name_x, rect.y + 30))


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


if __name__ == "__main__":
    try:
        # Run live update block before anything else
        live_update_block()

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

