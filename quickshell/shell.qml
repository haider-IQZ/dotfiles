//@ pragma IconTheme Papirus-Dark
// The bar: a floating island (Hyprland). Quickshell 0.3.1; save this file and it reloads by itself.
//   small:   ▮•••• 16:53 ▂▄▆█ 🔊               hover: grows into app · clock/date/now playing · status
// The bar also draws the wallpaper (a background layer, crossfading) and Super+W picks it
// (WallpaperPicker.qml): no awww/swww/hyprpaper/waypaper needed.

import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "Paths.js" as Paths

ShellRoot {
    id: root

    // black island, mint accent, warm white text
    // the accent comes from the wallpaper (see "colors from the wallpaper" below) and fades
    // when it changes; mint until the first pick
    property color accent: "#3dd2b0"
    Behavior on accent { enabled: root.prefsReady; ColorAnimation { duration: 700; easing.type: Easing.InOutQuad } }
    readonly property color bg: "#070707"            // cards
    readonly property color bgDark: "#000000"        // the island
    readonly property color bgAlt: Qt.tint("#1c1918", Qt.alpha(accent, 0.07))         // borders, chips, slider tracks
    readonly property color fg: "#ece4dc"
    readonly property color dim: "#8a827c"
    readonly property color faint: "#4a4542"         // disabled text, placeholders
    readonly property color red: "#e0705a"
    readonly property color critical: "#f04848"      // only for critical notifications
    readonly property color green: accent
    // highlights ("current", today, links) are all mint now, so the cards match the island
    readonly property color yellow: accent
    readonly property color blue: accent
    readonly property color purple: accent
    readonly property color cyan: accent
    readonly property color hover: Qt.tint("#141211", Qt.alpha(accent, 0.05))         // row hover
    readonly property color hoverStrong: Qt.tint("#201b1a", Qt.alpha(accent, 0.08))   // button hover, selected rows

    readonly property string font: "Inter"                        // all text
    readonly property string iconFont: "JetBrainsMono Nerd Font"  // icons
    readonly property int fontSize: 17

    // Nerd Font icons by codepoint (typing them directly risks them getting lost)
    function icon(cp) { return String.fromCodePoint(cp) }
    // an icon inside a sentence (rich text), so the words stay in Inter
    function iconHtml(cp) { return "<span style=\"font-family:'" + iconFont + "'\">" + icon(cp) + "</span>" }

    // keep the default speaker/mic objects live so volume + mute stay up to date
    PwObjectTracker { objects: [ Pipewire.defaultAudioSink, Pipewire.defaultAudioSource ] }
    readonly property var sink: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var source: Pipewire.defaultAudioSource?.audio ?? null

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ---------- settings state: $XDG_STATE_HOME/bar/settings.json ----------
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/bar"
    readonly property var prefs: prefsAdapter
    property bool prefsReady: false
    Process { running: true; command: ["mkdir", "-p", root.stateDir + "/theme"] }
    FileView {
        path: root.stateDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // (this also runs whenever the file changes, including our own saves: the startup
            // part only once, or a reload mid-fade would put the old color back)
            if (root.prefsReady) return
            if (prefsAdapter.accent) root.accent = prefsAdapter.accent   // last wallpaper's, no mint flash
            root.prefsReady = true
            root.writeTerminalTheme(prefsAdapter.accent || root.accent)  // make sure the files exist
        }
        onLoadFailed: {
            writeAdapter()   // first run: create it with the defaults below
            root.prefsReady = true
        }
        JsonAdapter {
            id: prefsAdapter
            property string musicFolder: ""       // empty = the user's Music folder
            property real musicVolume: 1          // local music volume, 0..1, kept across restarts
            property string accent: ""            // the accent picked from the last wallpaper
            property string wallpaper: ""         // the picture on the desktop ("" = plain black)
            property string wallpaperFolder: ""   // what Super+W shows ("" = ~/Pictures)
        }
    }

    // the user's Music folder, from the standard XDG user-dirs file
    property string musicDir: home + "/Music"
    function userDir(contents, key) {
        const m = contents.match(new RegExp('^XDG_' + key + '_DIR="((?:\\\\[\\s\\S]|[^"\\\\])*)"[ \\t]*(?:#.*)?$', "m"))
        if (!m) return ""
        let value = m[1], result = ""
        const prefix = value.match(/^\$(?:HOME|\{HOME\})(?=\/|$)/)
        if (prefix) { result = home; value = value.slice(prefix[0].length) }
        // Decode double-quoted shell escapes, without expanding variables or commands.
        for (let i = 0; i < value.length; i++) {
            const c = value[i]
            if (c === "\\" && i + 1 < value.length) {
                const next = value[++i]
                if (next === "\n") continue
                result += '\\"$`'.includes(next) ? next : "\\" + next
            } else if (c === "$" || c === "`") return ""
            else result += c
        }
        return result.startsWith("/") ? result : ""
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/user-dirs.dirs"
        onLoaded: root.musicDir = root.userDir(text(), "MUSIC") || root.musicDir
    }
    readonly property string musicFolder: prefs.musicFolder || musicDir

    // ---------- media ----------
    // Local music (MusicPlayer.qml) plus every MPRIS player that has a track. Which one the bar
    // and the media card show is sticky, because players blink "not playing" for a moment
    // between songs and after seeks:
    //  - the one you picked in the card stays until a different player starts playing
    //  - otherwise the shown one stays while it plays, or while nothing plays
    //  - moving to another player that plays happens after 1.5s, so blinks don't flip it
    MusicPlayer { id: musicPlayer; shell: root }
    readonly property var music: musicPlayer
    property var mediaPick: null
    property var mediaShown: null
    readonly property var mediaList: (music.active ? [music] : [])
        .concat(Mpris.players.values.filter(p => p.trackTitle !== ""))
    readonly property var mediaWanted: {
        const list = mediaList, cur = mediaShown
        if (mediaPick && list.includes(mediaPick)) return mediaPick
        const curOk = !!cur && list.includes(cur)
        if (curOk && (cur.isPlaying || !list.some(p => p.isPlaying))) return cur
        return list.find(p => p.isPlaying) ?? (curOk ? cur : list[0]) ?? null
    }
    // (applied a tick later: mediaWanted reads mediaShown, setting it inside would loop)
    function showWanted() { mediaShown = mediaWanted }
    onMediaWantedChanged: {
        if (!mediaShown || !mediaList.includes(mediaShown) || mediaWanted === mediaPick) {
            mediaSwitch.stop()
            Qt.callLater(showWanted)
        } else mediaSwitch.restart()
    }
    Timer { id: mediaSwitch; interval: 1500; onTriggered: root.showWanted() }
    readonly property var media: mediaShown && mediaList.includes(mediaShown) ? mediaShown : mediaWanted
    // cover art for a player: its own, else the YouTube thumbnail built from the video link
    // (Firefox sends no art for YouTube), else "" (then the player app's logo shows instead).
    // big: YouTube's 1280x720 one (not every video has it) instead of the 320x180 one.
    // A track looked up on YouTube (lookupArt) wins over the player's own tiny cover.
    function mediaArt(p, big) {
        if (!p) return ""
        const thumb = id => "https://i.ytimg.com/vi/" + id + (big ? "/maxresdefault.jpg" : "/mqdefault.jpg")
        const found = p !== music ? artIds[artKey(p)] : ""
        if (found) return thumb(found)
        if (p.trackArtUrl) return p.trackArtUrl
        const url = String(p.metadata?.["xesam:url"] ?? "")
        const m = url.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|shorts\/|live\/|embed\/)|youtu\.be\/)([\w-]{11})/)
        return m ? thumb(m[1]) : ""
    }

    // HD covers for players that send only a tiny cover and no link (Chromium/Helium send
    // ~150px ones): look the track up on YouTube by title + artist (the channel) with yt-dlp
    // and use that video's thumbnails. The music card asks for it only when its cover is small
    // or missing; one search at a time, each track once.
    property var artIds: ({})   // "title\nartist" -> YouTube video id ("" = nothing found)
    function artKey(p) { return p ? (p.trackTitle || "") + "\n" + (p.trackArtist || "") : "" }
    function lookupArt(p) {
        const key = artKey(p)
        if (!p || p === music || !p.trackTitle || key in artIds) return
        if (artSearch.running) { if (artSearch.forKey !== key) artSearch.next = p; return }
        artSearch.forKey = key
        artSearch.command = ["yt-dlp", "--no-warnings", "--flat-playlist", "--print", "id",
            "ytsearch1:" + p.trackTitle + " " + (p.trackArtist || "")]
        artSearch.running = true
    }
    Process {
        id: artSearch
        property string forKey: ""
        property var next: null
        stdout: StdioCollector {
            onStreamFinished: {
                const id = this.text.trim().split("\n")[0] || ""
                const ids = Object.assign({}, root.artIds)
                ids[artSearch.forKey] = /^[\w-]{11}$/.test(id) ? id : ""
                root.artIds = ids
            }
        }
        onExited: if (next) { const p = next; next = null; Qt.callLater(() => root.lookupArt(p)) }
    }
    // the player app's logo (Firefox, Spotify...), for tracks without any art
    function mediaAppIcon(p) {
        const id = p?.desktopEntry || p?.identity || ""
        const e = id ? DesktopEntries.heuristicLookup(id) : null
        return e?.icon ? Quickshell.iconPath(e.icon, true) : ""
    }
    // a different player starting to play ends your pick
    function playerStarted(p) { if (mediaPick && p !== mediaPick) mediaPick = null }
    Connections { target: root.music; function onIsPlayingChanged() { if (root.music.isPlaying) root.playerStarted(root.music) } }
    Variants {
        model: Mpris.players.values
        Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) root.playerStarted(modelData) }
        }
    }

    // ---------- the wallpaper, and colors from it ----------
    // Kept in settings.json; the bar draws it (wallWindow, per screen), Super+W changes it,
    // `qs ipc call wallpaper set <file>` too. The bar samples it (wallSampler, in the first
    // screen's bar) and takes its most vivid color as the accent, made readable on black.
    readonly property string wallpaper: prefsReady ? prefs.wallpaper : ""
    readonly property string wallpaperFolder: prefs.wallpaperFolder || home + "/Pictures"
    function setWallpaper(path) { prefs.wallpaper = path }
    function luminance(c) {
        const f = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    // d = RGBA pixels of the shrunken wallpaper. Hues go into 10° bins weighted by
    // saturation² × brightness, so a vivid patch beats a big dull area; the winning bin's
    // average color is then made readable. Muted wallpapers keep a muted accent (a soft slate,
    // sage...), vivid ones a vivid one. null = a truly grey wallpaper.
    function pickAccent(d) {
        const bins = []
        for (let k = 0; k < 36; k++) bins.push({ w: 0, r: 0, g: 0, b: 0 })
        for (let i = 0; i < d.length; i += 4) {
            const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255
            const max = Math.max(r, g, b), c = max - Math.min(r, g, b)
            const s = max === 0 ? 0 : c / max
            if (s < 0.08 || max < 0.12) continue
            let h = max === r ? ((g - b) / c) % 6 : max === g ? (b - r) / c + 2 : (r - g) / c + 4
            h = (h * 60 + 360) % 360
            const w = s * s * max, bin = bins[Math.floor(h / 10) % 36]
            bin.w += w; bin.r += r * w; bin.g += g * w; bin.b += b * w
        }
        let best = -1, bestW = 0
        for (let k = 0; k < 36; k++) {
            // a hue sitting on a bin edge still wins: count half of each neighbour
            const w = bins[k].w + 0.5 * (bins[(k + 35) % 36].w + bins[(k + 1) % 36].w)
            if (w > bestW) { bestW = w; best = k }
        }
        if (best < 0 || bestW < d.length / 4 * 0.0006) return null
        const bin = bins[best]
        const avg = Qt.rgba(bin.r / bin.w, bin.g / bin.w, bin.b / bin.w, 1)
        // readable as text on black, and dark text on it stays readable too
        const sat = Math.max(0.28, Math.min(0.8, avg.hslSaturation * 1.6))
        let light = 0.62, out = Qt.hsla(avg.hslHue, sat, light, 1)
        while (luminance(out) < 0.32 && light < 0.86) { light += 0.02; out = Qt.hsla(avg.hslHue, sat, light, 1) }
        return out
    }
    function applyAccent(c) {
        const col = c ?? Qt.color("#d6cfc7")   // grey wallpaper: a soft warm white
        prefs.accent = col.toString()           // (accent itself is mid-fade right after this)
        accent = col
        writeTerminalTheme(col)
    }

    // ---------- terminal colors (follow the accent too) ----------
    // Written to $XDG_STATE_HOME/bar/theme/: foot.ini (foot includes it), alacritty.toml (alacritty
    // imports it and reloads by itself), fzf, starship.toml (dotfiles/starship.toml with the accent
    // swapped in), fish.fish (fish loads it: colors.fish; it also sets EZA_COLORS, so ls/ll show
    // folders and your user in the accent). Then the universal variable bar_theme
    // tells every open fish to reload it, which also recolors its terminal on the spot (OSC 11/12/17).
    // Only the glass tint, cursor, selection and highlights follow; the 16 ANSI colors stay fixed.
    readonly property string themeDir: stateDir + "/theme"
    // One sh writes all the files (each atomically: temp file + mv), and only then tells the
    // shells to reload, so they never see half the files or the old ones. (FileView.setText
    // dropped writes after the first one, which left terminals on the previous wallpaper.)
    // A change that comes in while it runs waits and runs right after.
    Process {
        id: themeWriter
        property var pending: null
        onExited: if (pending) { const next = pending; pending = null; Qt.callLater(() => { command = next; running = true }) }
    }
    function writeFiles(files) {
        const cmd = ["sh", "-c", 'while [ $# -ge 2 ]; do printf "%s" "$2" > "$1.tmp" && mv -f "$1.tmp" "$1"; shift 2; done; '
            + 'fish -c "set -U bar_theme $(date +%s%N)"', "sh"]
        for (const f of files) cmd.push(f[0], f[1])
        if (themeWriter.running) themeWriter.pending = cmd
        else { themeWriter.command = cmd; themeWriter.running = true }
    }
    // your normal prompt config (starship's standard place), with the accent swapped in
    FileView { id: starshipBase; path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/starship.toml"; watchChanges: true; printErrors: false; onFileChanged: reload() }
    function writeTerminalTheme(acc) {
        acc = Qt.color(acc)
        const h = Math.max(0, acc.hslHue), s = acc.hslSaturation
        const hex = c => c.toString().slice(1)
        const a = hex(acc)
        const b = hex(Qt.hsla(h, Math.min(s, 0.55), 0.035, 1))   // the glass: a very dark tint
        const l = hex(Qt.hsla(h, Math.min(s, 0.4), 0.15, 1))     // selection
        const rgb = [acc.r, acc.g, acc.b].map(v => Math.round(v * 255)).join(";")   // for EZA_COLORS
        const head = "# Written by the bar (shell.qml, \"terminal colors\"): follows the wallpaper. Edits get replaced.\n"
        const files = []
        const t = root.themeDir + "/"
        // GTK3 apps (adw-gtk3's named colors; ~/.config/gtk-3.0/gtk.css imports this): dark
        // backgrounds tinted toward the wallpaper, the accent for selections and buttons
        const tint = l => "#" + hex(Qt.hsla(h, Math.min(s, 0.45), l, 1))
        files.push([t + "gtk3.css", "/* Written by the bar (shell.qml, \"terminal colors\"): follows the wallpaper. */\n"
            + "@define-color accent_color #" + a + ";\n@define-color accent_bg_color #" + a + ";\n"
            + "@define-color accent_fg_color #000000;\n"
            + "@define-color window_bg_color " + tint(0.075) + ";\n@define-color window_fg_color #e6e1d8;\n"
            + "@define-color view_bg_color " + tint(0.055) + ";\n@define-color view_fg_color #e6e1d8;\n"
            + "@define-color headerbar_bg_color " + tint(0.09) + ";\n@define-color headerbar_fg_color #e6e1d8;\n"
            + "@define-color headerbar_backdrop_color " + tint(0.075) + ";\n"
            + "@define-color sidebar_bg_color " + tint(0.085) + ";\n@define-color sidebar_fg_color #e6e1d8;\n"
            + "@define-color card_bg_color alpha(#ffffff, 0.04);\n"
            + "@define-color popover_bg_color " + tint(0.11) + ";\n@define-color popover_fg_color #e6e1d8;\n"
            + "@define-color dialog_bg_color " + tint(0.09) + ";\n@define-color dialog_fg_color #e6e1d8;\n"])
        files.push([t + "foot.ini", head + "[colors-dark]\nbackground=" + b + "\nselection-background=" + l + "\ncursor=" + b + " " + a + "\n"])
        files.push([t + "alacritty.toml", head + "[colors.primary]\nbackground = \"#" + b + "\"\n\n[colors.cursor]\ntext = \"#" + b
            + "\"\ncursor = \"#" + a + "\"\n\n[colors.selection]\ntext = \"#e6e1d8\"\nbackground = \"#" + l + "\"\n"])
        files.push([t + "fzf", "--color=bg+:#" + l + ",hl:#" + a + ",hl+:#" + a + ",marker:#" + a + ",prompt:#" + a
            + ",spinner:#" + a + ",pointer:#" + a + "\n"])
        const base = starshipBase.text()
        if (base) files.push([t + "starship.toml", base.replace(/^accent = ".*"$/m, 'accent = "#' + a + '"')])
        files.push([t + "fish.fish", head
            + "set -g fish_color_command " + a + "\n"
            + "set -g fish_pager_color_prefix " + a + " --bold\n"
            + "set -g fish_color_selection --background=" + l + "\n"
            + "set -g fish_color_search_match --background=" + l + "\n"
            + "set -g fish_pager_color_selected_background --background=" + l + "\n"
            + "test -f " + root.themeDir + "/starship.toml; and set -gx STARSHIP_CONFIG " + root.themeDir + "/starship.toml\n"
            + "set -gx FZF_DEFAULT_OPTS_FILE " + root.themeDir + "/fzf\n"
            + "# fetch's mug: lit, base and shadow shades of the accent\n"
            + "set -g bar_accent_shades " + hex(Qt.hsla(h, s, Math.min(0.84, acc.hslLightness + 0.12), 1)) + " " + a + " "
                + hex(Qt.hsla(h, s * 0.85, acc.hslLightness * 0.55, 1)) + "\n"
            + "# eza (ls, ll, la, lt): folders bold in the accent, your user in ll too\n"
            + "set -gx EZA_COLORS 'di=1;38;2;" + rgb + ":uu=38;2;" + rgb + "'\n"
            + "# recolor this terminal right away: background (foot keeps its 82% glass), cursor, selection\n"
            + "if status is-interactive; and isatty stdout\n"
            + "    switch $TERM\n"
            + "        case 'foot*'\n"
            + "            printf '\\e]11;[82]#" + b + "\\a\\e]12;#" + a + "\\a\\e]17;#" + l + "\\a'\n"
            + "        case '*'\n"
            + "            printf '\\e]11;#" + b + "\\a\\e]12;#" + a + "\\a\\e]17;#" + l + "\\a'\n"
            + "    end\n"
            + "end\n"])
        writeFiles(files)
    }

    // Hyprland commands: the new Lua config (hyprland.lua) takes them as Lua, the classic
    // hyprland.conf as plain dispatcher text, so send whichever this machine uses
    property bool hyprLua: false
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || root.home + "/.config") + "/hypr/hyprland.lua"
        printErrors: false
        onLoaded: root.hyprLua = true
    }
    function hyprDispatch(lua, classic) { Hyprland.dispatch(hyprLua ? lua : classic) }

    // app launcher (Launcher.qml), Super+D; wallpaper picker (WallpaperPicker.qml), Super+W
    Launcher { id: launcher; shell: root }
    WallpaperPicker { id: wallPicker; shell: root }
    function pickWallpaper() { wallPicker.open = true }
    // `qs ipc call wallpaper pick`
    IpcHandler {
        target: "wallpaper"
        function pick(): void { wallPicker.toggle() }
        function close(): void { wallPicker.open = false }
        function set(path: string): void { root.setWallpaper(path) }
        function get(): string { return root.wallpaper }
    }

    // `qs ipc call media playPause|next|previous` (the media keys, see hyprland.lua)
    IpcHandler {
        target: "media"
        function playPause(): void { if (root.media) root.media.togglePlaying(); else root.music.togglePlaying() }
        function next(): void { if (root.media?.canGoNext) root.media.next() }
        function previous(): void { if (root.media?.canGoPrevious) root.media.previous() }
        function playTrack(index: int): void { root.music.play(index) }
        function open(): void { root.mediaCardRequest++ }
    }
    property int mediaCardRequest: 0   // bumped by `qs ipc call media open`

    // `qs ipc call bar card <calendar|audio|network|media|notifications>` opens (or closes) that
    // card on the focused monitor; `qs ipc call bar close` closes it
    property string cardName: ""
    property int cardRequest: 0
    IpcHandler {
        target: "bar"
        function card(name: string): void { root.cardName = name; root.cardRequest++ }
        function close(): void { root.cardName = ""; root.cardRequest++ }
    }

    // first connected wired/Wi-Fi device (null = offline)
    readonly property var netDevice: Networking.devices.values.find(d =>
        d.connected && (d.type === DeviceType.Wired || d.type === DeviceType.Wifi)) ?? null

    // Watchdog: when NetworkManager restarts (e.g. a rebuild that changes network settings),
    // Quickshell's networking module loses its devices and never gets them back; only a
    // fresh start fixes it. Every 15s compare with nmcli; if NetworkManager says we're
    // connected but the module has no device twice in a row, restart the bar.
    property int netMismatch: 0
    onNetDeviceChanged: if (netDevice) netMismatch = 0
    Process {
        id: nmCheck
        environment: ({ LC_ALL: "C" })
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nmOnline = this.text.split("\n").some(l => /^(ethernet|wifi):connected$/.test(l.trim()))
                if (nmOnline && !root.netDevice) {
                    if (++root.netMismatch >= 2) {
                        console.warn("networking module lost NetworkManager's devices, restarting the bar")
                        Quickshell.execDetached(["sh", "-c", "sleep 1; exec qs -d"])
                        Qt.quit()
                    }
                } else root.netMismatch = 0
            }
        }
    }
    Timer { interval: 15000; running: root.netDevice === null; repeat: true; onTriggered: if (!nmCheck.running) nmCheck.running = true }

    // ---------- notifications ----------
    // Lists only hold plain JS copies. A live Notification object gets destroyed when the
    // app closes it, and reading a destroyed one from a model crashes Quickshell (Omarchy's
    // lesson). The live objects sit in a map, only used to invoke actions / dismiss.
    property var popups: []      // on screen now
    property var history: []     // notification center, newest first
    property var live: ({})      // id -> Notification
    onHistoryChanged: Qt.callLater(pruneLive)
    onPopupsChanged: Qt.callLater(pruneLive)
    property bool dnd: false     // Do Not Disturb: no popups, still logged
    // Fullscreen on the focused workspace: no popups either (critical ones still show).
    // Any mapped Overlay-layer surface makes Hyprland drop a fullscreen game out of
    // tearing / direct scanout, so a toast would cost latency. They still land in
    // history; toasts already up are pulled when fullscreen starts, nothing replays after.
    readonly property bool fullscreenFocused: Hyprland.focusedWorkspace?.hasFullscreen ?? false
    onFullscreenFocusedChanged: if (fullscreenFocused) popups = popups.filter(p => p.critical)

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => root.addNotification(n)
    }

    function addNotification(n) {
        n.tracked = true
        const o = {
            id: n.id, appName: n.appName, summary: n.summary, body: n.body,
            icon: notificationIcon(n.image, n.appIcon),
            critical: n.urgency === NotificationUrgency.Critical,
            actions: n.actions.map(a => ({ id: a.identifier, text: a.text })),
            // milliseconds (Quickshell 0.3.1's docs say seconds, but it passes the app's ms through)
            timeout: n.expireTimeout > 0 ? n.expireTimeout : 5000,
            time: Date.now()
        }
        live[o.id] = n
        n.closed.connect(() => { delete root.live[o.id]; root.hidePopup(o.id) })
        // an app can replace its notification (same id): drop the old copy
        history = [o].concat(history.filter(h => h.id !== o.id)).slice(0, 50)
        if (!dnd && (o.critical || !fullscreenFocused))
            popups = popups.filter(p => p.id !== o.id).concat([o]).slice(-5)
    }
    function notificationIcon(image, appIcon) {
        if (image) return image
        if (!appIcon) return ""
        if (appIcon.startsWith("/") || appIcon.includes("://")) return appIcon
        return Quickshell.iconPath(appIcon, true)
    }
    function hidePopup(id) { popups = popups.filter(p => p.id !== id) }
    function pruneLive() {
        const keep = new Set(history.map(h => h.id).concat(popups.map(p => p.id)))
        for (const key of Object.keys(live)) {
            if (keep.has(Number(key))) continue
            const n = live[key]
            delete live[key]
            try { n?.expire() } catch (e) {}
        }
    }
    function dismissNotification(id) {
        try { live[id]?.dismiss() } catch (e) {}
        hidePopup(id)
        history = history.filter(h => h.id !== id)
    }
    function invokeAction(id, actionId) {
        try { live[id]?.actions.find(a => a.identifier === actionId)?.invoke() } catch (e) {}
        hidePopup(id)
    }
    function clearNotifications() {
        const old = Object.values(live)
        live = ({})
        history = []; popups = []
        for (const n of old) { try { n?.dismiss() } catch (e) {} }
    }
    function ago(t) {
        const m = Math.floor((clock.date - t) / 60000)
        return m < 1 ? "now" : m < 60 ? m + "m" : Math.floor(m / 60) + "h"
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors { top: true; left: true; right: true }
            WlrLayershell.namespace: "bar"
            // tall enough for the island grown into its biggest card, but windows only make room
            // for the small pill (the rest is see-through and click-through, see mask)
            implicitHeight: 760
            exclusiveZone: 52
            color: "transparent"
            // only the island takes clicks/hover; the rest of the strip passes through to windows
            mask: Region { item: island }
            // only the music card has a text box (search / download link)
            WlrLayershell.keyboardFocus: dropdown.open === "media" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            // workspaces of the monitor this bar is on, normal ones only (no special/scratchpad)
            readonly property var monitor: Hyprland.monitorFor(modelData)
            readonly property var workspaces: Hyprland.workspaces.values
                .filter(w => w.id > 0 && w.monitor === monitor)
                .sort((a, b) => a.id - b.id)
            // slots 1..5 always (more if a higher one is open): a capsule for the focused one,
            // brighter dots for the ones with windows, faint dots for empty ones
            readonly property var slots: {
                const last = workspaces.length ? workspaces[workspaces.length - 1].id : 0
                const out = []
                for (let i = 1; i <= Math.max(5, last); i++) out.push(i)
                return out
            }

            // the focused app, for the expanded island
            readonly property var activeApp: ToplevelManager.activeToplevel
            readonly property var activeEntry: activeApp?.appId ? DesktopEntries.heuristicLookup(activeApp.appId) : null

            // ---------- shared pieces (used small in the pill, bigger in the island) ----------
            Component {
                id: wsDots
                Row {
                    spacing: 6
                    Repeater {
                        model: bar.slots
                        Item {
                            id: slot
                            required property int modelData
                            readonly property var ws: bar.workspaces.find(w => w.id === modelData) ?? null
                            readonly property bool focused: ws?.focused ?? false
                            readonly property bool urgent: ws?.urgent ?? false
                            width: focused ? 10 : 7
                            height: 22
                            Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: slot.focused ? 20 : 7
                                radius: width / 2
                                color: slot.urgent ? root.red
                                    : slot.focused ? root.accent
                                    : Qt.alpha(root.accent, slot.ws ? 0.45 : 0.16)
                                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { dropdown.open = ""; root.hyprDispatch("hl.dsp.focus({ workspace = " + slot.modelData + " })", "workspace " + slot.modelData) }
                            }
                        }
                    }
                }
            }
            // network: signal bars (Wi-Fi strength, or all four when wired). click = network card
            Component {
                id: netBarsComp
                Item {
                    id: netBars
                    readonly property bool wifi: root.netDevice?.type === DeviceType.Wifi
                    readonly property int level: !root.netDevice ? 0
                        : wifi ? Math.max(1, Math.ceil((root.netDevice.network?.signalStrength ?? 1) * 4)) : 4
                    implicitWidth: 4 * 3 + 3 * 2
                    implicitHeight: 14
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            x: index * 5
                            anchors.bottom: parent.bottom
                            width: 3
                            height: 5 + index * 3
                            radius: 1.5
                            color: !root.netDevice ? Qt.alpha(root.red, index === 0 ? 1 : 0.3)
                                : index < netBars.level ? root.accent : Qt.alpha(root.accent, 0.25)
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dropdown.toggleAt("network", parent)
                    }
                }
            }
            // volume: click = audio card, middle click = mute, scroll = level
            Component {
                id: volumeComp
                Text {
                    readonly property bool muted: root.sink?.muted ?? true
                    readonly property real level: root.sink?.volume ?? 0
                    text: root.icon(muted ? 0xF075F : level < 0.34 ? 0xF057F : level < 0.67 ? 0xF0580 : 0xF057E)
                    color: muted ? root.red : root.accent
                    font { family: root.iconFont; pixelSize: 17 }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) { if (root.sink) root.sink.muted = !root.sink.muted }
                            else dropdown.toggleAt("audio", parent)
                        }
                        onWheel: wheel => {
                            if (!root.sink) return
                            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                            root.sink.volume = Math.max(0, Math.min(1, root.sink.volume + step))
                        }
                    }
                }
            }
            // mic: only when muted (a red slashed mic). click = audio card, middle click = unmute
            Component {
                id: micComp
                Text {
                    text: root.icon(0xF036D)
                    color: root.red
                    font { family: root.iconFont; pixelSize: 17 }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) { if (root.source) root.source.muted = false }
                            else dropdown.toggleAt("audio", parent)
                        }
                    }
                }
            }
            // tray: left click = open app, right click = its menu (our own, see trayMenu)
            Component {
                id: trayComp
                Row {
                    spacing: 10
                    Repeater {
                        model: SystemTray.items
                        Image {
                            id: trayIcon
                            required property var modelData
                            source: modelData.icon
                            sourceSize { width: 16; height: 16 }
                            width: 16; height: 16
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if ((mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu) && trayIcon.modelData.hasMenu)
                                        trayMenu.openFor(trayIcon.modelData, trayIcon.mapToItem(null, trayIcon.width / 2, 0).x)
                                    else
                                        trayIcon.modelData.activate()
                                }
                            }
                        }
                    }
                }
            }
            // battery: only on machines that have one. A filled capsule, red under 15% unless charging
            readonly property bool hasBattery: UPower.displayDevice?.isLaptopBattery ?? false

            // ---------- the wallpaper ----------
            // A background layer with two pictures: a new wallpaper loads into the hidden one and
            // fades in over the old one, then they swap. Decoded at screen size, not full size.
            PanelWindow {
                id: wallWindow
                screen: bar.screen
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Background
                WlrLayershell.namespace: "bar-wallpaper"
                color: "#000000"

                property var front: wallA
                readonly property var back: front === wallA ? wallB : wallA
                readonly property string target: root.wallpaper ? Paths.toFileUrl(root.wallpaper) : ""
                onTargetChanged: load()
                Component.onCompleted: load()
                // (each picture remembers the url it was asked for: Image.source reads back decoded,
                // "Snowy Neon.png" instead of "Snowy%20Neon.png", so comparing that never matched)
                function load() {
                    if (wallFade.running) wallFade.complete()
                    if (front.want === target && front.opacity === 1) return
                    back.opacity = 0
                    back.want = target
                    back.source = target
                    if (!target) wallFade.fadeOutFront()
                }
                function ready(img) {
                    if (img !== back || img.status !== Image.Ready || img.want !== target) return
                    img.z = 1; front.z = 0
                    wallFade.target = img
                    wallFade.restart()
                }
                NumberAnimation {
                    id: wallFade
                    property: "opacity"
                    from: 0; to: 1
                    duration: 650
                    easing.type: Easing.InOutQuad
                    function fadeOutFront() { wallWindow.front.opacity = 0; wallWindow.front.want = ""; wallWindow.front.source = "" }
                    onFinished: {
                        const old = wallWindow.front
                        wallWindow.front = wallFade.target
                        old.opacity = 0
                        old.want = ""
                        old.source = ""
                    }
                }
                Image {
                    id: wallA
                    property string want: ""
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(bar.screen.width, bar.screen.height)
                    asynchronous: true
                    cache: false
                    opacity: 0
                    onStatusChanged: wallWindow.ready(wallA)
                }
                Image {
                    id: wallB
                    property string want: ""
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(bar.screen.width, bar.screen.height)
                    asynchronous: true
                    cache: false
                    opacity: 0
                    onStatusChanged: wallWindow.ready(wallB)
                }
            }

            // the wallpaper, drawn tiny to pick the accent from (first screen only; never shown).
            // Decoded straight at 64×36, so a 4K wallpaper doesn't take 30+ MB for a moment.
            Canvas {
                id: wallSampler
                readonly property bool active: bar.modelData === Quickshell.screens[0]
                width: 64; height: 36
                opacity: 0
                property string url: ""
                function sample() {
                    if (url) unloadImage(url)
                    url = active && root.wallpaper ? Paths.toFileUrl(root.wallpaper) : ""
                    if (!url) return
                    loadImage(url, Qt.size(width, height))
                    if (isImageLoaded(url)) requestPaint()
                }
                onImageLoaded: requestPaint()
                onPaint: {
                    if (!url || !isImageLoaded(url)) return
                    const ctx = getContext("2d")
                    ctx.drawImage(url, 0, 0, width, height)
                    root.applyAccent(root.pickAccent(ctx.getImageData(0, 0, width, height).data))
                    unloadImage(url)
                    url = ""
                }
                Connections { target: root; function onWallpaperChanged() { wallSampler.sample() } }
                Component.onCompleted: sample()
            }
            Component {
                id: batteryComp
                Item {
                    readonly property var dev: UPower.displayDevice
                    readonly property real frac: Math.max(0, Math.min(1, dev?.percentage ?? 0))
                    readonly property bool charging: dev?.state === UPowerDeviceState.Charging
                    readonly property color tint: frac < 0.15 && !charging ? root.red : root.accent
                    implicitWidth: 27
                    implicitHeight: 13
                    Rectangle {
                        id: battBody
                        width: 24; height: 13; radius: 4.5
                        color: "transparent"
                        border { color: Qt.alpha(parent.tint, 0.45); width: 1 }
                        Rectangle {
                            x: 2; y: 2
                            width: Math.max(4, (parent.width - 4) * parent.parent.frac)
                            height: parent.height - 4
                            radius: 2.5
                            color: parent.parent.tint
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Rectangle {
                        anchors { left: battBody.right; leftMargin: 1; verticalCenter: battBody.verticalCenter }
                        width: 2; height: 5; radius: 1
                        color: Qt.alpha(parent.tint, 0.45)
                    }
                }
            }

            // ---------- the island: a pill that grows into a panel on hover ----------
            Rectangle {
                id: island
                // hover opens it right away; leaving closes it after a moment (so a brief slip off
                // the edge doesn't); opening a card (calendar, audio...) closes it
                property bool expanded: false
                readonly property bool hovered: islandHover.hovered
                onHoveredChanged: {
                    if (hovered && dropdown.open === "") { collapseTimer.stop(); expanded = true }
                    else collapseTimer.restart()
                }
                Timer { id: collapseTimer; interval: 220; onTriggered: island.expanded = false }
                Connections {
                    target: dropdown
                    function onOpenChanged() { if (dropdown.open !== "") island.expanded = false }
                }
                HoverHandler { id: islandHover }

                // the open card (it decides the island's size while open)
                readonly property var panelItem: ({ calendar: calendar, audio: audioPanel, network: networkCard,
                    tray: trayMenu, media: mediaCard, notifications: notifCenter })[dropdown.open] ?? null

                anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
                width: panelItem ? Math.max(small.implicitWidth + 36, panelItem.width + 32)
                    : expanded ? Math.max(720, big.implicitWidth + 56) : small.implicitWidth + 36
                height: panelItem ? 44 + panelItem.height + 16
                    : expanded ? 136 : 36
                radius: panelItem || expanded ? 30 : 18
                color: root.bgDark
                border { color: root.bgAlt; width: 1 }
                clip: true
                Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on radius { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                MouseArea { anchors { top: parent.top; left: parent.left; right: parent.right } height: 36; onClicked: dropdown.open = "" }

                // ----- small: workspaces · clock · status (also the header while a card is open) -----
                RowLayout {
                    id: small
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: (36 - implicitHeight) / 2 }
                    spacing: 22
                    opacity: island.expanded ? 0 : 1
                    scale: island.expanded ? 0.9 : 1
                    visible: opacity > 0
                    enabled: !island.expanded
                    Behavior on opacity { NumberAnimation { duration: island.expanded ? 80 : 220; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Loader { sourceComponent: wsDots; Layout.alignment: Qt.AlignVCenter }

                    // clock (click = calendar)
                    Text {
                        id: clockText
                        Layout.alignment: Qt.AlignVCenter
                        text: Qt.formatDateTime(clock.date, "HH:mm")
                        color: calendar.visible ? root.accent : root.fg
                        font { family: root.font; pixelSize: 16; weight: Font.DemiBold; features: { "tnum": 1 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dropdown.toggle("calendar")
                        }
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 12
                        Loader { sourceComponent: trayComp; visible: SystemTray.items.values.length > 0; Layout.alignment: Qt.AlignVCenter }
                        // media: shown while something has a track. click = media card,
                        // middle click = play/pause, scroll = next/previous
                        Text {
                            id: mediaButton
                            visible: root.media !== null
                            text: root.icon(root.media?.isPlaying ? 0xF03E4 : 0xF075A)
                            color: dropdown.open === "media" ? root.fg : root.accent
                            font { family: root.iconFont; pixelSize: 17 }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                property real lastWheel: 0
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) root.media?.togglePlaying()
                                    else dropdown.toggleAt("media", parent)
                                }
                                onWheel: wheel => {
                                    // one skip per gesture: touchpads send many small wheel events
                                    const now = Date.now()
                                    if (!root.media || now - lastWheel < 400) return
                                    lastWheel = now
                                    if (wheel.angleDelta.y < 0) { if (root.media.canGoNext) root.media.next() }
                                    else if (root.media.canGoPrevious) root.media.previous()
                                }
                            }
                        }
                        // notifications: a bell with a dot, only when there are some (or Do Not Disturb)
                        Text {
                            visible: root.history.length > 0 || root.dnd
                            text: root.icon(root.dnd ? 0xF009B : 0xF009A)
                            color: root.dnd ? root.red : root.accent
                            font { family: root.iconFont; pixelSize: 17 }
                            Rectangle {
                                visible: !root.dnd
                                anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: 2 }
                                width: 6; height: 6; radius: 3
                                color: root.fg
                            }
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dropdown.toggleAt("notifications", parent)
                            }
                        }
                        Loader { sourceComponent: micComp; active: root.source?.muted ?? false; visible: active; Layout.alignment: Qt.AlignVCenter }
                        Loader { sourceComponent: netBarsComp; Layout.alignment: Qt.AlignVCenter }
                        Loader { sourceComponent: volumeComp; Layout.alignment: Qt.AlignVCenter }
                        Loader { sourceComponent: batteryComp; active: bar.hasBattery; visible: active; Layout.alignment: Qt.AlignVCenter }
                    }
                }

                // ----- panel: the open card, under the pill's row -----
                Item {
                    id: panelArea
                    anchors { top: parent.top; topMargin: 44; horizontalCenter: parent.horizontalCenter }
                    width: island.panelItem?.width ?? 0
                    height: island.panelItem?.height ?? 0


                Item {
                    id: calendar
                    visible: dropdown.open === "calendar"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: calBox.implicitWidth
                    height: calBox.implicitHeight
                    MouseArea { anchors.fill: parent } // clicks on the card don't close it

                    // always the current month
                    readonly property int year: clock.date.getFullYear()
                    readonly property int month: clock.date.getMonth()
                    readonly property int days: new Date(year, month + 1, 0).getDate()

                    Rectangle {
                        id: calBox
                        implicitWidth: calCol.implicitWidth + 28
                        implicitHeight: calCol.implicitHeight + 28
                        color: "transparent"

                        ColumnLayout {
                            id: calCol
                            anchors.centerIn: parent
                            spacing: 10

                            // full date
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                                color: root.fg
                                font { family: root.font; pixelSize: root.fontSize + 1; bold: true }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: Qt.formatDate(clock.date, "MMMM yyyy")
                                color: root.blue
                                font { family: root.font; pixelSize: root.fontSize; bold: true }
                            }

                            GridLayout {
                                columns: 7
                                rowSpacing: 4
                                columnSpacing: 4

                                // just this month: 1 in the top-left, 7 per row
                                Repeater {
                                    model: calendar.days
                                    Rectangle {
                                        required property int index
                                        readonly property int day: index + 1
                                        readonly property bool isToday: day === clock.date.getDate()
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 28
                                        radius: 6
                                        color: isToday ? root.yellow : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.day
                                            color: parent.isToday ? root.bg : root.fg
                                            font { family: root.font; pixelSize: root.fontSize; bold: parent.isToday }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: audioPanel
                    visible: dropdown.open === "audio"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 380
                    height: panelCol.implicitHeight + 32
                    MouseArea { anchors.fill: parent } // clicks on the card don't close it

                    // Device lists are snapshots, refreshed a moment after PipeWire changes and
                    // cleared while closed. Rebuilding straight from PipeWire's live list while a
                    // device is disappearing can crash Quickshell (same trick Omarchy uses).
                    property var sinks: []
                    property var sources: []
                    readonly property var liveNodes: Pipewire.nodes.values

                    function isAudio(n) { return !!n.audio || String(n.type).indexOf("Audio") >= 0 }
                    function refresh() {
                        const nodes = liveNodes.slice()
                        sinks = nodes.filter(n => n && n.isSink && !n.isStream && isAudio(n))
                        sources = nodes.filter(n => n && !n.isSink && !n.isStream && isAudio(n) && n.name !== "quickshell")
                    }
                    onLiveNodesChanged: if (visible) refreshTimer.restart()
                    onVisibleChanged: { if (visible) refresh(); else { refreshTimer.stop(); sinks = []; sources = [] } }
                    Timer { id: refreshTimer; interval: 75; onTriggered: audioPanel.refresh() }

                    PwObjectTracker { objects: audioPanel.sinks.concat(audioPanel.sources) }

                    function label(n) { return n.nickname || n.description || n.name || "Unknown" }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        ColumnLayout {
                            id: panelCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing: 18

                            Repeater {
                                model: ScriptModel {
                                    objectProp: "isOutput"
                                    comparisonMode: ObjectComparison.Identity
                                    values: [
                                        { title: "Output", isOutput: true,  node: Pipewire.defaultAudioSink,   devices: audioPanel.sinks,
                                          accent: root.cyan,   icon: 0xF057E, mutedIcon: 0xF075F },
                                        { title: "Input",  isOutput: false, node: Pipewire.defaultAudioSource, devices: audioPanel.sources,
                                          accent: root.purple, icon: 0xF036C, mutedIcon: 0xF036D }
                                    ]
                                }

                                ColumnLayout {
                                    id: section
                                    required property var modelData
                                    readonly property var audio: modelData.node?.audio ?? null
                                    readonly property bool muted: audio?.muted ?? true
                                    readonly property real level: audio?.volume ?? 0
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // header: icon (click = mute), title, percentage
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text {
                                            text: root.icon(section.muted ? section.modelData.mutedIcon : section.modelData.icon)
                                            color: section.muted ? root.red : section.modelData.accent
                                            font { family: root.iconFont; pixelSize: root.fontSize + 3 }
                                            MouseArea {
                                                anchors.fill: parent; anchors.margins: -6
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: if (section.audio) section.audio.muted = !section.audio.muted
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            Layout.leftMargin: 6
                                            text: section.modelData.title
                                            color: root.fg
                                            font { family: root.font; pixelSize: root.fontSize; bold: true }
                                        }
                                        Text {
                                            text: section.muted ? "muted" : Math.round(section.level * 100) + "%"
                                            color: section.muted ? root.red : root.dim
                                            font { family: root.font; pixelSize: root.fontSize }
                                        }
                                    }

                                    // slider: click or drag to set, scroll for 5% steps
                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 20
                                        readonly property real fill: Math.max(0, Math.min(1, section.level))

                                        Rectangle {
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                                            height: 6; radius: 3
                                            color: root.bgAlt
                                            Rectangle {
                                                width: parent.width * parent.parent.fill
                                                height: parent.height; radius: 3
                                                color: section.muted ? root.dim : section.modelData.accent
                                            }
                                        }
                                        Rectangle {
                                            x: parent.width * parent.fill - width / 2
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 14; height: 14; radius: 7
                                            color: root.fg
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            function setFrom(x) { if (section.audio) section.audio.volume = Math.max(0, Math.min(1, x / width)) }
                                            onPressed: mouse => setFrom(mouse.x)
                                            onPositionChanged: mouse => { if (pressed) setFrom(mouse.x) }
                                            onWheel: wheel => {
                                                if (!section.audio) return
                                                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                                section.audio.volume = Math.max(0, Math.min(1, section.audio.volume + step))
                                            }
                                        }
                                    }

                                    // devices: the current one is marked, click another to switch
                                    Repeater {
                                        model: ScriptModel { values: section.modelData.devices; comparisonMode: ObjectComparison.Identity }

                                        Rectangle {
                                            id: deviceRow
                                            required property var modelData
                                            readonly property bool current: section.modelData.node !== null
                                                && modelData.id === section.modelData.node.id
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: 6
                                            color: current ? root.bgAlt : (rowMouse.containsMouse ? root.hover : "transparent")

                                            RowLayout {
                                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                                spacing: 10
                                                Text {
                                                    text: deviceRow.current ? "●" : "○"
                                                    color: deviceRow.current ? root.yellow : root.dim
                                                    font { family: root.iconFont; pixelSize: root.fontSize - 2 }
                                                }
                                                Text {
                                                    Layout.fillWidth: true
                                                    text: audioPanel.label(deviceRow.modelData)
                                                    elide: Text.ElideRight
                                                    color: deviceRow.current ? root.fg : root.dim
                                                    font { family: root.font; pixelSize: root.fontSize - 1 }
                                                }
                                            }

                                            MouseArea {
                                                id: rowMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (section.modelData.isOutput) Pipewire.preferredDefaultAudioSink = deviceRow.modelData
                                                    else Pipewire.preferredDefaultAudioSource = deviceRow.modelData
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: section.modelData.devices.length === 0
                                        text: "no devices"
                                        color: root.dim
                                        font { family: root.font; pixelSize: root.fontSize - 1; italic: true }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- network card: connection + DNS provider ----------
                Item {
                    id: networkCard
                    visible: dropdown.open === "network"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 380
                    height: netCol.implicitHeight + 32
                    MouseArea { anchors.fill: parent } // clicks on the card don't close it

                    readonly property var providers: ["DHCP", "Cloudflare", "Google", "OpenDNS", "Custom"]
                    property string dns: ""        // what `dns` reports
                    property string pending: ""    // being applied right now
                    property string dnsError: ""
                    property string ip: ""

                    function refresh() {
                        dnsRead.running = true
                        if (root.netDevice) { ipRead.command = ["sh", "-c", "ip -4 -o addr show dev \"$1\" | awk '{print $4}' | head -1", "sh", root.netDevice.name]; ipRead.running = true }
                    }
                    function setDns(p) {
                        if (pending !== "") return
                        dnsError = ""
                        pending = p
                        dnsSet.command = p === "Custom"
                            ? ["foot", "--app-id", "dns", "-e", "dns", "Custom"]
                            : ["dns", p]
                        dnsSet.running = true
                    }
                    onVisibleChanged: if (visible) refresh()

                    Process { id: dnsRead; command: ["dns"]
                        stdout: StdioCollector { onStreamFinished: networkCard.dns = this.text.trim() } }
                    Process { id: ipRead
                        stdout: StdioCollector { onStreamFinished: networkCard.ip = this.text.trim() } }
                    Process {
                        id: dnsSet
                        onRunningChanged: {
                            if (!running && networkCard.pending !== "") {
                                networkCard.pending = ""
                                networkCard.dnsError = "Could not start " + command[0] + ". Check that it is installed."
                            }
                        }
                        onExited: exitCode => {
                            networkCard.pending = ""
                            if (exitCode !== 0) networkCard.dnsError = "DNS change failed (exit " + exitCode + ")."
                            dnsRead.running = true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        ColumnLayout {
                            id: netCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing: 14

                            // connection
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    text: !root.netDevice ? root.icon(0xF0202)
                                        : (root.netDevice.type === DeviceType.Wifi ? root.icon(0xF05A9) : root.icon(0xF0200))
                                    color: root.netDevice ? root.green : root.red
                                    font { family: root.iconFont; pixelSize: root.fontSize + 6 }
                                }
                                ColumnLayout {
                                    spacing: 2
                                    Text {
                                        text: !root.netDevice ? "Offline"
                                            : (root.netDevice.type === DeviceType.Wifi ? "Wi-Fi" : "Wired") + "  ·  " + root.netDevice.name
                                        color: root.fg
                                        font { family: root.font; pixelSize: root.fontSize; bold: true }
                                    }
                                    Text {
                                        visible: !!root.netDevice
                                        text: (networkCard.ip || "no IP yet")
                                            + (root.netDevice?.linkSpeed > 0 ? "  ·  " + root.netDevice.linkSpeed + " Mb/s" : "")
                                        color: root.dim
                                        font { family: root.font; pixelSize: root.fontSize - 2 }
                                    }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.bgAlt }

                            Text {
                                text: "DNS PROVIDER"
                                color: root.dim
                                font { family: root.font; pixelSize: root.fontSize - 3; bold: true; letterSpacing: 1 }
                            }

                            // pills: current one yellow, the one being applied blinks dim
                            GridLayout {
                                Layout.fillWidth: true
                                columns: 3
                                rowSpacing: 8
                                columnSpacing: 8

                                Repeater {
                                    model: networkCard.providers
                                    Rectangle {
                                        id: pill
                                        required property string modelData
                                        readonly property bool current: networkCard.dns === modelData
                                        readonly property bool applying: networkCard.pending === modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: 8
                                        color: current ? root.yellow : (pillMouse.containsMouse ? root.hover : root.bgAlt)
                                        opacity: applying ? 0.5 : 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: pill.modelData
                                            color: pill.current ? root.bg : root.fg
                                            font { family: root.font; pixelSize: root.fontSize - 1; bold: pill.current }
                                        }
                                        MouseArea {
                                            id: pillMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: networkCard.setDns(pill.modelData)
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: networkCard.dnsError !== ""
                                Layout.fillWidth: true
                                text: networkCard.dnsError
                                wrapMode: Text.Wrap
                                color: root.red
                                font { family: root.font; pixelSize: root.fontSize - 2 }
                            }
                        }
                    }
                }

                // ---------- tray menu: the app's menu, drawn by us ----------
                // Quickshell can only show apps' own (platform) menus in QApplication mode,
                // and they wouldn't match the bar anyway. Submenus drill down in place.
                Item {
                    id: trayMenu
                    visible: dropdown.open === "tray"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    width: 280
                    height: menuCol.implicitHeight + 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    MouseArea { anchors.fill: parent } // clicks on the card don't close it

                    property var item: null       // the SystemTrayItem
                    property real anchorX: 0
                    property var stack: []        // [{ title, opener }] for submenus
                    property bool settling: false // ignore clicks right after changing level
                    readonly property var opener: stack.length > 0 ? stack[stack.length - 1].opener : rootOpener

                    function openFor(it, x) {
                        reset()
                        item = it
                        anchorX = x
                        dropdown.open = "tray"
                    }
                    function reset() {
                        const old = stack; stack = []
                        for (const lvl of old) lvl.opener.destroy()
                    }
                    function settle() { settling = true; settleTimer.restart() }
                    function enter(entry) {
                        const o = openerComponent.createObject(trayMenu, { menu: entry })
                        stack = stack.concat([{ title: entry.text, opener: o }])
                        settle()
                    }
                    function back() {
                        const lvl = stack[stack.length - 1]
                        stack = stack.slice(0, -1)
                        lvl.opener.destroy()
                        settle()
                    }
                    function clean(t) { return String(t ?? "").replace(/_(?!_)/g, "").replace(/__/g, "_") } // drop "_" mnemonics
                    onVisibleChanged: if (!visible) reset()

                    QsMenuOpener { id: rootOpener; menu: trayMenu.visible ? (trayMenu.item?.menu ?? null) : null }
                    Component { id: openerComponent; QsMenuOpener {} }
                    Timer { id: settleTimer; interval: 250; onTriggered: trayMenu.settling = false }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        ColumnLayout {
                            id: menuCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                            spacing: 2

                            // header: app name, or "‹ submenu" to go back
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: 6
                                color: trayMenu.stack.length > 0 && backMouse.containsMouse ? root.bgAlt : "transparent"
                                Text {
                                    anchors { left: parent.left; leftMargin: 8; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    elide: Text.ElideRight
                                    text: trayMenu.stack.length > 0
                                        ? "‹  " + trayMenu.clean(trayMenu.stack[trayMenu.stack.length - 1].title)
                                        : (trayMenu.item?.tooltipTitle || trayMenu.item?.title || trayMenu.item?.id || "")
                                    color: trayMenu.stack.length > 0 ? root.blue : root.dim
                                    font { family: root.font; pixelSize: root.fontSize - 2; bold: true }
                                }
                                MouseArea {
                                    id: backMouse
                                    anchors.fill: parent
                                    enabled: trayMenu.stack.length > 0
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (!trayMenu.settling) trayMenu.back()
                                }
                            }

                            Repeater {
                                model: trayMenu.opener.children

                                Item {
                                    id: entryRow
                                    required property var modelData
                                    readonly property bool sep: modelData.isSeparator
                                    readonly property bool on: modelData.enabled
                                    readonly property bool checkable: modelData.buttonType !== QsMenuButtonType.None
                                    readonly property bool checked: modelData.checkState === Qt.Checked
                                    Layout.fillWidth: true
                                    implicitHeight: sep ? 9 : 30

                                    Rectangle { // separator
                                        visible: entryRow.sep
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                                        height: 1
                                        color: root.bgAlt
                                    }

                                    Rectangle {
                                        visible: !entryRow.sep
                                        anchors.fill: parent
                                        radius: 6
                                        color: entryMouse.containsMouse && entryRow.on ? root.bgAlt : "transparent"

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            spacing: 8

                                            // checkbox / radio state, or the entry's icon
                                            Item {
                                                Layout.preferredWidth: 16
                                                Layout.preferredHeight: 16
                                                Text {
                                                    anchors.centerIn: parent
                                                    visible: entryRow.checkable
                                                    text: entryRow.checked
                                                        ? (entryRow.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : root.icon(0xF012C))
                                                        : (entryRow.modelData.buttonType === QsMenuButtonType.RadioButton ? "○" : "")
                                                    color: root.yellow
                                                    font { family: root.iconFont; pixelSize: root.fontSize - 2 }
                                                }
                                                Image {
                                                    anchors.fill: parent
                                                    // hidden unless it actually loaded (no "missing image" squares)
                                                    visible: !entryRow.checkable && entryRow.modelData.icon !== "" && status === Image.Ready
                                                    source: entryRow.modelData.icon
                                                    sourceSize { width: 16; height: 16 }
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: trayMenu.clean(entryRow.modelData.text)
                                                elide: Text.ElideRight
                                                color: entryRow.on ? root.fg : root.faint
                                                font { family: root.font; pixelSize: root.fontSize - 1 }
                                            }
                                            Text {
                                                visible: entryRow.modelData.hasChildren
                                                text: "›"
                                                color: root.dim
                                                font { family: root.font; pixelSize: root.fontSize + 2 }
                                            }
                                        }

                                        MouseArea {
                                            id: entryMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            enabled: entryRow.on
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (trayMenu.settling) return
                                                if (entryRow.modelData.hasChildren) trayMenu.enter(entryRow.modelData)
                                                else { entryRow.modelData.triggered(); dropdown.open = "" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- media ----------
                MediaCard {
                    id: mediaCard
                    shell: root
                    visible: dropdown.open === "media"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // ---------- notification center ----------
                Item {
                    id: notifCenter
                    visible: dropdown.open === "notifications"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 400
                    height: centerCol.implicitHeight + 32
                    MouseArea { anchors.fill: parent } // clicks on the card don't close it

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        ColumnLayout {
                            id: centerCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                            spacing: 12

                            // header: title, DND toggle, clear all
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text {
                                    Layout.fillWidth: true
                                    text: "Notifications"
                                    color: root.fg
                                    font { family: root.font; pixelSize: root.fontSize; bold: true }
                                }
                                Rectangle {
                                    implicitWidth: dndText.implicitWidth + 20
                                    implicitHeight: 26
                                    radius: 6
                                    color: root.dnd ? root.red : root.bgAlt
                                    Text {
                                        id: dndText
                                        anchors.centerIn: parent
                                        textFormat: Text.RichText
                                        text: root.iconHtml(root.dnd ? 0xF009B : 0xF009A) + " Do Not Disturb"
                                        color: root.dnd ? root.bg : root.fg
                                        font { family: root.font; pixelSize: root.fontSize - 3; bold: root.dnd }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { root.dnd = !root.dnd; if (root.dnd) root.popups = [] }
                                    }
                                }
                                Text {
                                    visible: root.history.length > 0
                                    text: "Clear"
                                    color: root.blue
                                    font { family: root.font; pixelSize: root.fontSize - 2 }
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -6
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.clearNotifications()
                                    }
                                }
                            }

                            Text {
                                visible: root.history.length === 0
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 8
                                Layout.bottomMargin: 8
                                text: "No notifications"
                                color: root.dim
                                font { family: root.font; pixelSize: root.fontSize - 1; italic: true }
                            }

                            // the list (scrolls when long)
                            Flickable {
                                visible: root.history.length > 0
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.min(historyCol.implicitHeight, 520)
                                contentHeight: historyCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ColumnLayout {
                                    id: historyCol
                                    width: parent.width
                                    spacing: 8

                                    Repeater {
                                        model: ScriptModel { values: root.history; comparisonMode: ObjectComparison.Identity }
                                        Rectangle {
                                            id: hRow
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: hBody.implicitHeight + 20
                                            radius: 8
                                            color: root.bgAlt
                                            border { color: hRow.modelData.critical ? root.critical : "transparent"; width: 1 }

                                            RowLayout {
                                                id: hBody
                                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                                                spacing: 10

                                                Image {
                                                    Layout.preferredWidth: 32
                                                    Layout.preferredHeight: 32
                                                    Layout.alignment: Qt.AlignTop
                                                    source: hRow.modelData.icon
                                                    sourceSize { width: 32; height: 32 }
                                                    visible: status === Image.Ready
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 2
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: (hRow.modelData.appName || "notification") + "  ·  " + root.ago(hRow.modelData.time)
                                                        color: root.dim
                                                        elide: Text.ElideRight
                                                        font { family: root.font; pixelSize: root.fontSize - 4 }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: hRow.modelData.summary
                                                        color: root.fg
                                                        elide: Text.ElideRight
                                                        font { family: root.font; pixelSize: root.fontSize - 1; bold: true }
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: text !== ""
                                                        text: hRow.modelData.body
                                                        textFormat: Text.StyledText
                                                        wrapMode: Text.Wrap
                                                        maximumLineCount: 3
                                                        elide: Text.ElideRight
                                                        color: root.dim
                                                        font { family: root.font; pixelSize: root.fontSize - 2 }
                                                    }
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignTop
                                                    text: "×"
                                                    color: root.dim
                                                    font { family: root.font; pixelSize: root.fontSize + 2 }
                                                    MouseArea {
                                                        anchors.fill: parent; anchors.margins: -6
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.dismissNotification(hRow.modelData.id)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                }

                // ----- big: app + workspaces | clock, date, now playing | notifications + status -----
                Item {
                    id: big
                    anchors { fill: parent; leftMargin: 28; rightMargin: 28; topMargin: 14; bottomMargin: 16 }
                    implicitWidth: islandLeft.implicitWidth + islandCenter.implicitWidth + islandRight.implicitWidth + 80
                    opacity: island.expanded ? 1 : 0
                    scale: island.expanded ? 1 : 0.94
                    visible: opacity > 0
                    enabled: island.expanded
                    Behavior on opacity { NumberAnimation { duration: island.expanded ? 200 : 90; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                    // left: the focused app, then the workspaces
                    ColumnLayout {
                        id: islandLeft
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                        spacing: 12
                        RowLayout {
                            spacing: 8
                            Layout.maximumWidth: 190
                            Image {
                                id: appIconImg
                                visible: status === Image.Ready
                                source: bar.activeEntry?.icon ? Quickshell.iconPath(bar.activeEntry.icon, true) : ""
                                sourceSize { width: 18; height: 18 }
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                            }
                            Text {
                                Layout.fillWidth: true
                                text: bar.activeEntry?.name || bar.activeApp?.appId || "Desktop"
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: root.fg
                                font { family: root.font; pixelSize: 14; weight: Font.DemiBold }
                            }
                        }
                        Loader { sourceComponent: wsDots }
                    }

                    // center: clock + date on a raised chip, the track below
                    ColumnLayout {
                        id: islandCenter
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
                        spacing: 10

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: chipRow.implicitWidth + 28
                            implicitHeight: 38
                            radius: 12
                            color: chipMouse.containsMouse ? root.hoverStrong : root.bgAlt
                            Behavior on color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 12
                                Text {
                                    text: Qt.formatDateTime(clock.date, "HH:mm")
                                    color: root.fg
                                    font { family: root.font; pixelSize: 22; weight: Font.DemiBold; features: { "tnum": 1 } }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: Qt.formatDateTime(clock.date, "ddd, MMM d")
                                    color: root.dim
                                    font { family: root.font; pixelSize: 14; weight: Font.Medium }
                                }
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dropdown.toggle("calendar")
                            }
                        }

                        // now playing. click = media card, middle click = play/pause
                        Rectangle {
                            id: nowPlaying
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: 290
                            implicitHeight: 52
                            radius: 14
                            color: npMouse.containsMouse ? root.hover : Qt.alpha(root.bgAlt, 0.55)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            readonly property bool playing: root.media?.isPlaying ?? false

                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 14 }
                                spacing: 10
                                ClippingRectangle {
                                    Layout.preferredWidth: 36
                                    Layout.preferredHeight: 36
                                    radius: 8
                                    color: root.bgAlt
                                    // no cover: the player app's logo, else a note
                                    Image {
                                        id: npLogo
                                        anchors.centerIn: parent
                                        width: 22; height: 22
                                        visible: cover.status !== Image.Ready && status === Image.Ready
                                        source: island.expanded ? root.mediaAppIcon(root.media) : ""
                                        sourceSize { width: 44; height: 44 }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: cover.status !== Image.Ready && npLogo.status !== Image.Ready
                                        text: root.icon(0xF075A)
                                        color: root.dim
                                        font { family: root.iconFont; pixelSize: 18 }
                                    }
                                    Image {
                                        id: cover
                                        anchors.fill: parent
                                        source: island.expanded ? root.mediaArt(root.media) : ""
                                        sourceSize { width: 72; height: 72 }
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1
                                    Text {
                                        Layout.fillWidth: true
                                        text: "‎" + (root.media ? (root.media.trackTitle || "Unknown") : "Nothing playing")
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: root.media ? root.fg : root.dim
                                        font { family: root.font; pixelSize: 14; weight: Font.DemiBold }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        visible: text !== ""
                                        text: root.media?.trackArtist ? "‎" + root.media.trackArtist : ""
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: root.dim
                                        font { family: root.font; pixelSize: 12 }
                                    }
                                }
                                // dotted wave: moves while playing, flat and dim when paused
                                Row {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignVCenter
                                    Repeater {
                                        model: 10
                                        Rectangle {
                                            id: dot
                                            required property int index
                                            width: 3
                                            height: 3
                                            radius: 1.5
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: root.accent
                                            opacity: nowPlaying.playing ? 0.9 : 0.3
                                            Behavior on opacity { NumberAnimation { duration: 300 } }
                                            SequentialAnimation on height {
                                                running: nowPlaying.playing && island.expanded
                                                loops: Animation.Infinite
                                                onRunningChanged: if (!running) dot.height = 3
                                                PauseAnimation { duration: dot.index * 70 }
                                                NumberAnimation { to: 11; duration: 320; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 3; duration: 320; easing.type: Easing.InOutSine }
                                                PauseAnimation { duration: (9 - dot.index) * 70 }
                                            }
                                        }
                                    }
                                }
                            }
                            MouseArea {
                                id: npMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.MiddleButton) root.media?.togglePlaying()
                                    else dropdown.toggleAt("media", parent)
                                }
                            }
                        }
                    }

                    // right: notifications, then tray + status
                    ColumnLayout {
                        id: islandRight
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                        spacing: 14
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 8
                            Text {
                                text: root.dnd ? "Do not disturb"
                                    : root.history.length === 0 ? "All caught up"
                                    : root.history.length + " notification" + (root.history.length === 1 ? "" : "s")
                                color: root.fg
                                font { family: root.font; pixelSize: 14; weight: Font.DemiBold }
                            }
                            Text {
                                text: root.icon(root.dnd ? 0xF009B : 0xF009A)
                                color: root.dnd ? root.red : root.accent
                                font { family: root.iconFont; pixelSize: 16 }
                            }
                            TapHandler { onTapped: dropdown.toggleAt("notifications", parent) }
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 12
                            Loader { sourceComponent: trayComp; visible: SystemTray.items.values.length > 0; Layout.alignment: Qt.AlignVCenter }
                            Loader { sourceComponent: micComp; active: root.source?.muted ?? false; visible: active; Layout.alignment: Qt.AlignVCenter }
                            Loader { sourceComponent: netBarsComp; Layout.alignment: Qt.AlignVCenter }
                            Loader { sourceComponent: volumeComp; Layout.alignment: Qt.AlignVCenter }
                            Loader { sourceComponent: batteryComp; active: bar.hasBattery; visible: active; Layout.alignment: Qt.AlignVCenter }
                        }
                    }
                }
            }

            // ---------- cards (calendar, audio, network, tray, media, notifications) ----------
            // The cards live inside the island, which grows into them (see "panel" below).
            // `dropdown` only remembers which one is open, and while one is, covers the screen
            // with an invisible layer that has a hole where the island is: a click anywhere
            // else closes the card, while the island itself stays clickable.
            PanelWindow {
                id: dropdown
                property string open: ""   // "", "calendar", "audio", "network", "notifications", "tray" or "media"
                function toggle(name) { open = (open === name) ? "" : name }
                function toggleAt(name, item) { toggle(name) }
                Connections {
                    target: root
                    function onMediaCardRequestChanged() {
                        if (bar.screen.name === Hyprland.focusedMonitor?.name && dropdown.open !== "media") dropdown.toggle("media")
                    }
                    function onCardRequestChanged() {
                        if (bar.screen.name === Hyprland.focusedMonitor?.name)
                            dropdown.open = root.cardName === "" ? "" : (dropdown.open === root.cardName ? "" : root.cardName)
                    }
                }

                screen: bar.screen
                visible: open !== ""
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "bar-catcher"
                color: "transparent"
                mask: Region {
                    item: catchAll
                    Region {
                        intersection: Intersection.Subtract
                        x: island.x; y: island.y; width: island.width; height: island.height
                    }
                }
                MouseArea { id: catchAll; anchors.fill: parent; onClicked: dropdown.open = "" }
            }

            // ---------- notification popups ----------
            // Top-right, right under the bar (it respects the bar's reserved space).
            PanelWindow {
                id: toastWindow
                screen: bar.screen
                visible: root.popups.length > 0
                anchors { top: true; right: true }
                margins { top: 6; right: 10 }
                implicitWidth: 380
                implicitHeight: toastCol.implicitHeight
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "bar-notifications"
                color: "transparent"

                ColumnLayout {
                    id: toastCol
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: ScriptModel {
                            values: root.popups
                            comparisonMode: ObjectComparison.Identity
                        }

                        Rectangle {
                            id: toast
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: toastBody.implicitHeight + 24
                            radius: 10
                            color: root.bg
                            border { color: toast.modelData.critical ? root.critical : root.bgAlt; width: toast.modelData.critical ? 2 : 1 }

                            // disappears after the app's timeout; critical ones stay, hovering pauses
                            Timer {
                                interval: toast.modelData.timeout
                                running: !toast.modelData.critical && !toastMouse.containsMouse
                                onTriggered: root.hidePopup(toast.modelData.id)
                            }

                            // click = the app's default action (if any), otherwise just close the popup
                            MouseArea {
                                id: toastMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const def = toast.modelData.actions.find(a => a.id === "default")
                                    if (def) root.invokeAction(toast.modelData.id, "default")
                                    else root.hidePopup(toast.modelData.id)
                                }
                            }

                            ColumnLayout {
                                id: toastBody
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Image {
                                        Layout.preferredWidth: 40
                                        Layout.preferredHeight: 40
                                        Layout.alignment: Qt.AlignTop
                                        source: toast.modelData.icon
                                        sourceSize { width: 40; height: 40 }
                                        visible: status === Image.Ready
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: toast.modelData.appName || "notification"
                                            color: root.dim
                                            elide: Text.ElideRight
                                            font { family: root.font; pixelSize: root.fontSize - 4 }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: toast.modelData.summary
                                            color: root.fg
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            font { family: root.font; pixelSize: root.fontSize - 1; bold: true }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            visible: text !== ""
                                            text: toast.modelData.body
                                            textFormat: Text.StyledText
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 4
                                            elide: Text.ElideRight
                                            color: root.dim
                                            font { family: root.font; pixelSize: root.fontSize - 2 }
                                        }
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignTop
                                        text: "×"
                                        color: root.dim
                                        font { family: root.font; pixelSize: root.fontSize + 2 }
                                        MouseArea {
                                            anchors.fill: parent; anchors.margins: -6
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.hidePopup(toast.modelData.id)
                                        }
                                    }
                                }

                                // action buttons (the "default" action is the click on the popup itself)
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: toast.modelData.actions.some(a => a.id !== "default")
                                    spacing: 8
                                    Repeater {
                                        model: toast.modelData.actions.filter(a => a.id !== "default")
                                        Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            implicitHeight: 28
                                            radius: 6
                                            color: actMouse.containsMouse ? root.hoverStrong : root.bgAlt
                                            Text {
                                                anchors.centerIn: parent
                                                text: parent.modelData.text
                                                color: root.fg
                                                font { family: root.font; pixelSize: root.fontSize - 3 }
                                            }
                                            MouseArea {
                                                id: actMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: root.invokeAction(toast.modelData.id, parent.modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

        }
    }
}
