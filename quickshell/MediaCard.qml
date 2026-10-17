pragma ComponentBehavior: Bound
// The music card, Spotify-style: the island grows into it (click the note in the bar, or the
// now-playing card in the expanded island).
//   left:  now playing: any MPRIS player (Firefox, Spotify...) or our local music (MusicPlayer.qml):
//          big cover, title, seek bar (local only), controls, this player's own volume
//   right: your library (the music folder): search it, paste a link to download with yt-dlp,
//          change the folder; click a track to play it
// Behind it all: the cover, blurred and darkened, like Spotify's ambient glow.
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: card
    required property var shell
    readonly property var music: shell.music
    // "Music" picked in the chips: your local music (and its library), even while another app plays
    property bool localPicked: false
    readonly property var player: localPicked ? music : shell.media
    readonly property bool isLocal: player === music
    // the library only for local music (or when nothing plays at all, to pick something)
    readonly property bool showLibrary: isLocal || !shell.media
    // the chips: your music first, then every other app that has a track
    readonly property var chips: [music].concat(shell.mediaList.filter(p => p !== music))
    // Time and seek bar only for local music: mpv's numbers are exact. Browsers don't report them
    // reliably (Firefox sends position 0 and drops the length after every seek).
    readonly property real trackLength: isLocal ? music.length : 0
    readonly property real position: isLocal ? music.position : 0
    readonly property bool needsPosition: visible && isLocal
    onNeedsPositionChanged: music.setPositionClient(card, needsPosition)
    Component.onCompleted: music.setPositionClient(card, needsPosition)
    Component.onDestruction: music.setPositionClient(card, false)

    readonly property string art: visible ? shell.mediaArt(player) : ""
    // the big cover: YouTube's 1280x720 thumbnail; videos without one fall back to `art`
    readonly property string bigArt: visible ? shell.mediaArt(player, true) : ""
    property string missingArt: ""
    // a small cover (Chromium/Helium send ~150px ones) or none: have the bar find an HD one
    function maybeLookup() {
        if (!visible || !player || isLocal) return
        const small = cover.status === Image.Ready && cover.implicitWidth < 400
        const none = cover.status === Image.Error || !art
        if (small || none) shell.lookupArt(player)
    }
    onArtChanged: Qt.callLater(maybeLookup)

    width: 800
    height: 440
    MouseArea { anchors.fill: parent } // clicks on the card don't close it

    onVisibleChanged: {
        if (visible) { music.refresh(); refreshStreams() }
        else { browser.visible = false; streamTimer.stop(); streams = []; localPicked = false }
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0))
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60
        const mm = h > 0 && m < 10 ? "0" + m : "" + m
        return (h > 0 ? h + ":" : "") + mm + ":" + (sec < 10 ? "0" : "") + sec
    }
    function seek(seconds) { if (isLocal) music.seekTo(seconds) }

    // ---------- volume ----------
    // Local music: mpv's own volume. Other players: the app's own PipeWire streams (like a
    // per-app mixer), which works for every app. The MPRIS volume is only the fallback.
    // Streams are a snapshot refreshed shortly after PipeWire changes, only while open
    // (rebuilding from the live list while a stream disappears can crash Quickshell).
    property var streams: []
    readonly property var liveNodes: Pipewire.nodes.values
    readonly property bool wantsStreams: visible && !!player && !isLocal
    function refreshStreams() {
        streams = wantsStreams
            ? liveNodes.filter(n => n && n.isStream && n.isSink && n.audio && ownsStream(player, n))
            : []
    }
    onWantsStreamsChanged: { streamTimer.stop(); refreshStreams() }
    onPlayerChanged: { if (wantsStreams) refreshStreams(); Qt.callLater(maybeLookup) }
    onLiveNodesChanged: if (wantsStreams) streamTimer.restart()
    Timer { id: streamTimer; interval: 75; onTriggered: card.refreshStreams() }
    PwObjectTracker { objects: card.streams }

    // a stream belongs to the player if its name matches the app ("Firefox" ~ "firefox")
    function ownsStream(p, n) {
        const name = (n.name || "").toLowerCase()
        if (!name) return false
        return [p.desktopEntry, p.identity].filter(k => k).map(k => k.toLowerCase())
            .some(k => k === name || k.includes(name) || name.includes(k))
    }
    readonly property var appStreams: !player || isLocal ? [] : streams.filter(n => ownsStream(player, n))
    readonly property bool hasVolume: !!player && (isLocal || appStreams.length > 0 || !!player.volumeSupported)
    readonly property real volume: !player ? 0
        : isLocal ? music.volume
        : appStreams.length > 0 ? (appStreams[0].audio?.volume ?? 0)
        : player.volume
    readonly property bool volumeMuted: isLocal ? music.muted : (appStreams[0]?.audio?.muted ?? false)
    function setVolume(v) {
        v = Math.max(0, Math.min(1, v))
        if (isLocal) music.setVolume(v)
        else if (appStreams.length > 0) { for (const n of appStreams) if (n.audio) n.audio.volume = v }
        else if (player.volumeSupported) player.volume = v
    }
    function toggleMute() {
        if (isLocal) music.toggleMute()
        else { const m = !volumeMuted; for (const n of appStreams) if (n.audio) n.audio.muted = m }
    }

    function pretty(p) { return p.startsWith(shell.home) ? "~" + p.slice(shell.home.length) : p }
    // "Artist - Title.opus" (how yt-dlp names them) -> title + artist; otherwise the name + its folder
    function splitLabel(t) {
        const l = music.label(t), slash = l.lastIndexOf("/")
        const file = l.slice(slash + 1), dir = slash > 0 ? l.slice(0, slash) : ""
        const dash = file.indexOf(" - ")
        return dash > 0 ? { title: file.slice(dash + 3), sub: file.slice(0, dash) } : { title: file, sub: dir }
    }

    // ---------- building blocks ----------
    component Glyph: Text {
        id: gl
        property int glyph
        property color tint: card.shell.fg
        property bool active: true
        property int size: 22
        signal clicked
        text: card.shell.icon(glyph)
        color: !active ? card.shell.faint : glMouse.containsMouse ? Qt.lighter(tint, 1.25) : tint
        font { family: card.shell.iconFont; pixelSize: size }
        scale: glMouse.pressed ? 0.88 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea {
            id: glMouse
            anchors.fill: parent; anchors.margins: -7
            hoverEnabled: true
            cursorShape: gl.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (gl.active) gl.clicked()
        }
    }
    // a thin bar that thickens on hover; click/drag sets, wheel nudges
    component Bar: Item {
        id: bar
        property real value: 0          // 0..1
        property color fill: card.shell.accent
        property bool interactive: true
        signal moved(real v)
        signal wheeled(int dir)
        readonly property bool hot: barMouse.containsMouse || barMouse.pressed
        implicitHeight: 16
        Rectangle {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: bar.hot ? 6 : 4
            radius: height / 2
            color: Qt.alpha(card.shell.fg, 0.14)
            Behavior on height { NumberAnimation { duration: 120 } }
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, bar.value))
                height: parent.height; radius: parent.radius
                color: bar.hot ? bar.fill : Qt.alpha(card.shell.fg, 0.85)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
        }
        Rectangle {
            x: parent.width * Math.max(0, Math.min(1, bar.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13; radius: 6.5
            color: card.shell.fg
            scale: bar.hot ? 1 : 0
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
        }
        MouseArea {
            id: barMouse
            anchors.fill: parent
            enabled: bar.interactive
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => bar.moved(Math.max(0, Math.min(1, mouse.x / width)))
            onPositionChanged: mouse => { if (pressed) bar.moved(Math.max(0, Math.min(1, mouse.x / width))) }
            onWheel: wheel => bar.wheeled(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }

    // ---------- the surface ----------
    ClippingRectangle {
        anchors.fill: parent
        radius: 22
        color: "#0c0b0b"

        // ambient glow: the cover, tiny, blurred and darkened (the accent when there's no cover)
        Image {
            id: glowSrc
            anchors.fill: parent
            visible: false
            source: card.art
            sourceSize { width: 48; height: 48 }
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        MultiEffect {
            anchors.fill: parent
            source: glowSrc
            visible: glowSrc.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 64
            saturation: 0.25
            brightness: -0.38
            opacity: 0.9
        }
        Rectangle {
            anchors.fill: parent
            visible: glowSrc.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(card.shell.accent, 0.22) }
                GradientStop { position: 0.75; color: "transparent" }
            }
        }
        // the library side sits on a darker pane, so the list stays easy to read
        Rectangle {
            x: nowPane.width + 40
            anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
            color: Qt.alpha("#000000", 0.42)
            opacity: card.showLibrary ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        // ===================== left: now playing =====================
        ColumnLayout {
            id: nowPane
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: 26; topMargin: 22; bottomMargin: 20 }
            // the left column next to the library; the whole card for other apps (no library)
            width: card.showLibrary ? 300 : card.width - 52
            spacing: 0

            // which player (only when there's more than one)
            Row {
                Layout.preferredHeight: visible ? 30 : 0
                Layout.bottomMargin: visible ? 14 : 0
                Layout.alignment: Qt.AlignLeft   // always top-left, also when the rest is centered
                visible: card.chips.length > 1
                spacing: 6
                Repeater {
                    model: ScriptModel {
                        values: card.visible ? card.chips : []
                        comparisonMode: ObjectComparison.Identity
                    }
                    Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: modelData === card.player
                        readonly property string iconSrc: modelData === card.music ? "" : card.shell.mediaAppIcon(modelData)
                        width: chipRow.implicitWidth + 20
                        height: 30
                        radius: 15
                        color: current ? Qt.alpha(card.shell.fg, 0.92) : chipMouse.containsMouse ? Qt.alpha(card.shell.fg, 0.16) : Qt.alpha(card.shell.fg, 0.08)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.iconSrc !== ""
                                source: chip.iconSrc
                                sourceSize { width: 16; height: 16 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: chip.iconSrc === ""
                                text: card.shell.icon(0xF075A)
                                color: chip.current ? "#000000" : card.shell.accent
                                font { family: card.shell.iconFont; pixelSize: 14 }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: chip.modelData === card.music ? "Music" : (chip.modelData.identity || "Player")
                                color: chip.current ? "#000000" : card.shell.fg
                                font { family: card.shell.font; pixelSize: 12; weight: Font.DemiBold }
                            }
                        }
                        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                card.localPicked = chip.modelData === card.music
                                if (chip.modelData !== card.music || card.music.active) card.shell.mediaPick = chip.modelData
                            } }
                    }
                }
            }

            // a column next to the library; for other apps the whole card, everything centered
            // under the cover (a video's thumbnail keeps its wide shape)
            GridLayout {
                id: nowGrid
                readonly property bool wide: !card.showLibrary
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 1
                rowSpacing: 0

                // cover
                ClippingRectangle {
                    id: coverBox
                    // the picture's own shape when centered (square art, 16:9 thumbnails), within limits
                    readonly property real aspect: cover.status === Image.Ready && cover.implicitHeight > 0
                        ? Math.max(1, Math.min(1.9, cover.implicitWidth / cover.implicitHeight)) : 1
                    readonly property int tall: card.chips.length > 1 ? 196 : 228
                    Layout.preferredWidth: nowGrid.wide ? Math.round(tall * aspect) : 300
                    Layout.preferredHeight: tall
                    Layout.alignment: Qt.AlignHCenter
                    Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    radius: 16
                    color: Qt.alpha(card.shell.fg, 0.06)
                    Behavior on Layout.preferredHeight { NumberAnimation { duration: 200 } }
                    // no cover: the player app's logo, else a note
                    Image {
                        id: appLogo
                        anchors.centerIn: parent
                        width: 64; height: 64
                        visible: cover.status !== Image.Ready && status === Image.Ready
                        source: card.visible ? card.shell.mediaAppIcon(card.player) : ""
                        sourceSize { width: 128; height: 128 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready && appLogo.status !== Image.Ready
                        text: card.shell.icon(0xF075A)
                        color: Qt.alpha(card.shell.fg, 0.3)
                        font { family: card.shell.iconFont; pixelSize: 64 }
                    }
                    Image {
                        id: cover
                        anchors.fill: parent
                        source: card.bigArt && card.bigArt !== card.missingArt ? card.bigArt : card.art
                        onStatusChanged: {
                            if (status === Image.Error && card.bigArt && card.bigArt !== card.art) card.missingArt = card.bigArt
                            card.maybeLookup()
                        }
                        sourceSize { width: 600; height: 600 }
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        retainWhileLoading: true
                        cache: !card.isLocal
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 250 } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0

                    // title + artist (centered with the cover when there's no library)
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 16
                        horizontalAlignment: nowGrid.wide ? Text.AlignHCenter : Text.AlignLeft
                        text: "‎" + (card.player && !(card.isLocal && !card.music.active) ? (card.player.trackTitle || "Unknown title") : "Nothing playing")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: card.shell.fg
                        font { family: card.shell.font; pixelSize: nowGrid.wide ? 21 : 19; weight: Font.Bold }
                    }
                    Text {
                        Layout.fillWidth: true
                        Layout.topMargin: 3
                        horizontalAlignment: nowGrid.wide ? Text.AlignHCenter : Text.AlignLeft
                        text: "‎" + (card.player ? (card.player.trackArtist || (card.isLocal ? "Your music" : card.player.identity || "")) : "Pick a song from your library →")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: card.shell.dim
                        font { family: card.shell.font; pixelSize: 13 }
                    }

                    Item { Layout.fillHeight: true }

                    // seek bar (local music only)
                    Bar {
                        id: seekBar
                        visible: !!card.player && card.trackLength > 0
                        Layout.fillWidth: true
                        property real preview: -1
                        readonly property real pos: preview >= 0 ? preview * card.trackLength : card.position
                        value: card.trackLength > 0 ? pos / card.trackLength : 0
                        interactive: card.isLocal
                        onMoved: v => { preview = v; seekCommit.restart() }
                        Timer { id: seekCommit; interval: 120; onTriggered: { card.seek(seekBar.preview * card.trackLength); seekBar.preview = -1 } }
                    }
                    RowLayout {
                        visible: seekBar.visible
                        Layout.fillWidth: true
                        Text { text: card.fmt(seekBar.pos); color: card.shell.dim; font { family: card.shell.font; pixelSize: 11; features: { "tnum": 1 } } }
                        Item { Layout.fillWidth: true }
                        Text { text: card.fmt(card.trackLength); color: card.shell.dim; font { family: card.shell.font; pixelSize: 11; features: { "tnum": 1 } } }
                    }

                    // controls
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 6
                        spacing: 24
                        opacity: card.player ? 1 : 0.35
                        enabled: !!card.player
                        Glyph {
                            glyph: 0xF049D   // shuffle
                            size: 18
                            opacity: card.isLocal ? 1 : 0
                            enabled: card.isLocal
                            tint: card.music.shuffle ? card.shell.accent : card.shell.dim
                            onClicked: card.music.setShuffle(!card.music.shuffle)
                        }
                        Glyph { glyph: 0xF04AE; active: card.player?.canGoPrevious ?? false; onClicked: card.player.previous() }
                        Rectangle {
                            implicitWidth: 52; implicitHeight: 52; radius: 26
                            color: card.shell.accent
                            scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            Text {
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: card.player?.isPlaying ? 0 : 2
                                text: card.shell.icon(card.player?.isPlaying ? 0xF03E4 : 0xF040A)
                                color: "#000000"
                                font { family: card.shell.iconFont; pixelSize: 26 }
                            }
                            MouseArea { id: playMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: card.player.togglePlaying() }
                        }
                        Glyph { glyph: 0xF04AD; active: card.player?.canGoNext ?? false; onClicked: card.player.next() }
                        Glyph {
                            glyph: 0xF04DB   // stop
                            size: 18
                            opacity: card.isLocal ? 1 : 0
                            enabled: card.isLocal
                            tint: card.shell.dim
                            onClicked: card.music.stop()
                        }
                    }

                    // this player's volume: click the icon = mute
                    RowLayout {
                        Layout.fillWidth: !nowGrid.wide
                        Layout.preferredWidth: nowGrid.wide ? 340 : -1
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 12
                        spacing: 10
                        opacity: card.hasVolume ? 1 : 0
                        enabled: card.hasVolume
                        Glyph {
                            glyph: card.volumeMuted ? 0xF075F : card.volume < 0.34 ? 0xF057F : card.volume < 0.67 ? 0xF0580 : 0xF057E
                            size: 17
                            tint: card.volumeMuted ? card.shell.red : card.shell.dim
                            onClicked: card.toggleMute()
                        }
                        Bar {
                            Layout.fillWidth: true
                            value: card.volume
                            onMoved: v => card.setVolume(v)
                            onWheeled: dir => card.setVolume(card.volume + dir * 0.05)
                        }
                        Text {
                            Layout.preferredWidth: 34
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(card.volume * 100) + "%"
                            color: card.shell.dim
                            font { family: card.shell.font; pixelSize: 11; features: { "tnum": 1 } }
                        }
                    }
                }
            }
        }

        // ===================== right: your library =====================
        // One field: typing searches the tracks, a pasted link downloads (Enter).
        ColumnLayout {
            id: library
            anchors { left: nowPane.right; right: parent.right; top: parent.top; bottom: parent.bottom
                      leftMargin: 40 + 18; rightMargin: 18; topMargin: 20; bottomMargin: 14 }
            spacing: 10
            opacity: card.showLibrary ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: card.showLibrary ? 260 : 120; easing.type: Easing.OutCubic } }

            readonly property string text: field.text.trim()
            readonly property bool isLink: /^(https?:\/\/|www\.)/i.test(text)
            readonly property var shown: {
                if (!card.visible) return []
                const q = isLink ? "" : text.toLowerCase()
                return q ? card.music.tracks.filter(t => card.music.label(t).toLowerCase().includes(q)) : card.music.tracks
            }
            function submit() {
                if (!isLink || card.music.downloading) return
                card.music.download(text)
                field.text = ""
            }

            // header
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                spacing: 8
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: browser.visible ? "Pick a folder" : "Your music"
                        color: card.shell.fg
                        font { family: card.shell.font; pixelSize: 18; weight: Font.Bold }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (library.shown.length !== card.music.tracks.length ? library.shown.length + " of " : "")
                            + card.music.tracks.length + " song" + (card.music.tracks.length === 1 ? "" : "s")
                            + "  ·  " + card.pretty(card.music.folder)
                        elide: Text.ElideMiddle
                        color: card.shell.dim
                        font { family: card.shell.font; pixelSize: 11 }
                    }
                }
                Glyph {   // change the music folder
                    glyph: 0xF024B
                    size: 18
                    tint: browser.visible ? card.shell.accent : card.shell.dim
                    onClicked: browser.visible ? browser.visible = false : browser.open(card.music.folder)
                }
            }

            // search / link field
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: 19
                color: field.activeFocus ? Qt.alpha(card.shell.fg, 0.12) : Qt.alpha(card.shell.fg, 0.07)
                border { width: field.activeFocus ? 1 : 0; color: Qt.alpha(card.shell.accent, 0.6) }
                Behavior on color { ColorAnimation { duration: 150 } }
                RowLayout {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 8 }
                    spacing: 9
                    Text {
                        text: card.shell.icon(library.isLink ? 0xF0337 : 0xF0349)   // link / magnify
                        color: library.isLink ? card.shell.accent : card.shell.dim
                        font { family: card.shell.iconFont; pixelSize: 16 }
                    }
                    TextInput {
                        id: field
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: card.shell.fg
                        cursorDelegate: Rectangle { width: 2; color: card.shell.accent; visible: field.activeFocus }
                        selectionColor: Qt.alpha(card.shell.accent, 0.35)
                        selectByMouse: true
                        font { family: card.shell.font; pixelSize: 13 }
                        onAccepted: library.submit()
                        Keys.onEscapePressed: text = ""
                        onTextChanged: if (text !== "" && !card.music.downloading) card.music.dlStatus = ""
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            visible: field.text === ""
                            text: "Search, or paste a link to download"
                            elide: Text.ElideRight
                            color: card.shell.dim
                            font: field.font
                        }
                    }
                    // download (a link) / clear (a search)
                    Rectangle {
                        visible: library.isLink
                        implicitWidth: 30; implicitHeight: 26; radius: 13
                        color: card.music.downloading ? Qt.alpha(card.shell.fg, 0.1) : card.shell.accent
                        Text {
                            anchors.centerIn: parent
                            text: card.shell.icon(0xF01DA)
                            color: card.music.downloading ? card.shell.dim : "#000000"
                            font { family: card.shell.iconFont; pixelSize: 15 }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: library.submit() }
                    }
                    Glyph {
                        visible: field.text !== "" && !library.isLink
                        glyph: 0xF0156
                        size: 15
                        tint: card.shell.dim
                        onClicked: field.text = ""
                    }
                }
            }

            // download progress / last result
            ColumnLayout {
                visible: card.music.downloading || card.music.dlStatus !== ""
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 5
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: card.shell.icon(card.music.downloading ? 0xF01DA : (card.music.dlFailed ? 0xF0026 : 0xF012C))
                        color: card.music.dlFailed && !card.music.downloading ? card.shell.red : card.shell.accent
                        font { family: card.shell.iconFont; pixelSize: 14 }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "‎" + (card.music.downloading ? (card.music.dlTitle || "Starting…") : card.music.dlStatus)
                        color: card.music.dlFailed && !card.music.downloading ? card.shell.red : card.shell.fg
                        elide: Text.ElideRight
                        font { family: card.shell.font; pixelSize: 12 }
                    }
                    Text {
                        visible: card.music.downloading
                        text: Math.round(card.music.dlPercent) + "%"
                        color: card.shell.dim
                        font { family: card.shell.font; pixelSize: 12; features: { "tnum": 1 } }
                    }
                    Glyph {   // cancel a download, or dismiss the result
                        glyph: 0xF0156
                        size: 14
                        tint: card.shell.dim
                        onClicked: card.music.downloading ? card.music.cancelDownload() : card.music.dlStatus = ""
                    }
                }
                Rectangle {
                    visible: card.music.downloading
                    Layout.fillWidth: true
                    implicitHeight: 3; radius: 1.5
                    color: Qt.alpha(card.shell.fg, 0.12)
                    Rectangle {
                        width: parent.width * Math.min(1, card.music.dlPercent / 100)
                        height: parent.height; radius: 1.5
                        color: card.shell.accent
                        Behavior on width { enabled: card.visible; NumberAnimation { duration: 200 } }
                    }
                }
            }

            // choosing another folder (the folder button in the header)
            FolderBrowser {
                id: browser
                shell: card.shell
                Layout.fillWidth: true
                Layout.fillHeight: true
                nameFilters: card.music.nameFilters
                countNoun: "track"
                onChosen: path => card.shell.prefs.musicFolder = path
            }

            // the tracks
            ListView {
                id: trackList
                visible: !browser.visible
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: ScriptModel {
                    values: library.shown
                    comparisonMode: ObjectComparison.Identity
                }
                delegate: Rectangle {
                    id: row
                    required property string modelData
                    required property int index
                    readonly property bool current: card.music.active && modelData === card.music.path
                    readonly property var parts: card.splitLabel(modelData)
                    width: ListView.view.width
                    height: 48
                    radius: 10
                    color: rowMouse.containsMouse ? Qt.alpha(card.shell.fg, 0.08) : row.current ? Qt.alpha(card.shell.fg, 0.04) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }

                    // number / play on hover / equalizer while it plays
                    Item {
                        id: lead
                        x: 6
                        width: 30; height: parent.height
                        Text {
                            anchors.centerIn: parent
                            visible: !rowMouse.containsMouse && !row.current
                            text: row.index + 1
                            color: card.shell.dim
                            font { family: card.shell.font; pixelSize: 13; features: { "tnum": 1 } }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: rowMouse.containsMouse || (row.current && !card.music.isPlaying)
                            text: card.shell.icon(row.current && card.music.isPlaying ? 0xF03E4 : 0xF040A)
                            color: row.current ? card.shell.accent : card.shell.fg
                            font { family: card.shell.iconFont; pixelSize: 16 }
                        }
                        Item {   // equalizer
                            anchors.centerIn: parent
                            visible: row.current && card.music.isPlaying && !rowMouse.containsMouse
                            width: 13
                            height: 14
                            Repeater {
                                model: 3
                                Rectangle {
                                    id: eqBar
                                    required property int index
                                    x: index * 5
                                    y: 14 - height
                                    width: 3; radius: 1
                                    height: 4
                                    color: card.shell.accent
                                    SequentialAnimation on height {
                                        running: eqBar.visible && card.visible
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 14 - eqBar.index * 3; duration: 260 + eqBar.index * 90; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 4 + eqBar.index; duration: 300 + eqBar.index * 70; easing.type: Easing.InOutSine }
                                    }
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        anchors { left: lead.right; leftMargin: 8; right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: "‎" + row.parts.title
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: row.current ? card.shell.accent : card.shell.fg
                            font { family: card.shell.font; pixelSize: 14; weight: Font.DemiBold }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: row.parts.sub ? "‎" + row.parts.sub : ""
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: card.shell.dim
                            font { family: card.shell.font; pixelSize: 12 }
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: row.current ? card.music.togglePlaying() : card.music.play(card.music.tracks.indexOf(row.modelData))
                    }
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: library.shown.length === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: card.music.tracks.length === 0
                        ? "No music here yet.\nPaste a link above, or pick another folder."
                        : "Nothing matches “" + library.text + "”"
                    color: card.shell.dim
                    font { family: card.shell.font; pixelSize: 13 }
                }
            }
        }
    }
}
