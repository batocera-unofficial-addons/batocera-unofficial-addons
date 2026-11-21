#!/bin/bash
# Hotkey+Start (from the Ports entry): log out of Plasma. The launcher then
# closes what is left in the container and EmulationStation returns.
pkill -f '^/usr/bin/startplasma-waylan[d]'
