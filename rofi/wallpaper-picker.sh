#!/bin/bash

# Wallpaper directory
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"

# Check if directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Wallpaper directory not found!"
    exit 1
fi

# Check if wallpapers exist
cd "$WALLPAPER_DIR"
wallpapers=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null)

if [ -z "$wallpapers" ]; then
    notify-send "Wallpaper Picker" "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

# Show wallpapers in rofi with preview using filenames
chosen=$(echo "$wallpapers" | xargs -n1 basename | rofi -dmenu -i -p "Select Wallpaper" -theme ~/.config/rofi/launchers/type-3/style-1.rasi)

if [ -n "$chosen" ]; then
    # Set wallpaper with feh
    feh --bg-fill "$WALLPAPER_DIR/$chosen"
    # Also save to nitrogen config
    nitrogen --set-zoom-fill "$WALLPAPER_DIR/$chosen" --save
    notify-send "Wallpaper Set!" "$chosen"
fi
