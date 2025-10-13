#!/bin/bash
# Reload sxhkd
pkill -USR1 -x sxhkd

# Reload polybar
killall -q polybar
sleep 0.5
~/.config/polybar/launch.sh &

# Reload bspwm config (without restarting WM)
~/.config/bspwm/bspwmrc &

notify-send "Reloaded" "sxhkd, polybar, and bspwm configs"
