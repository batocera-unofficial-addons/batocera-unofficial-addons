#!/bin/bash
# BUA Doctor: finds and fixes what breaks in BUA add-ons (F1 desktops,
# services, emulators set up for another Batocera version, leftovers of
# removed add-ons). It is on the BUA menu's main screen (next to the Updater):
# run it whenever something seems off, or after a Batocera update. It is not
# an add-on, so there is nothing to uninstall; what it keeps is
# /userdata/system/add-ons/bua-doctor (the last downloaded checks), its log,
# and the backups of files it changed.
#
# Each run downloads the latest checks, so new problems are found without
# reinstalling. Nothing is changed without asking, and every file it changes
# or removes is backed up to /userdata/system/backups/bua-doctor/.

APPNAME="BUA Doctor"
install_dir="/userdata/system/add-ons/bua-doctor"
tool="$install_dir/bua_doctor.py"
url="https://github.com/batocera-unofficial-addons/batocera-unofficial-addons/raw/main/bua-doctor/extra/bua_doctor.py"

fail() {
    dialog --title "$APPNAME" --msgbox "$1" 8 60
    exit 1
}

[ "$(id -u)" -eq 0 ] || fail "$APPNAME must run as root."
command -v python3 >/dev/null || fail "$APPNAME needs python3, which this Batocera does not have."

mkdir -p "$install_dir"
if curl -fsSL --max-time 30 -o "$tool.new" "$url" && python3 -m py_compile "$tool.new" 2>/dev/null; then
    mv -f "$tool.new" "$tool"
else
    rm -f "$tool.new"
    # Offline: use the copy from the last run, if there is one
    [ -f "$tool" ] || fail "Could not download $APPNAME. Check the network and try again."
fi
rm -rf "$install_dir/__pycache__"

python3 "$tool" "$@"
