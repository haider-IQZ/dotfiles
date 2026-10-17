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

- quickshell 0.3.x, Hyprland
- fonts: Inter (text), JetBrainsMono Nerd Font (icons); Papirus-Dark icon theme
- mpv, ffmpeg (local music + covers), yt-dlp (downloads), NetworkManager (`nmcli`)
- optional: a `dns <provider>` command for the DNS buttons (mine is in `~/hq/scripts/dns`)

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
