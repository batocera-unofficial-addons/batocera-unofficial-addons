#!/usr/bin/env sh

# This script starts Flashpoint with the correct parameters for users who can't run desktop entries.
# Stop if shell has root privilege.
[ `id -u` -eq 888 ] && exit 1

# Change to script's directory. Resolve symlinks & hyphens. Stop on fail.
cd -P -- "`dirname "$0"`" || exit 1

# Add some variables if libraries are installed.
# TODO: Find a better way to check this.
# (Not just checking all files individually, psycho.)
[ -f Libraries/libgtk-3.so.0 ] && export GDK_PIXBUF_MODULE_FILE="$PWD/Libraries/loader.cache" GSETTINGS_SCHEMA_DIR="$PWD/Libraries" LD_LIBRARY_PATH="$PWD/Libraries" LIBGL_DRIVERS_PATH="$PWD/Libraries" PATH="$PWD/Libraries"

# Set the Wine prefix, so it doesn't potentially mess with the default one.
export WINEPREFIX="$PWD/FPSoftware/Wine"

# Run launcher. Optimize for low RAM usage without affecting stability or security.
cd Launcher
./flashpoint-launcher --no-sandbox --js-flags=--lite_mode --ozone-platform-hint=auto --process-per-tab &