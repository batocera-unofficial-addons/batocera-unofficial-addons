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

# The container, then the system folders on top of it
run("mount", "--bind", root, root)
for src, dst in (("/dev", "dev"), ("/sys", "sys"), ("/run", "host-run")):
    os.makedirs(os.path.join(root, dst), exist_ok=True)
    run("mount", "--rbind", src, os.path.join(root, dst))
run("mount", "-t", "proc", "proc", os.path.join(root, "proc"))
# /userdata belongs to root and Plasma runs as "plasma" (uid 1000): mount it
# ID-mapped, so root's files show as plasma's and what plasma writes is
# stored as root, like Batocera's own file manager. Nothing on disk changes
# owner. Not recursive: the container itself lives inside /userdata.
userdata = os.path.join(root, "userdata")
os.makedirs(userdata, exist_ok=True)
if subprocess.run(["mount", "--bind", "-o", "X-mount.idmap=b:0:1000:1 b:1000:0:1",
                   "/userdata", userdata]).returncode != 0:
    run("mount", "--bind", "/userdata", userdata)

# Switch root to the container and drop Batocera's root
os.chdir(root)
os.makedirs(".oldroot", exist_ok=True)
check(libc.syscall(SYS_pivot_root, b".", b".oldroot"), "pivot_root")
os.chdir("/")
check(libc.umount2(b"/.oldroot", MNT_DETACH), "detaching the old root")
os.rmdir("/.oldroot")

# Tell the launcher which mount namespace is the container's. <nsfile> is in
# Batocera's /run, which the container sees as /host-run.
with open(os.path.join("/host-run", os.path.basename(nsfile)), "w") as f:
    f.write(os.readlink("/proc/self/ns/mnt"))

os.execv(command[0], command)
