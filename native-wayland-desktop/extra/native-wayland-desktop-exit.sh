#!/bin/bash
# Hotkey+Start (from the Ports entry): close the Native Wayland Desktop and go back to
# EmulationStation.
pid=$(cat /run/native-wayland-desktop.pid 2>/dev/null)
[ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
