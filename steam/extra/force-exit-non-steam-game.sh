#!/bin/bash
# Force exit Non-Steam game AND restore Steam Deck controller.
# ALWAYS does both: exit game, then modprobe hid_steam to restore controller.
killall -9 evmapy 2>/dev/null || true
pkill -9 -f proton 2>/dev/null || true
pkill -9 -f steam 2>/dev/null || true
killall -9 emulationstation 2>/dev/null || true
sleep 3

# Restore Steam Deck controller (required after Non-Steam game exit)
modprobe -r hid_steam 2>/dev/null || true
sleep 1
modprobe hid_steam 2>/dev/null || true
sleep 2
udevadm trigger --action=change 2>/dev/null || true
sleep 1
killall -9 emulationstation 2>/dev/null || true
