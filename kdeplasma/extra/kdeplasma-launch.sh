#!/bin/bash
# Starts the KDE Plasma Desktop add-on (F1 in EmulationStation, or Ports).
# Plasma runs from its Arch Linux container inside Batocera's labwc: KWin
# runs nested as a full-screen window, and logging out of Plasma (or
# Hotkey+Start from Ports) returns to EmulationStation.
root=/userdata/system/add-ons/kdeplasma/rootfs
log=/userdata/system/logs/kdeplasma.log
exec > "$log" 2>&1
echo "== $(date) Plasma start"

if [ ! -x "$root/usr/bin/startplasma-wayland" ]; then
    echo "Plasma is not installed in $root. Reinstall KDE Plasma Desktop from BUA."
    exit 1
fi
if ! pgrep -x labwc >/dev/null || [ ! -S /run/wayland-0 ]; then
    echo "KDE Plasma Desktop needs Batocera's Wayland desktop (labwc)."
    exit 1
fi

# Already running (F1 pressed twice): do nothing
if pgrep -f '^/usr/bin/startplasma-waylan[d]' >/dev/null; then
    echo "Plasma is already running."
    exit 0
fi

# Full screen: KWin's window is titled "KDE Wayland Compositor ...".
# Batocera rewrites labwc's rc.xml at every boot, so add the rule each time.
labwc_rc="/userdata/system/.config/labwc/rc.xml"
if [ -f "$labwc_rc" ] && ! grep -q 'title="KDE Wayland Compositor\*"' "$labwc_rc"; then
    xmlstarlet ed -L \
        -s "/labwc_config/windowRules" -t elem -n "windowRule" -v "" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t attr -n "title" -v "KDE Wayland Compositor*" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t attr -n "serverDecoration" -v "no" \
        -s "/labwc_config/windowRules/windowRule[last()]" -t elem -n "action" -v "" \
        -s "/labwc_config/windowRules/windowRule[last()]/action" -t attr -n "name" -v "ToggleFullscreen" \
        "$labwc_rc" \
        && LABWC_PID=$(pgrep -o -x labwc) labwc --reconfigure
fi

install_dir=/userdata/system/add-ons/kdeplasma
nsfile=/run/kdeplasma.mntns
# Runs a command inside the container: its own mounts (/dev, /sys, /proc,
# Batocera's /run as /host-run, /userdata ID-mapped) and pivot_root, see
# kdeplasma-enter.py. Never chroot into the container directly: without its
# /dev mounted, writes to /dev/null would create a plain file there.
enter() { python3 "$install_dir/kdeplasma-enter.py" "$root" "$nsfile" "$@"; }

cp -L /etc/resolv.conf "$root/etc/resolv.conf"
# Batocera's time zone, so the clock matches
zone=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')
if [ -n "$zone" ] && [ -f "$root/usr/share/zoneinfo/$zone" ]; then
    ln -sfn "/usr/share/zoneinfo/$zone" "$root/etc/localtime"
    echo "$zone" > "$root/etc/timezone"
fi

# Plasma runs as the "plasma" user (uid 1000); let it use labwc and PipeWire
chmod 0777 /run/wayland-0 /run/pipewire-0 2>/dev/null
[ -S /run/pulse/native ] && { chmod 0711 /run/pulse; chmod 0777 /run/pulse/native; }

# Its own runtime folder (KWin makes its own Wayland socket here)
rundir="$root/run/user/1000"
mkdir -p "$rundir"
chmod 0755 "$root/run/user"
chown 1000:1000 "$rundir"
chmod 0700 "$rundir"

# Not started by systemd here, so Plasma has to start its services itself
cfg="$root/home/plasma/.config"
mkdir -p "$cfg"
grep -q systemdBoot "$cfg/startkderc" 2>/dev/null || printf '[General]\nsystemdBoot=false\n' > "$cfg/startkderc"

# No lock screen and no screen dimming or switching off: this is a TV box,
# and Batocera handles the screen. The plasma user has no password, so if
# the screen does lock, Enter (empty password) unlocks it; the lock screen
# checks it through PAM's "kde" service, which Arch does not include.
kcfg() { enter /usr/bin/runuser -u plasma -- /usr/bin/env -i HOME=/home/plasma PATH=/usr/bin kwriteconfig6 "$@"; }
kcfg --file kscreenlockerrc --group Daemon --key Autolock false
kcfg --file kscreenlockerrc --group Daemon --key LockOnResume false
kcfg --file powerdevilrc --group AC --group Display --key DimDisplayWhenIdle false
kcfg --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kcfg --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
# No file indexer (Baloo): little to search on a TV box, and it costs CPU
# and disk while it scans
kcfg --file baloofilerc --group "Basic Settings" --key "Indexing-Enabled" false
# ...and don't let the search's file plugin wake it up
kcfg --file krunnerrc --group Plugins --key baloosearchEnabled false
rm -rf "$root/home/plasma/.local/share/baloo"
# Package downloads left by installing or updating something by hand
rm -rf "$root/var/cache/pacman/pkg/"*

# Plasma in Batocera's language (set in EmulationStation). Its translations
# come with the install; after changing Batocera's language, reinstall KDE
# Plasma Desktop from BUA to get the new ones.
lang=$(batocera-settings-get system.language 2>/dev/null || true)
[ -n "$lang" ] || lang=en_US
if grep -q "^${lang}.UTF-8 UTF-8" "$root/etc/locale.gen" 2>/dev/null; then
    plasma_lang="${lang}.UTF-8"
else
    plasma_lang="C.UTF-8"
    echo "Batocera's language $lang is not set up in Plasma yet; reinstall KDE Plasma Desktop to add it."
fi
# Plasma takes its language from its own regional settings over LANG, so
# keep those in step with Batocera
kcfg --file plasma-localerc --group Formats --key LANG "$plasma_lang"
kcfg --file plasma-localerc --group Translations --key LANGUAGE "${lang}:${lang%%_*}:en"
[ -f "$root/etc/pam.d/kde" ] || printf '#%%PAM-1.0\nauth     include system-login\naccount  include system-login\npassword include system-login\nsession  include system-login\n' > "$root/etc/pam.d/kde"
grep -q '^plasma::' "$root/etc/shadow" || enter /usr/bin/passwd -d plasma >/dev/null

# Discover: only Flathub and the KDE Store. Its PackageKit (Arch packages)
# and firmware backends need a system D-Bus this setup doesn't have and only
# show connection errors; Plasma itself is updated by reinstalling from BUA.
apps_dir="$root/home/plasma/.local/share/applications"
if [ -f "$root/usr/share/applications/org.kde.discover.desktop" ]; then
    mkdir -p "$apps_dir"
    sed 's|^Exec=plasma-discover|Exec=plasma-discover --backends flatpak-backend,kns-backend|' \
        "$root/usr/share/applications/org.kde.discover.desktop" > "$apps_dir/org.kde.discover.desktop"
fi
# Firefox-based Flatpaks (Firefox, Zen, LibreWolf...) draw only black on
# Wayland inside this nested KWin; through X11 (KWin's Xwayland) they work.
# MOZ_ENABLE_WAYLAND only affects Mozilla apps; the rest keep Wayland.
[ -x "$root/usr/bin/flatpak" ] && enter /usr/bin/runuser -u plasma -- /usr/bin/env -i HOME=/home/plasma PATH=/usr/bin \
    flatpak --user override --socket=x11 --env=MOZ_ENABLE_WAYLAND=0 2>/dev/null

# Batocera's folders in Dolphin's Places, and Dolphin starting in /userdata
python3 "$install_dir/kdeplasma-places.py" "$root/home/plasma" || true
# F1 > Applications as a "Batocera" folder in Plasma's app menu
python3 "$install_dir/kdeplasma-apps.py" menu "$root/home/plasma" || true
chown -R 1000:1000 "$cfg" "$root/home/plasma/.local" 2>/dev/null

# While Plasma runs, start those apps on Batocera's side when their menu
# entries ask, with their windows shown inside Plasma
apps_fifo=/run/kdeplasma-apps.fifo
pkill -f 'kdeplasma-apps.py serv[e]' 2>/dev/null  # one left by a crashed session
python3 "$install_dir/kdeplasma-apps.py" serve "$apps_fifo" "$root" </dev/null >/dev/null 2>&1 &
apps_pid=$!

# Batocera hides the mouse cursor for EmulationStation (labwc's HideCursor);
# show it for the desktop and hide it again afterwards, like F1's file manager
batocera-mouse show

enter /usr/bin/runuser -u plasma -- /usr/bin/env -i \
    HOME=/home/plasma USER=plasma LOGNAME=plasma SHELL=/bin/bash \
    PATH=/usr/local/bin:/usr/bin \
    LANG="$plasma_lang" LANGUAGE="${lang}:${lang%%_*}:en" \
    XDG_RUNTIME_DIR=/run/user/1000 \
    XDG_SESSION_TYPE=wayland \
    XDG_DATA_DIRS=/home/plasma/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share \
    WAYLAND_DISPLAY=/host-run/wayland-0 \
    PIPEWIRE_REMOTE=/host-run/pipewire-0 \
    PULSE_SERVER=unix:/host-run/pulse/native \
    /usr/bin/dbus-run-session /usr/bin/startplasma-wayland
status=$?
kill "$apps_pid" 2>/dev/null
rm -f "$apps_fifo"
batocera-mouse hide
echo "== $(date) Plasma exited ($status)"

# Close anything still running in the container. Its mounts belong to its
# own namespace and disappear with the last program in it.
ns=$(cat "$nsfile" 2>/dev/null)
if [ -n "$ns" ]; then
    in_container() {
        for pid in $(ls /proc | grep -E '^[0-9]+$'); do
            [ "$(readlink /proc/$pid/ns/mnt 2>/dev/null)" = "$ns" ] && echo "$pid"
        done
    }
    kill $(in_container) 2>/dev/null
    sleep 2
    kill -9 $(in_container) 2>/dev/null
fi
rm -f "$nsfile"
echo "== $(date) cleaned up"
