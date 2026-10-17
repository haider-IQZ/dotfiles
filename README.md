# dotfiles

My desktop pieces that aren't tied to one machine's NixOS config (that lives in `~/hq`).

## quickshell/: the island bar

A [Quickshell](https://quickshell.org) (0.3.x) shell for Hyprland, one floating black island
that grows into whatever you open:

- **pill**: workspaces (the focused one is a capsule), clock, tray, music, notifications,
  network bars, volume, battery (only on machines that have one)
- **hover**: grows into the focused app, clock + date, now playing, notification status
- **cards** (click a module): calendar, audio devices + levels, network + DNS provider,
  tray menus, notification center, and a Spotify-style music card (any MPRIS player, plus a
  local music library played with mpv: search, download from a link with yt-dlp)
- **launcher** (`qs ipc call launcher toggle`): apps, power, toggles, grows out of the island
- **wallpaper**: the bar draws it itself (background layer, crossfade) and has a picker
  (`qs ipc call wallpaper pick`): no awww/swww/hyprpaper/waypaper
- **colors from the wallpaper**: the accent is picked from the current wallpaper and fades when
  it changes; it's also written for the terminal (see below)
- notifications (it *is* the notification server), no mako/dunst

### Needs

- quickshell 0.3.x, Hyprland (either the classic `hyprland.conf` or the new `hyprland.lua`:
  the bar checks which one you have)
- fonts: Inter (text), JetBrainsMono Nerd Font (icons); Papirus-Dark icon theme
- mpv, ffmpeg (local music + covers), yt-dlp (downloads), NetworkManager (`nmcli`)
- optional: `extras/dns` on your PATH as `dns`, for the DNS buttons in the network card

### Use

```sh
ln -s ~/code/dotfiles/quickshell ~/.config/quickshell   # (hq does this with home-manager)
qs -d -n
```

Hyprland binds I use:

```lua
hl.bind(mod .. " + D", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("qs ipc call wallpaper pick"))
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("qs ipc call media playPause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("qs ipc call media next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("qs ipc call media previous"), { locked = true })
```

Other IPC: `wallpaper set <file>` / `get`, `bar card <calendar|audio|network|media|notifications>`,
`bar close`, `media open`.

### State

`$XDG_STATE_HOME/bar/`: `settings.json` (wallpaper, wallpaper folder, music folder and volume,
last accent), `launcher.json` (how often you open each app), and `theme/`: files the bar
rewrites whenever the accent changes, for the terminal to pick up:
`foot.ini` (include it), `alacritty.toml` (import it), `fzf` (`FZF_DEFAULT_OPTS_FILE`),
`starship.toml` (your `~/.config/starship.toml` with its `accent` palette color swapped), and
`fish.fish` (source it; the bar sets the universal variable `bar_theme` when it changes, so
open shells can reload it and recolor their terminal).

### Hook the terminal up (optional)

The bar keeps `$XDG_STATE_HOME/bar/theme/` in the wallpaper's colors; point your tools at it:

```ini
# ~/.config/foot/foot.ini, under [main] (don't set background/cursor/selection-background yourself)
include=~/.local/state/bar/theme/foot.ini
```

```toml
# ~/.config/alacritty/alacritty.toml (don't set primary.background/cursor/selection yourself)
[general]
import = ["~/.local/state/bar/theme/alacritty.toml"]
```

```css
/* ~/.config/gtk-3.0/gtk.css: GTK3 apps (adw-gtk3 theme) in the wallpaper's colors */
@import url("file:///home/YOU/.local/state/bar/theme/gtk3.css");
```

- **fish**: `source extras/fish/bar-theme.fish` from `config.fish`. Open shells recolor
  themselves when the wallpaper changes, and `ls`/`eza` folders follow the accent.
- **starship**: keep your config at `~/.config/starship.toml`, define a palette color named
  `accent` and use it (`style = "bold accent"`); the bar writes a copy with the wallpaper's
  accent and fish points `STARSHIP_CONFIG` at it.
- **fzf**: highlights come from `FZF_DEFAULT_OPTS_FILE` (set by the fish file); keep `hl`,
  `pointer`, `prompt`... out of your own `FZF_DEFAULT_OPTS`.
- **fetch**: `extras/fish/fetch.fish` is a coffee mug in the accent's shades with some system
  facts; source it and call `fetch` (e.g. at the end of `config.fish`).

### Glass windows (Hyprland)

Blur plus a little transparency makes apps sit nicely on the wallpaper, e.g. in `hyprland.lua`:

```lua
hl.window_rule({ name = "obsidian-glass", match = { class = "^(obsidian)$" }, opacity = "0.88 0.85" })
```

