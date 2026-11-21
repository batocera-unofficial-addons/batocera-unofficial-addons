#!/bin/bash
# Proof of concept: Arch Linux container with KDE Plasma for Batocera 44 (labwc).
# Step 1: unpack Arch, prepare pacman. Step 2: install Plasma.
set -e
base=/userdata/system/add-ons/plasma
root=$base/rootfs
log=/userdata/system/logs/plasma-setup.log
exec > >(tee -a "$log") 2>&1
echo "== $(date) setup start"

mkdir -p "$base"
if [ ! -x "$root/usr/bin/pacman" ]; then
    echo "Downloading Arch Linux bootstrap..."
    curl -fL -o "$base/bootstrap.tar.zst" https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst
    echo "Extracting..."
    rm -rf "$base/root.x86_64"
    tar --zstd -xf "$base/bootstrap.tar.zst" -C "$base" --numeric-owner
    rm -rf "$root"
    mv "$base/root.x86_64" "$root"
    rm -f "$base/bootstrap.tar.zst"
fi

# Mount what pacman and Plasma need (each only once)
mounted() { awk -v m="$1" '$2==m {f=1} END {exit !f}' /proc/mounts; }
bind() { mounted "$2" || { mkdir -p "$2"; mount --rbind "$1" "$2"; mount --make-rslave "$2"; }; }
# The container bound onto itself first (pacman expects a real mount at /),
# then everything else on top of it
mounted "$root" || mount --bind "$root" "$root"
bind /dev "$root/dev"
bind /sys "$root/sys"
mounted "$root/proc" || mount -t proc proc "$root/proc"
cp -L /etc/resolv.conf "$root/etc/resolv.conf"

# Mirrors and keys
grep -q '^Server' "$root/etc/pacman.d/mirrorlist" || \
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' >> "$root/etc/pacman.d/mirrorlist"
sed -i 's/^#ParallelDownloads/ParallelDownloads/; s/^CheckSpace/#CheckSpace/' "$root/etc/pacman.conf"
# Batocera's kernel has no Landlock, which pacman's download sandbox needs
grep -q '^DisableSandbox' "$root/etc/pacman.conf" || sed -i '/^\[options\]/a DisableSandbox' "$root/etc/pacman.conf"
inroot() { chroot "$root" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin "$@"; }
if [ ! -f "$root/etc/pacman.d/gnupg/pubring.gpg" ] && [ ! -f "$root/etc/pacman.d/gnupg/pubring.kbx" ]; then
    inroot pacman-key --init
    inroot pacman-key --populate archlinux
fi

echo "Installing Plasma (this is the big part)..."
inroot pacman -Syu --noconfirm --needed \
    plasma-desktop kwin plasma-workspace breeze breeze-gtk kde-gtk-config \
    plasma-pa plasma-nm powerdevil kscreen systemsettings \
    konsole dolphin kate ark spectacle gwenview \
    xorg-xwayland mesa vulkan-radeon libva-mesa-driver \
    pipewire pipewire-pulse wireplumber \
    noto-fonts ttf-dejavu sudo

# A normal user: KDE apps refuse to run as root
if ! inroot id plasma >/dev/null 2>&1; then
    inroot useradd -m -u 1000 -G wheel,video,audio,input -s /bin/bash plasma
fi
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "$root/etc/sudoers.d/wheel"

echo "== $(date) setup done"
