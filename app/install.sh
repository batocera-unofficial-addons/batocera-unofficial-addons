#!/bin/bash

# Check for Profork
if [[ -e "/userdata/system/pro" ]]; then
    cat <<'EOF' > /dev/tty

Cliffy has decided to act like a child for an unknown reason.
I haven't touched his repo whatsoever, but he has decided to mess with BUA's launching script.
What I once believed would be a great collaboration partnership to work on a viable Batocera Pro replacement
has instead turned into a school playground. The only problem is, I'm not in that playground, so it's just
Cliffy throwing toys around for no reason. Don't know what's up with you bro, but I ain't got time for it.

Unfortunately he's decided, despite no incompatibility, that BUA cannot be installed alongside Profork.

Please note: if you continue with this installation, Profork will no longer open, as Cliffy added a detection
code and a lock file. Don't ask me why — this is literally the only thing in the entire BUA repo that even
has any reference to Profork. But hey, I'm not here to tell people how to run their own repos...
just don't fuck with mine, bro.

EOF

    echo -n "Type 'y' and press Enter to continue, or anything else to exit: " > /dev/tty
    read confirm < /dev/tty

    if [[ "${confirm,,}" != "y" ]]; then
        echo -e "\nExiting..." > /dev/tty
        sleep 2
        clear
        exit 0
    fi
fi

# URLs
AMD64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_x86.sh"
ARM64="https://github.com/DTJW92/batocera-unofficial-addons/raw/refs/heads/main/app/install_arm64.sh"

# Filesystem check
fstype=$(stat -f -c %T /userdata)
incompatible_types=("vfat" "msdos" "exfat" "cifs" "ntfs")

for type in "${incompatible_types[@]}"; do
    if [[ "$fstype" == "$type" ]]; then
        echo -e "\e[31mError:\e[0m The file system type '$fstype' on /userdata does not reliably support symlinks. Incompatible."
        exit 1
    fi
done

echo -e "\e[32mFile system '$fstype' supports symlinks. Continuing...\e[0m"

# Architecture detection
ARCH=$(uname -m)

if [[ "$ARCH" == "x86_64" ]]; then
    echo "Detected AMD64 architecture. Executing the install script..."
    curl -Ls "$AMD64" | bash
elif [[ "$ARCH" == "aarch64" ]]; then
    echo "Detected ARM64 architecture. Executing the install script..."
    curl -Ls "$ARM64" | bash
else
    echo -e "\e[31mUnsupported architecture:\e[0m $ARCH"
    exit 1
fi
