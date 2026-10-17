pragma ComponentBehavior: Bound
// Wallpaper picker, Super+W (`qs ipc call wallpaper pick`). Grows out of the bar's island:
// a search line and a carousel of the wallpaper folder, the picked one in the middle.
//   type to filter · ←/→ (or Tab, scroll) to move · Enter applies · Esc closes
// The bar draws the wallpaper itself (shell.qml, wallWindow) and remembers it, so it's back
// at login. The folder is the bar's setting wallpaperFolder (settings.json; default ~/Pictures).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "Paths.js" as Paths

Scope {
    id: picker
    required property var shell
    property bool open: false
    function toggle() { open = !open }

    // ---------- folder + current wallpaper: the bar's ----------
    readonly property string folder: shell.wallpaperFolder
    readonly property string current: shell.wallpaper

    // ---------- the files ----------
    property var files: []          // absolute paths, sorted by name
    Process {
        id: scan
        command: ["sh", "-c", "find -L \"$1\" -maxdepth 1 -type f | grep -iE '\\.(jpe?g|png|webp|gif|bmp|avif)$' | sort -f", "sh", picker.folder]
        stdout: StdioCollector {
            onStreamFinished: {
                picker.files = this.text.split("\n").filter(l => l !== "")
                picker.selectCurrent()
            }
        }
    }
    function name(p) { const b = p.slice(p.lastIndexOf("/") + 1); const d = b.lastIndexOf("."); return d > 0 ? b.slice(0, d) : b }

    property string query: ""
    readonly property var shown: {
        const q = query.trim().toLowerCase()
        if (!q) return files
        const words = q.split(/\s+/)
        return files.filter(f => { const n = name(f).toLowerCase(); return words.every(w => n.includes(w)) })
    }
    property int index: 0
    onShownChanged: if (index >= shown.length) index = Math.max(0, shown.length - 1)
    function selectCurrent() {
        const i = shown.indexOf(current)
        index = i >= 0 ? i : 0
        carousel.positionViewAtIndex(index, ListView.Center)
    }
    function move(d) { if (shown.length) index = (index + d + shown.length) % shown.length }
    function apply() {
        const f = shown[index]
        if (!f) return
        shell.setWallpaper(f)
        open = false
    }

    onOpenChanged: {
        if (!open) return
        query = ""
        scan.running = true
    }

    // ---------- the window ----------
    PanelWindow {
        id: win
        visible: picker.open || card.shown > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-wallpapers"
        WlrLayershell.keyboardFocus: picker.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        MouseArea { anchors.fill: parent; enabled: picker.open; onClicked: picker.open = false }
        mask: Region { item: picker.open ? win.contentItem : null }

        Rectangle {
            id: card
            // 0 = the pill it grows from, 1 = full size
            property real shown: picker.open ? 1 : 0
            Behavior on shown { NumberAnimation { duration: picker.open ? 240 : 150; easing.type: picker.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.5 } }
            readonly property int fullW: Math.min(900, win.width - 32)
            readonly property int fullH: 244
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 260 + (fullW - 260) * shown
            height: 36 + (fullH - 36) * shown
            radius: 18 + 14 * Math.min(1, shown)
            color: picker.shell.bgDark
            border { color: picker.shell.bgAlt; width: 1 }
            opacity: Math.min(1, shown * 4)
            clip: true
            MouseArea { anchors.fill: parent }   // clicks on the card don't close it

            Item {
                id: content
                anchors { fill: parent; margins: 22 }
                opacity: Math.max(0, Math.min(1, (card.shown - 0.2) / 0.5))

                // search line
                RowLayout {
                    id: header
                    anchors { top: parent.top; left: parent.left; right: parent.right }
                    height: 28
                    spacing: 12
                    Text {
                        text: picker.shell.icon(0xF0349)
                        color: picker.shell.dim
                        font { family: picker.shell.iconFont; pixelSize: 17 }
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: picker.shell.fg
                        cursorDelegate: Rectangle { width: 2; color: picker.shell.accent; visible: input.activeFocus }
                        selectionColor: Qt.alpha(picker.shell.accent, 0.35)
                        font { family: picker.shell.font; pixelSize: 16 }
                        focus: picker.open
                        onTextChanged: { picker.query = text; picker.index = 0 }
                        Connections {
                            target: picker
                            function onOpenChanged() { if (picker.open) { input.text = ""; input.forceActiveFocus() } }
                        }
                        Text {
                            anchors.fill: parent
                            visible: input.text === ""
                            text: "Search wallpapers…"
                            color: picker.shell.dim
                            font: input.font
                        }
                        Keys.onPressed: event => {
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Escape) picker.open = false
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) picker.apply()
                            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab || event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_L)) picker.move(1)
                            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_H)) picker.move(-1)
                            else return
                            event.accepted = true
                        }
                    }
                    Text {
                        text: picker.shown.length ? (picker.index + 1) + "/" + picker.shown.length : "0/0"
                        color: picker.shell.dim
                        font { family: picker.shell.font; pixelSize: 13; features: { "tnum": 1 } }
                    }
                }

                // carousel: the picked one stays in the middle, the rest slide past it
                ListView {
                    id: carousel
                    // full card width, clipped at the card's edges, so nothing shows past the fades
                    anchors { top: header.bottom; topMargin: 18; left: parent.left; right: parent.right; leftMargin: -22; rightMargin: -22 }
                    height: 130
                    orientation: ListView.Horizontal
                    spacing: 14
                    clip: true
                    model: picker.shown
                    currentIndex: picker.index
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - 105
                    preferredHighlightEnd: width / 2 + 105
                    highlightMoveDuration: 280
                    highlightMoveVelocity: -1
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: if (currentIndex !== picker.index && currentIndex >= 0) picker.index = currentIndex
                    WheelHandler {
                        property real acc: 0
                        onWheel: event => {
                            acc += event.angleDelta.y + event.angleDelta.x
                            if (Math.abs(acc) >= 120) { picker.move(acc > 0 ? -1 : 1); acc = 0 }
                        }
                    }

                    delegate: Item {
                        id: tile
                        required property string modelData
                        required property int index
                        readonly property bool selected: index === picker.index
                        width: 210
                        height: carousel.height

                        Rectangle {
                            id: frame
                            anchors.centerIn: parent
                            width: parent.width
                            height: 120
                            radius: 16
                            color: "#121110"
                            scale: tile.selected ? 1 : 0.9
                            opacity: tile.selected ? 1 : 0.5
                            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                            Behavior on opacity { NumberAnimation { duration: 260 } }

                            ClippingRectangle {
                                id: picture
                                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 6 }
                                height: 82
                                radius: 11
                                color: picker.shell.bgAlt
                              Image {
                                id: thumb
                                anchors.fill: parent
                                source: Paths.toFileUrl(tile.modelData)
                                sourceSize { width: 420; height: 224 }
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                              }
                            }
                            Text {
                                anchors { left: parent.left; right: parent.right; top: picture.bottom; topMargin: 7; leftMargin: 10; rightMargin: 10 }
                                horizontalAlignment: Text.AlignHCenter
                                text: picker.name(tile.modelData)
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                color: tile.selected ? picker.shell.fg : picker.shell.dim
                                font { family: picker.shell.font; pixelSize: 13; weight: tile.selected ? Font.DemiBold : Font.Normal }
                            }
                            // selection ring
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border { width: 2; color: tile.selected ? picker.shell.accent : Qt.alpha(picker.shell.fg, 0.06) }
                                Behavior on border.color { ColorAnimation { duration: 200 } }
                            }
                            // the wallpaper that's on now
                            Rectangle {
                                visible: tile.modelData === picker.current
                                anchors { top: parent.top; right: parent.right; margins: 12 }
                                width: 8; height: 8; radius: 4
                                color: picker.shell.accent
                                border { color: "#000000"; width: 1 }
                            }
                        }
                        MouseArea {
                            anchors.fill: frame
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { if (tile.selected) picker.apply(); else picker.index = tile.index }
                        }
                    }
                }
                // fade the carousel out at both edges
                Rectangle {
                    anchors { left: carousel.left; top: carousel.top; bottom: carousel.bottom }
                    width: 110
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: card.color }
                        GradientStop { position: 1; color: Qt.alpha(card.color, 0) }
                    }
                }
                Rectangle {
                    anchors { right: carousel.right; top: carousel.top; bottom: carousel.bottom }
                    width: 110
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.alpha(card.color, 0) }
                        GradientStop { position: 1; color: card.color }
                    }
                }
                Text {
                    anchors.centerIn: carousel
                    visible: picker.shown.length === 0 && !scan.running
                    text: picker.files.length === 0 ? "No pictures in " + picker.folder : "No matches for “" + picker.query + "”"
                    textFormat: Text.PlainText
                    color: picker.shell.dim
                    font { family: picker.shell.font; pixelSize: 14 }
                }

                Text {
                    anchors { right: parent.right; bottom: parent.bottom }
                    text: "Enter to apply"
                    color: picker.shell.dim
                    font { family: picker.shell.font; pixelSize: 12 }
                }
            }
        }
    }
}
