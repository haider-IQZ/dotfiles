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
sudo pacman -S --needed bspwm sxhkd polybar picom rofi alacritty git base-devel thunar nitrogen flameshot ttf-dejavu zsh zsh-completions fastfetch pavucontrol || {
    echo "❌ Failed to install packages!"
    exit 1
}

# Install AUR helper if not present
if ! command -v paru &> /dev/null; then
    echo ""
    echo "🔧 Installing paru-bin (AUR helper)..."
    echo "This will require your input for confirmation."
    echo ""
    
    cd /tmp
    rm -rf paru-bin
    git clone https://aur.archlinux.org/paru-bin.git || {
        echo "❌ Failed to clone paru-bin!"
        exit 1
    }
    cd paru-bin
    
    # This will ask for confirmation
    makepkg -si || {
        echo "❌ Failed to build paru-bin!"
        exit 1
    }
    cd -
    
    echo "✅ paru installed successfully!"
fi

# Install AUR packages (will ask for confirmation)
echo ""
echo "📦 Installing AUR packages..."
echo "You'll be asked to confirm each package installation."
echo ""

# Install each package separately so one failure doesn't stop everything
paru -S --needed zen-browser-bin || echo "⚠️  zen-browser-bin failed or was skipped"
paru -S --needed windsurf || echo "⚠️  windsurf failed or was skipped"
paru -S --needed bibata-cursor-theme || echo "⚠️  bibata-cursor-theme failed or was skipped"

# Install Oh My Zsh if not present
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo ""
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
cp -r ~/.config/bspwm ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/sxhkd ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/polybar ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/picom ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/rofi ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/alacritty ~/.config_backup/ 2>/dev/null || true
cp -r ~/.config/fontconfig ~/.config_backup/ 2>/dev/null || true
cp ~/.bashrc ~/.config_backup/ 2>/dev/null || true
cp ~/.zshrc ~/.config_backup/ 2>/dev/null || true
cp ~/.p10k.zsh ~/.config_backup/ 2>/dev/null || true

# Install fonts
echo "Installing fonts..."
mkdir -p ~/.local/share/fonts
cp -r fonts/* ~/.local/share/fonts/ 2>/dev/null || echo "⚠️  No fonts directory found, skipping..."
fc-cache -fv

# Copy all dotfiles
echo "Copying dotfiles..."
cp -r alacritty ~/.config/
cp -r bspwm ~/.config/
cp -r picom ~/.config/
cp -r polybar ~/.config/
cp -r rofi ~/.config/
cp -r sxhkd ~/.config/
cp -r gtk-3.0 ~/.config/ 2>/dev/null || true
cp -r fontconfig ~/.config/ 2>/dev/null || true
cp .gtkrc-2.0 ~/ 2>/dev/null || true
cp .Xresources ~/ 2>/dev/null || true
cp .bashrc ~/
cp .zshrc ~/
cp .p10k.zsh ~/

# Make bspwm and sxhkd executable
chmod +x ~/.config/bspwm/bspwmrc
chmod +x ~/.config/sxhkd/sxhkdrc

# Change default shell to Zsh
if [ "$SHELL" != "$(which zsh)" ]; then
    echo ""
    echo "Changing default shell to Zsh..."
    chsh -s $(which zsh)
    echo "✅ Shell changed to Zsh! You'll need to logout and login for it to take effect."
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
