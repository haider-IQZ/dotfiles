# Required Packages

## Official Repositories (pacman)
```bash
sudo pacman -S bspwm sxhkd polybar picom rofi alacritty git base-devel thunar nitrogen flameshot pavucontrol ttf-dejavu zsh zsh-completions fastfetch
```

### Package Breakdown:
- **bspwm** - Window manager
- **sxhkd** - Hotkey daemon
- **polybar** - Status bar
- **picom** - Compositor (transparency, shadows, etc.)
- **rofi** - Application launcher
- **alacritty** - Terminal emulator
- **git** - Version control
- **base-devel** - Build tools for AUR
- **thunar** - File manager
- **nitrogen** - Wallpaper setter
- **flameshot** - Screenshot tool with GUI and editing features
- **pavucontrol** - Volume control GUI
- **ttf-dejavu** - DejaVu fonts with Arabic support
- **zsh** - Z shell (better than bash)
- **zsh-completions** - Additional completion definitions for Zsh
- **fastfetch** - System info tool (neofetch alternative)

## AUR Packages (paru/yay)
```bash
paru -S zen-browser-bin windsurf bibata-cursor-theme
```

### AUR Package Breakdown:
- **zen-browser-bin** - Zen browser (Firefox-based with modern UI)
- **windsurf** - Code editor
- **bibata-cursor-theme** - Modern cursor theme

## Optional but Recommended
```bash
sudo pacman -S feh dunst libnotify
paru -S zed
```

- **feh** - Alternative image viewer/wallpaper setter
- **dunst** - Notification daemon
- **libnotify** - Desktop notifications
- **zed** - Modern code editor (already in your keybinds)
