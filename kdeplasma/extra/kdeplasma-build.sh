#!/bin/bash
# Builds (or updates) the KDE Plasma Desktop container: an Arch Linux system
# in /userdata/system/add-ons/kdeplasma/rootfs with Plasma installed.
# Batocera has no package manager and its own libraries would clash with
# Plasma's, so Plasma lives in its own folder and runs with chroot (no
# Docker). Run by kdeplasma.sh; running it again updates Plasma.
set -e

install_dir="/userdata/system/add-ons/kdeplasma"
root="$install_dir/rootfs"
bootstrap_url="https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst"

# Unpack Arch Linux the first time
if [ ! -x "$root/usr/bin/pacman" ]; then
    echo "Downloading Arch Linux base system..."
    mkdir -p "$install_dir"
    curl -fL --progress-bar -o "$install_dir/bootstrap.tar.zst" "$bootstrap_url"
    echo "Extracting..."
    rm -rf "$install_dir/root.x86_64"
    tar --zstd -xf "$install_dir/bootstrap.tar.zst" -C "$install_dir" --numeric-owner
    rm -rf --one-file-system "$root"
    mv "$install_dir/root.x86_64" "$root"
    rm -f "$install_dir/bootstrap.tar.zst" "$install_dir/pkglist.x86_64.txt" "$install_dir/version"
fi

mounted() { awk -v m="$1" '$2==m {f=1} END {exit !f}' /proc/mounts; }
# The container bound onto itself first (pacman expects a real mount at /),
# then everything else on top of it
mounted "$root" || mount --bind "$root" "$root"
bind() { mounted "$2" || { mkdir -p "$2"; mount --rbind "$1" "$2"; mount --make-rslave "$2"; }; }
bind /dev "$root/dev"
bind /sys "$root/sys"
mounted "$root/proc" || mount -t proc proc "$root/proc"
cp -L /etc/resolv.conf "$root/etc/resolv.conf"

# Unmount again when done, even on failure
cleanup() {
    for _ in 1 2 3 4 5; do
        mounts=$(awk -v r="$root" 'index($2, r)==1 {print $2}' /proc/mounts | sort -r)
        [ -z "$mounts" ] && break
        for m in $mounts; do umount -l "$m" 2>/dev/null; done
    done
}
trap cleanup EXIT

# Package mirror, parallel downloads, and no download sandbox (it needs
# Landlock, which Batocera's kernel does not have)
grep -q '^Server' "$root/etc/pacman.d/mirrorlist" || \
    echo 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch' >> "$root/etc/pacman.d/mirrorlist"
sed -i 's/^#ParallelDownloads/ParallelDownloads/; s/^CheckSpace/#CheckSpace/' "$root/etc/pacman.conf"
grep -q '^DisableSandbox' "$root/etc/pacman.conf" || sed -i '/^\[options\]/a DisableSandbox' "$root/etc/pacman.conf"

inroot() { chroot "$root" /usr/bin/env -i HOME=/root TERM=xterm PATH=/usr/bin:/usr/sbin "$@"; }
if [ ! -f "$root/etc/pacman.d/gnupg/pubring.gpg" ] && [ ! -f "$root/etc/pacman.d/gnupg/pubring.kbx" ]; then
    echo "Setting up package signing keys..."
    inroot pacman-key --init
    inroot pacman-key --populate archlinux
fi

echo "Installing KDE Plasma (about 750 MB to download)..."
inroot pacman -Syu --noconfirm --needed \
    plasma-desktop kwin plasma-workspace breeze breeze-gtk kde-gtk-config \
    plasma-pa plasma-nm powerdevil kscreen systemsettings \
    konsole dolphin kate ark spectacle gwenview \
    discover flatpak flatpak-kcm \
    xorg-xwayland mesa vulkan-radeon vulkan-intel libva-mesa-driver intel-media-driver \
    pipewire pipewire-pulse wireplumber \
    noto-fonts ttf-dejavu sudo
inroot pacman -Scc --noconfirm >/dev/null 2>&1 || true

# A normal user: KDE apps refuse to run as root
if ! inroot id plasma >/dev/null 2>&1; then
    inroot useradd -m -u 1000 -G wheel,video,audio,input -s /bin/bash plasma
fi
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > "$root/etc/sudoers.d/wheel"
# Its runtime folder: /run/user must be reachable by the plasma user
mkdir -p "$root/run/user/1000"
chmod 0755 "$root/run/user"

# Lock screen: Arch has no PAM "kde" service, which would refuse every
# unlock; with it, Enter (empty password) unlocks
[ -f "$root/etc/pam.d/kde" ] || printf '#%%PAM-1.0\nauth     include system-login\naccount  include system-login\npassword include system-login\nsession  include system-login\n' > "$root/etc/pam.d/kde"
inroot passwd -d plasma >/dev/null

# Discover installs apps from Flathub, per user (no root service needed).
# Run through kdeplasma-enter.py rather than chroot: Flatpak's sandbox needs
# user namespaces, which the kernel refuses inside a chroot.
trap - EXIT
cleanup
python3 "$install_dir/kdeplasma-enter.py" "$root" /run/kdeplasma-build.mntns \
    /usr/bin/runuser -u plasma -- /usr/bin/env -i HOME=/home/plasma PATH=/usr/bin \
    flatpak --user remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo \
    || echo "Could not add Flathub now; Discover can add it later."
rm -f /run/kdeplasma-build.mntns

echo "KDE Plasma is ready."
