#!/bin/bash
set -e  # Exit on error

echo "=== BSPWM Dotfiles Installation ==="
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo "❌ Please don't run this script as root!"
    exit 1
fi

# Check internet connection
if ! ping -c 1 archlinux.org &> /dev/null; then
    echo "❌ No internet connection detected!"
    exit 1
fi

# Install required packages
echo "📦 Installing required packages..."
sudo pacman -S --needed --noconfirm bspwm sxhkd polybar picom rofi alacritty git base-devel thunar nitrogen flameshot ttf-dejavu zsh zsh-completions fastfetch pavucontrol || {
    echo "❌ Failed to install packages!"
    exit 1
}

# Install AUR helper if not present
if ! command -v paru &> /dev/null; then
    echo "🔧 Installing yay-bin (temporary AUR helper)..."
    cd /tmp
    rm -rf yay-bin
    git clone https://aur.archlinux.org/yay-bin.git || {
        echo "❌ Failed to clone yay-bin!"
        exit 1
    }
    cd yay-bin
    makepkg -si --noconfirm || {
        echo "❌ Failed to build yay-bin!"
        exit 1
    }
    cd -
    
    echo "🔧 Installing paru-bin..."
    yay -S --noconfirm paru-bin || {
        echo "❌ Failed to install paru-bin!"
        exit 1
    }
    
    echo "🧹 Removing yay..."
    sudo pacman -Rns --noconfirm yay-bin
fi

# Install AUR packages
echo "📦 Installing AUR packages..."
paru -S --needed --noconfirm zen-browser-bin windsurf bibata-cursor-theme || {
    echo "⚠️  Warning: Some AUR packages failed to install, continuing..."
}

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Powerlevel10k theme
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    echo "Installing Powerlevel10k theme..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
fi

# Install Zsh plugins
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
fi

echo ""
echo "Backing up existing configs..."

# Backup existing configs
mkdir -p ~/.config_backup
cp -r ~/.config/bspwm ~/.config_backup/ 2>/dev/null
cp -r ~/.config/sxhkd ~/.config_backup/ 2>/dev/null
cp -r ~/.config/polybar ~/.config_backup/ 2>/dev/null
cp -r ~/.config/picom ~/.config_backup/ 2>/dev/null
cp -r ~/.config/rofi ~/.config_backup/ 2>/dev/null
cp -r ~/.config/alacritty ~/.config_backup/ 2>/dev/null
cp -r ~/.config/fontconfig ~/.config_backup/ 2>/dev/null
cp ~/.bashrc ~/.config_backup/ 2>/dev/null
cp ~/.zshrc ~/.config_backup/ 2>/dev/null
cp ~/.p10k.zsh ~/.config_backup/ 2>/dev/null
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
cp -r gtk-3.0 ~/.config/
cp -r fontconfig ~/.config/
cp .gtkrc-2.0 ~/
cp .Xresources ~/
cp .bashrc ~/
cp .zshrc ~/
cp .p10k.zsh ~/

# Change default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to Zsh..."
    chsh -s $(which zsh)
    echo "Shell changed to Zsh! You'll need to logout and login for it to take effect."
fi

echo ""
echo "==================================="
echo "✅ Installation complete!"
echo "==================================="
echo ""
echo "📋 Next steps:"
echo "  1. Logout and login again (for Zsh to take effect)"
echo "  2. Restart bspwm: Super+Shift+R"
echo "  3. Enjoy your setup! 🚀"
echo ""
echo "💾 Your old configs are backed up in ~/.config_backup/"
echo ""
