#!/bin/bash
# Hotkey+Start (from the Ports entry): close the Light Desktop and go back to
# EmulationStation.
pid=$(cat /run/lightdesktop.pid 2>/dev/null)
[ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
