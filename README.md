# Haider's Dotfiles

My BSPWM rice configuration for Arch Linux.

## Screenshots
(Add screenshots later)

## Components
- **WM:** bspwm
- **Hotkeys:** sxhkd
- **Bar:** polybar
- **Compositor:** picom
- **Launcher:** rofi
- **Terminal:** alacritty
- **Fonts:** Nerd Fonts (JetBrains Mono, Iosevka, Material Design Icons, etc.)

## Installation on Fresh Arch

### 1. Install required packages
sudo pacman -S bspwm sxhkd polybar picom rofi alacritty git base-devel thunar nitrogen

### 2. Install AUR helper (if you don't have one)
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..

then-install = = paru -S google-chrome windsurf 


### 3. Clone this repository
git clone https://github.com/haider-IQZ/dotfiles.git
cd dotfiles

### 4. Run the install script
chmod +x install.sh
./install.sh

### 5. Restart bspwm
Press Super+Shift+R or logout and login again.

## Notes
- Fonts are included in the fonts/ directory and will be installed automatically
- Your old configs are backed up to ~/.config_backup/ before installation
- If something breaks, restore from backup: cp -r ~/.config_backup/* ~/.config/

## Customization
Edit the configs in ~/.config/ after installation:
- BSPWM settings: ~/.config/bspwm/bspwmrc
- Keybindings: ~/.config/sxhkd/sxhkdrc
- Polybar: ~/.config/polybar/
- Picom effects: ~/.config/picom/picom.conf

## Package List
Full package list saved in pkglist.txt for reference.
