#!/bin/bash
volume=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -Po '\d+(?=%)' | head -1)
muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -o 'yes')

if [ "$muted" == "yes" ]; then
    echo "󰖁 MUTED"
else
    echo "󰕾 $volume%"
fi
