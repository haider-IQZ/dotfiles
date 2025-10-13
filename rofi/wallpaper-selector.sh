#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
CACHE_DIR="$HOME/.cache/wallpaper-picker"

# Create cache directory for thumbnails
mkdir -p "$CACHE_DIR"

# Check if directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Wallpaper directory not found!"
    exit 1
fi

# Find all wallpapers
wallpapers=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null)

if [ -z "$wallpapers" ]; then
    notify-send "Wallpaper Picker" "No wallpapers found!"
    exit 1
fi

# Generate thumbnails and create rofi entries with image preview
entries=""
first=true
while IFS= read -r wallpaper; do
    [ -z "$wallpaper" ] && continue
    filename=$(basename "$wallpaper")
    thumbnail="$CACHE_DIR/${filename}.thumb.png"
    
    # Generate thumbnail if it doesn't exist
    if [ ! -f "$thumbnail" ]; then
        convert "$wallpaper" -resize 400x300^ -gravity center -extent 400x300 "$thumbnail" 2>/dev/null
    fi
    
    # Add entry with icon (thumbnail)
    if [ "$first" = true ]; then
        entries="${filename}\x00icon\x1f${thumbnail}"
        first=false
    else
        entries="${entries}\n${filename}\x00icon\x1f${thumbnail}"
    fi
done <<< "$wallpapers"

# Show in rofi with icons
chosen=$(echo -e "$entries" | rofi -dmenu -i -p "Select Wallpaper" -show-icons -theme ~/.config/rofi/wallpaper-theme.rasi)

if [ -n "$chosen" ]; then
    # Set wallpaper
    feh --bg-fill "$WALLPAPER_DIR/$chosen"
    nitrogen --set-zoom-fill "$WALLPAPER_DIR/$chosen" --save
    notify-send "Wallpaper Set!" "$chosen"
fi
