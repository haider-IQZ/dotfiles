#!/bin/bash

ICON_DIR="$HOME/.config/rofi/icons"

# Settings menu options with image icons
options="Wallpaper Picker\x00icon\x1f${ICON_DIR}/wallpaper.png
Audio Settings\x00icon\x1f${ICON_DIR}/audio.png
Display Settings\x00icon\x1f${ICON_DIR}/display.png
Bluetooth\x00icon\x1f${ICON_DIR}/bluetooth.png
Network Settings\x00icon\x1f${ICON_DIR}/network.png
File Manager\x00icon\x1f${ICON_DIR}/files.png
Power Menu\x00icon\x1f${ICON_DIR}/power.png"

# Show menu with custom theme
chosen=$(echo -e "$options" | rofi -dmenu -i -p "Settings" -show-icons -theme ~/.config/rofi/settings-theme.rasi)

case "$chosen" in
    "Wallpaper Picker")
        ~/.config/rofi/wallpaper-selector.sh
        ;;
    "Audio Settings")
        pavucontrol
        ;;
    "Display Settings")
        arandr
        ;;
    "Bluetooth")
        blueman-manager
        ;;
    "Network Settings")
        nm-connection-editor
        ;;
    "File Manager")
        GTK_THEME=Adwaita:dark thunar
        ;;
    "Power Menu")
        powermenu=$(echo -e "Shutdown\nReboot\nLogout" | rofi -dmenu -i -p "Power" -theme ~/.config/rofi/settings-theme.rasi)
        case "$powermenu" in
            "Shutdown")
                systemctl poweroff
                ;;
            "Reboot")
                systemctl reboot
                ;;
            "Logout")
                bspc quit
                ;;
        esac
        ;;
esac
