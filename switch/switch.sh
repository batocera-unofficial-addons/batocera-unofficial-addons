#!/bin/bash

# Check if rgs.version exists
if [ -f "/userdata/system/rgs.version" ]; then
    dialog --msgbox "Team Pixel Nostalgia's build supports Switch emulation natively. No need to install it via BUA." 8 60
    clear
    exit 0
fi

curl -L bit.ly/foclabroc-switch-all | bash
