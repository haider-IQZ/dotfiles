#!/bin/bash

echo "Installing dotfiles..."

# Backup existing configs
mkdir -p ~/.config_backup
cp -r ~/.config/bspwm ~/.config_backup/ 2>/dev/null
cp -r ~/.config/sxhkd ~/.config_backup/ 2>/dev/null
cp -r ~/.config/polybar ~/.config_backup/ 2>/dev/null
cp -r ~/.config/picom ~/.config_backup/ 2>/dev/null
cp -r ~/.config/rofi ~/.config_backup/ 2>/dev/null
cp -r ~/.config/alacritty ~/.config_backup/ 2>/dev/null
mkdir -p ~/.local/share/fonts
cp -r fonts/* ~/.local/share/fonts/
fc-cache -fv

# Copy all dotfiles
cp -r alacritty ~/.config/
cp -r bspwm ~/.config/
cp -r picom ~/.config/
cp -r polybar ~/.config/
cp -r rofi ~/.config/
cp -r sxhkd ~/.config/

echo "Dotfiles installed! Restart bspwm (Super+Shift+R) to apply changes."
