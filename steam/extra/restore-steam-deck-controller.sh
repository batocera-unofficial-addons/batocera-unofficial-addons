#!/bin/bash
# Restore Steam Deck controller without reboot.
# Run via SSH when controls disappear after exiting a Non-Steam game:
#   ~/bin/ssh-batocera.sh "/userdata/system/add-ons/steam/extra/restore-steam-deck-controller.sh"
killall -9 evmapy 2>/dev/null || true
pkill -9 -f proton 2>/dev/null || true
pkill -9 -f steam 2>/dev/null || true
killall -9 emulationstation 2>/dev/null || true
sleep 3
modprobe -r hid_steam 2>/dev/null || true
sleep 1
modprobe hid_steam 2>/dev/null || true
sleep 2
udevadm trigger --action=change 2>/dev/null || true
sleep 1
killall -9 emulationstation 2>/dev/null || true
