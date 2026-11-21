#!/bin/bash
# Proof of concept: run KDE Plasma from the Arch container inside Batocera's
# labwc. KWin runs nested as a full-screen window; logging out of Plasma
# returns to EmulationStation.
root=/userdata/system/add-ons/plasma/rootfs
log=/userdata/system/logs/plasma.log
exec > "$log" 2>&1
echo "== $(date) Plasma start"

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

mounted() { awk -v m="$1" '$2==m {f=1} END {exit !f}' /proc/mounts; }
# The container bound onto itself first (pacman and chroot tools expect a
# real mount at /), then everything else on top of it
mounted "$root" || mount --bind "$root" "$root"
bind() { mounted "$2" || { mkdir -p "$2"; mount --rbind "$1" "$2"; mount --make-rslave "$2"; }; }
bind /dev "$root/dev"
bind /sys "$root/sys"
mounted "$root/proc" || mount -t proc proc "$root/proc"
# Batocera's /run holds the labwc (Wayland) and PipeWire sockets
bind /run "$root/host-run"
# Your files (a plain bind: the container itself lives inside /userdata)
mounted "$root/userdata" || { mkdir -p "$root/userdata"; mount --bind /userdata "$root/userdata"; }
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
chown -R 1000:1000 "$cfg"

# Batocera hides the mouse cursor for EmulationStation (labwc's HideCursor);
# show it for the desktop and hide it again afterwards, like F1's file manager
batocera-mouse show

chroot "$root" /usr/bin/runuser -u plasma -- /usr/bin/env -i \
    HOME=/home/plasma USER=plasma LOGNAME=plasma SHELL=/bin/bash \
    PATH=/usr/local/bin:/usr/bin \
    LANG=C.UTF-8 \
    XDG_RUNTIME_DIR=/run/user/1000 \
    XDG_SESSION_TYPE=wayland \
    WAYLAND_DISPLAY=/host-run/wayland-0 \
    PIPEWIRE_REMOTE=/host-run/pipewire-0 \
    PULSE_SERVER=unix:/host-run/pulse/native \
    /usr/bin/dbus-run-session /usr/bin/startplasma-wayland
status=$?
batocera-mouse hide
echo "== $(date) Plasma exited ($status)"

# Close anything still running in the container, then unmount it
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
    [ "$(readlink /proc/$pid/root 2>/dev/null)" = "$root" ] && kill "$pid" 2>/dev/null
done
sleep 2
for pid in $(ls /proc | grep -E '^[0-9]+$'); do
    [ "$(readlink /proc/$pid/root 2>/dev/null)" = "$root" ] && kill -9 "$pid" 2>/dev/null
done
for _ in 1 2 3 4 5; do
    mounts=$(awk -v r="$root" 'index($2, r)==1 {print $2}' /proc/mounts | sort -r)
    [ -z "$mounts" ] && break
    for m in $mounts; do umount -l "$m" 2>/dev/null; done
done
echo "== $(date) cleaned up"
