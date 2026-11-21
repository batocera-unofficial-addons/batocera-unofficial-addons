#!/usr/bin/env python3
"""Enter the KDE Plasma Desktop container and run a command in it.

Gives the command its own set of mounts (a private mount namespace), sets
up the folders Plasma needs, then switches its root to the container with
pivot_root. Unlike chroot, this lets programs inside create user namespaces,
which Flatpak (Discover's Flathub apps) and Chromium/Electron sandboxes need.
The mounts exist only for Plasma: Batocera never sees them, and they vanish
when the last program in the container exits.

Usage: kdeplasma-enter.py <rootfs> <nsfile> <command> [args...]
<nsfile> receives the mount namespace's id, so kdeplasma-launch.sh can find
(and stop) everything still running in the container afterwards.
"""
import ctypes
import os
import re
import subprocess
import sys

root, nsfile, command = sys.argv[1], sys.argv[2], sys.argv[3:]

libc = ctypes.CDLL(None, use_errno=True)
libc.mount.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_ulong, ctypes.c_void_p]
libc.umount2.argtypes = [ctypes.c_char_p, ctypes.c_int]
MS_REC, MS_PRIVATE, MNT_DETACH = 0x4000, 0x40000, 2
SYS_pivot_root = 155  # x86_64


def check(result, what):
    if result != 0:
        err = ctypes.get_errno()
        sys.exit(f"kdeplasma-enter: {what} failed: {os.strerror(err)}")


def run(*args):
    subprocess.run(args, check=True)


# Our own mounts, not shared with Batocera
os.unshare(os.CLONE_NEWNS)
check(libc.mount(None, b"/", None, MS_REC | MS_PRIVATE, None), "making mounts private")

# The container, then the system folders on top of it. Plasma runs as a
# normal user ("plasma", uid 1000) and only gets what a desktop needs, so a
# program started in it cannot take over Batocera.
run("mount", "--bind", root, root)


def in_root(path):
    return os.path.join(root, path.lstrip("/"))


def bind(src, dst, readonly=False, recursive=False):
    """Bind src at dst inside the container; skipped if src is missing."""
    if not os.path.lexists(src):
        return
    target = in_root(dst)
    if os.path.isdir(src):
        os.makedirs(target, exist_ok=True)
    else:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        if not os.path.exists(target):
            open(target, "a").close()
    run("mount", "--rbind" if recursive else "--bind", src, target)
    if readonly:
        # Every mount below it too (sysfs has several)
        targets = [target]
        with open("/proc/self/mountinfo") as f:
            for line in f:
                mnt = line.split()[4]
                if mnt.startswith(target + "/"):
                    targets.append(mnt)
        for t in targets:
            subprocess.run(["mount", "-o", "remount,bind,ro", t], stderr=subprocess.DEVNULL)


# /dev: only the devices a desktop uses, not Batocera's disks, memory or
# consoles. A fresh folder in memory, with Batocera's devices bound into it.
dev = in_root("/dev")
os.makedirs(dev, exist_ok=True)
run("mount", "-t", "tmpfs", "-o", "mode=0755,nosuid,noexec", "kdeplasma-dev", dev)
for node in ("null", "zero", "full", "random", "urandom", "tty", "fuse", "uinput"):
    bind("/dev/" + node, "/dev/" + node)
for d in ("dri", "snd", "input"):  # GPU, sound, controllers/mouse/keyboard
    bind("/dev/" + d, "/dev/" + d)
for name in sorted(os.listdir("/dev")):  # webcams, controllers' raw HID
    if name.startswith(("video", "hidraw")):
        bind("/dev/" + name, "/dev/" + name)
# Terminals: Plasma's own, not Batocera's
os.makedirs(in_root("/dev/pts"), exist_ok=True)
run("mount", "-t", "devpts", "-o", "newinstance,ptmxmode=0666,mode=0620,gid=5,nosuid,noexec",
    "devpts", in_root("/dev/pts"))
os.symlink("pts/ptmx", in_root("/dev/ptmx"))
os.makedirs(in_root("/dev/shm"), exist_ok=True)
run("mount", "-t", "tmpfs", "-o", "mode=1777,nosuid,nodev", "shm", in_root("/dev/shm"))
for link, target in (("fd", "/proc/self/fd"), ("stdin", "/proc/self/fd/0"),
                     ("stdout", "/proc/self/fd/1"), ("stderr", "/proc/self/fd/2")):
    os.symlink(target, in_root("/dev/" + link))

# /sys: read-only (programs read hardware details there)
bind("/sys", "/sys", readonly=True, recursive=True)
run("mount", "-t", "proc", "proc", in_root("/proc"))

# Batocera's /run as /host-run, but only the sockets Plasma talks to:
# labwc (Wayland), PipeWire/PulseAudio (sound) and the request pipe for
# Batocera's apps (kdeplasma-apps.py). Not D-Bus, udev or other root services.
host_run = in_root("/host-run")
os.makedirs(host_run, exist_ok=True)
run("mount", "-t", "tmpfs", "-o", "mode=0755,nosuid,nodev,noexec", "kdeplasma-run", host_run)
for name in ("wayland-0", "pipewire-0", "pulse/native", "kdeplasma-apps.fifo"):
    bind("/run/" + name, "/host-run/" + name)
if os.path.isdir(in_root("/host-run/pulse")):
    os.chmod(in_root("/host-run/pulse"), 0o711)

# /userdata belongs to root and Plasma runs as "plasma" (uid 1000): mount it
# ID-mapped, so root's files show as plasma's and what plasma writes is
# stored as root, like Batocera's own file manager. Nothing on disk changes
# owner. Not recursive: the container itself lives inside /userdata.
userdata = in_root("/userdata")
os.makedirs(userdata, exist_ok=True)
if subprocess.run(["mount", "--bind", "-o", "X-mount.idmap=b:0:1000:1 b:1000:0:1",
                   "/userdata", userdata]).returncode != 0:
    run("mount", "--bind", "/userdata", userdata)
# ...except /userdata/system (Batocera's settings, services, custom.sh, SSH
# keys, add-ons), read-only so nothing run in Plasma can change how Batocera
# starts. Games, BIOS, saves, screenshots and music stay writable.
system = os.path.join(userdata, "system")
run("mount", "--bind", system, system)
run("mount", "-o", "remount,bind,ro", system)

# Other drives Batocera mounted under /media (USB drives, a second disk,
# another operating system). All of them visible, read-only first; then
# drives that hold files are made writable, with their own owners (so a
# uid-1000 user's files on them, e.g. SteamOS's "deck", are plasma's).
# Another system's EFI, boot, root and var partitions stay read-only, so
# nothing in Plasma can break that system. Drives plugged in while Plasma
# runs show up too (rslave).
SYSTEM_PARTITION = re.compile(r"^(esp|efi|boot|rootfs|root|var|batocera|share)(_\d+)?$", re.I)
if os.path.isdir("/media"):
    media = in_root("/media")
    os.makedirs(media, exist_ok=True)
    run("mount", "--rbind", "/media", media)
    run("mount", "--make-rslave", media)
    mounts = []
    with open("/proc/self/mountinfo") as f:
        for line in f:
            point = line.split()[4].replace("\\040", " ")
            if point == media or point.startswith(media + "/"):
                mounts.append(point)
    for point in mounts:
        subprocess.run(["mount", "-o", "remount,bind,ro", point], stderr=subprocess.DEVNULL)
    for point in mounts:
        rel = os.path.relpath(point, media)
        if "/" not in rel and rel != "." and not SYSTEM_PARTITION.match(rel):
            subprocess.run(["mount", "-o", "remount,bind,rw", point], stderr=subprocess.DEVNULL)

# Tell the launcher which mount namespace is the container's
with open(nsfile, "w") as f:
    f.write(os.readlink("/proc/self/ns/mnt"))

# Switch root to the container and drop Batocera's root
os.chdir(root)
os.makedirs(".oldroot", exist_ok=True)
check(libc.syscall(SYS_pivot_root, b".", b".oldroot"), "pivot_root")
os.chdir("/")
check(libc.umount2(b"/.oldroot", MNT_DETACH), "detaching the old root")
os.rmdir("/.oldroot")

os.execv(command[0], command)
