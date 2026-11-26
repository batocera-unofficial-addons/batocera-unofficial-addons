#!/bin/bash
# Hotkey+Start (from the Ports entry): close the Native X11 Desktop and go
# back to EmulationStation.
pid=$(cat /run/native-x11-desktop.pid 2>/dev/null)
[ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
