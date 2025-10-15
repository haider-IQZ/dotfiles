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

### 1. Clone this repository
```bash
git clone https://github.com/haider-IQZ/dotfiles.git
cd dotfiles
```

### 2. Run the install script
```bash
chmod +x install.sh
./install.sh
```

The script will automatically:
- Install all required packages (pacman + AUR)
- Install Oh My Zsh with Powerlevel10k theme
- Install Zsh plugins (autosuggestions, syntax highlighting)
- Copy all config files
- Change your default shell to Zsh

### 3. Logout and login
After installation, logout and login again for Zsh to take effect.

### 4. Done!
Your BSPWM setup is ready! Press Super+Shift+R to reload if needed.

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
