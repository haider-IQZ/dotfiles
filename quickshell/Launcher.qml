pragma ComponentBehavior: Bound
// Launcher (replaces rofi/fuzzel). Super+D, or `qs ipc call launcher toggle`. Grows out of
// the bar's island.
//   Nothing typed: your apps, the ones you open most first.
//   Typing: searches apps and actions at once ("reb" finds Reboot, "wall" the wallpaper picker).
//   Enter opens a submenu or runs the row; Backspace on an empty search or Esc goes back.
// Apps are ranked like Omarchy's search, plus the ones you open often first (counted in
// $XDG_STATE_HOME/bar/launcher.json).
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
    id: launcher
    required property var shell
    property bool open: false
    function toggle() { open = !open }
    function close() { open = false }

    // ---------- launch counts ----------
    FileView {
        path: launcher.shell.stateDir + "/launcher.json"
        printErrors: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: writeAdapter()
        JsonAdapter {
            id: usage
            property var counts: ({})   // desktop id -> times launched
        }
    }

    // ---------- apps ----------
    readonly property var apps: {
        const seen = {}
        return DesktopEntries.applications.values.filter(e => {
            if (!e || e.noDisplay || !e.name || seen[e.id]) return false
            seen[e.id] = true
            return true
        })
    }
    function launchApp(e) {
        const counts = Object.assign({}, usage.counts || {})
        counts[e.id] = (counts[e.id] || 0) + 1
        usage.counts = counts
        if (e.runInTerminal)
            Quickshell.execDetached([Quickshell.env("TERMINAL") || "foot", "-e"].concat(e.command))
        else
            e.execute()
        close()
    }
    function appRow(e) {
        return { label: e.name, sub: e.genericName || e.comment || "", image: Quickshell.iconPath(e.icon, true), glyph: 0xF08C6,
                 keys: [e.genericName, e.comment, (e.keywords || []).join(" "), e.id].join(" "),
                 used: (usage.counts || {})[e.id] || 0, run: () => launchApp(e) }
    }

    // ---------- search ----------
    function words(v) {
        return String(v || "").replace(/([a-z0-9])([A-Z])/g, "$1 $2").replace(/[._:/\\-]+/g, " ")
            .toLowerCase().split(/[^a-z0-9]+/).filter(w => w)
    }
    // each word you type must match somewhere; a word that starts a word of the label counts
    // most ("fi ro" -> File Roller), then inside the label, other keywords, acronym
    function score(row, q) {
        const name = row.label.toLowerCase(), nameWords = words(row.label)
        const hay = (row.label + " " + (row.keys || "")).toLowerCase()
        const acr = words(row.label + " " + (row.keys || "")).map(w => w[0]).join("")
        let total = 0
        for (const t of q.split(/\s+/).filter(t => t)) {
            if (nameWords.some(w => w.startsWith(t))) total += 300
            else if (name.includes(t)) total += 200
            else if (hay.includes(t)) total += 100
            else if (t.length <= 5 && acr.includes(t)) total += 80
            else return -1
        }
        if (name.startsWith(q)) total += 1000          // the whole thing starts the label
        else if (name.includes(q)) total += 400
        return total * 10 - name.length + Math.min(row.used || 0, 50) * 20
    }
    function ranked(rows, q) {
        if (!q) return rows
        return rows.map(r => ({ r: r, s: score(r, q) })).filter(x => x.s >= 0)
            .sort((a, b) => b.s - a.s || a.r.label.localeCompare(b.r.label)).map(x => x.r)
    }

    // ---------- the menu ----------
    function confirmRows(what, glyph, action) {
        return [ { label: "Yes, " + what.toLowerCase(), glyph: glyph, danger: true, run: action },
                 { label: "Cancel", glyph: 0xF0156, run: () => back() } ]
    }
    // Keep the session alive while an app is still open, including a save dialog.
    property bool loggingOut: false
    property double logoutDeadline: 0
    property int logoutRevision: 0
    property string logoutMessage: ""
    function logout() {
        if (loggingOut) return
        close()
        logoutMessage = ""
        loggingOut = true
        logoutRevision++
        logoutDeadline = Date.now() + 15000
        for (const t of Hyprland.toplevels.values) {
            const addr = String(t.address).replace(/^0x/, "")
            if (/^[0-9a-fA-F]+$/.test(addr) && addr !== "0")
                shell.hyprDispatch('hl.dsp.window.close({ window = "address:0x' + addr + '" })', "closewindow address:0x" + addr)
        }
        logoutPoll.start()
        logoutTimeout.start()
    }
    function cancelLogout(message) {
        loggingOut = false
        logoutPoll.stop()
        logoutTimeout.stop()
        logoutMessage = message
        open = true
    }
    Timer {
        id: logoutTimeout
        interval: 15000
        onTriggered: launcher.cancelLogout("Logout cancelled: windows are still open or could not be checked. Save your work and try again.")
    }
    Timer {
        id: logoutPoll
        interval: 250
        repeat: true
        onTriggered: if (!logoutProbe.running) {
            logoutProbe.revision = launcher.logoutRevision
            logoutProbe.pending = true
            logoutProbe.running = true
        }
    }
    Process {
        id: logoutProbe
        property int revision: 0
        property bool pending: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector { id: logoutClients }
        onExited: (code, status) => {
            pending = false
            if (!launcher.loggingOut || revision !== launcher.logoutRevision) return
            let clients = null
            try { clients = JSON.parse(logoutClients.text) } catch (e) {}
            if (code !== 0 || status !== 0 || !Array.isArray(clients)) {
                launcher.cancelLogout("Logout cancelled: could not check open windows.")
            } else if (Date.now() >= launcher.logoutDeadline) {
                launcher.cancelLogout("Logout cancelled: windows are still open. Save your work and try again.")
            } else if (clients.length === 0) {
                launcher.loggingOut = false
                logoutPoll.stop()
                logoutTimeout.stop()
                launcher.shell.hyprDispatch("hl.dsp.exit()", "exit")
            }
        }
        onRunningChanged: if (!running && pending) {
            pending = false
            if (launcher.loggingOut && revision === launcher.logoutRevision)
                launcher.cancelLogout("Logout cancelled: could not check open windows.")
        }
    }

    readonly property var menu: [
        { label: "Apps", glyph: 0xF003B, children: () => apps.map(appRow)
            .sort((a, b) => b.used - a.used || a.label.localeCompare(b.label)) },
        { label: "Wallpaper", sub: "Pick a wallpaper (Super+W)", glyph: 0xF02E9, keys: "background wallpapers picker",
            run: () => { close(); shell.pickWallpaper() } },
        { label: "Power", sub: "Suspend, log out, reboot, shut down", glyph: 0xF0425, keys: "system session", children: () => [
            { label: "Suspend", glyph: 0xF04B2, keys: "sleep power", run: () => { close(); Quickshell.execDetached(["systemctl", "suspend"]) } },
            { label: "Log out", glyph: 0xF0343, keys: "logout exit leave power", confirm: true,
              children: () => confirmRows("Log out", 0xF0343, () => logout()) },
            { label: "Reboot", glyph: 0xF0709, keys: "restart power", confirm: true,
              children: () => confirmRows("Reboot", 0xF0709, () => { close(); Quickshell.execDetached(["systemctl", "reboot"]) }) },
            { label: "Shut down", glyph: 0xF0425, keys: "shutdown poweroff power off", confirm: true,
              children: () => confirmRows("Shut down", 0xF0425, () => { close(); Quickshell.execDetached(["systemctl", "poweroff"]) }) } ] },
        { label: "Toggles", sub: "Do Not Disturb", glyph: 0xF0521, children: () => [
            { label: "Do Not Disturb", glyph: 0xF009B, keys: "notifications dnd quiet", check: shell.dnd, stay: true,
              run: () => { shell.dnd = !shell.dnd } } ] }
    ]

    // ---------- where we are ----------
    property var stack: []        // submenus opened, deepest last
    property string query: ""
    onQueryChanged: current = 0
    property int current: 0
    property int version: 0       // bumped to rebuild the rows after a toggle
    readonly property var rows: {
        version
        const q = query.trim().toLowerCase()
        if (stack.length > 0) return ranked(stack[stack.length - 1].children(), q)
        if (!q) return menu[0].children()
        // search everything: apps, plus every menu row and what's in its submenu (not the
        // app list again)
        let all = apps.map(appRow)
        for (const m of menu) {
            if (m.label === "Apps") continue
            all.push(m)
            if (m.children)
                for (const c of m.children()) all.push(Object.assign({}, c, { parent: m.label }))
        }
        return ranked(all, q)
    }
    onRowsChanged: if (current >= rows.length) current = 0

    function activate(row) {
        if (!row) return
        if (row.children) { stack = stack.concat([row]); query = ""; input.text = ""; current = 0; return }
        row.run()
        if (row.stay) version++
    }
    function back() {
        if (stack.length === 0) { close(); return }
        stack = stack.slice(0, -1); current = 0
    }
    // true for a moment after opening: the rows slide in then (see the delegate)
    property bool justOpened: false
    Timer { id: openedTimer; interval: 250; onTriggered: launcher.justOpened = false }
    onOpenChanged: {
        if (!open) return
        justOpened = true
        openedTimer.restart()
        stack = []; query = ""; current = 0
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.open = true }
        function close(): void { launcher.open = false }
        function menu(path: string): void {   // open straight into a submenu: `menu Power`
            launcher.open = true
            for (const name of path.split("/")) {
                const r = launcher.rows.find(x => x.label.toLowerCase() === name.toLowerCase())
                if (r && r.children) launcher.activate(r)
            }
        }
    }

    // ---------- the window ----------
    PanelWindow {
        id: win
        visible: launcher.open || card.shown > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "bar-launcher"
        WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        // click outside = close; release input as soon as the close animation starts
        MouseArea { anchors.fill: parent; enabled: launcher.open; onClicked: launcher.close() }
        mask: Region { item: launcher.open ? win.contentItem : null }

        Rectangle {
            id: card
            readonly property int padding: 18
            readonly property int rowH: 52
            readonly property int rowGap: 4
            readonly property int visibleRows: 6
            readonly property int headerH: 34
            readonly property int noticeHeight: logoutNotice.visible ? logoutNotice.implicitHeight + 10 : 0
            readonly property int rowsHeight: visibleRows * rowH + (visibleRows - 1) * rowGap
            readonly property int fullW: Math.min(540, win.width - 32)
            readonly property int fullH: padding + headerH + 13 + 1 + 10 + noticeHeight + rowsHeight + padding

            // 0 = the bar's pill it grows out of, 1 = full size
            property real shown: launcher.open ? 1 : 0
            Behavior on shown { NumberAnimation { duration: launcher.open ? 240 : 150; easing.type: launcher.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.5 } }
            anchors.horizontalCenter: parent.horizontalCenter
            y: 8
            width: 260 + (fullW - 260) * shown
            height: 36 + (fullH - 36) * shown
            radius: 18 + 12 * Math.min(1, shown)
            color: launcher.shell.bgDark
            border { color: launcher.shell.bgAlt; width: 1 }
            opacity: Math.min(1, shown * 4)
            clip: true
            enabled: launcher.open
            MouseArea { anchors.fill: parent }   // clicks on the card don't close it

            Item {
                anchors.fill: parent
                opacity: Math.max(0, Math.min(1, (card.shown - 0.2) / 0.5))

                // ----- search line -----
                RowLayout {
                    id: search
                    anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: card.padding; leftMargin: card.padding + 4; rightMargin: card.padding + 4 }
                    height: card.headerH
                    spacing: 12
                    Text {
                        text: launcher.stack.length > 0 ? "‹" : launcher.shell.icon(0xF0349)
                        color: launcher.shell.dim
                        font { family: launcher.stack.length > 0 ? launcher.shell.font : launcher.shell.iconFont; pixelSize: launcher.stack.length > 0 ? 22 : 17 }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6
                            enabled: launcher.stack.length > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcher.back()
                        }
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        color: launcher.shell.fg
                        cursorDelegate: Rectangle { width: 2; color: launcher.shell.accent; visible: input.activeFocus }
                        selectionColor: Qt.alpha(launcher.shell.accent, 0.35)
                        selectedTextColor: launcher.shell.fg
                        font { family: launcher.shell.font; pixelSize: 16 }
                        focus: launcher.open
                        onTextChanged: launcher.query = text
                        Component.onCompleted: forceActiveFocus()
                        Connections {
                            target: launcher
                            function onOpenChanged() { if (launcher.open) { input.text = ""; input.forceActiveFocus() } }
                        }
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: input.text === ""
                            text: (launcher.stack.length > 0 ? launcher.stack[launcher.stack.length - 1].label : "Search") + "…"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: launcher.shell.dim
                            font: input.font
                        }
                        Keys.onPressed: event => {
                            const n = launcher.rows.length
                            const ctrl = event.modifiers & Qt.ControlModifier
                            if (event.key === Qt.Key_Escape) launcher.back()
                            else if (event.key === Qt.Key_Backspace && input.text === "" && launcher.stack.length > 0) launcher.back()
                            else if (event.key === Qt.Key_Left && input.text === "" && launcher.stack.length > 0) launcher.back()
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) launcher.activate(launcher.rows[launcher.current])
                            else if (event.key === Qt.Key_Right && input.text === "" && launcher.rows[launcher.current]?.children) launcher.activate(launcher.rows[launcher.current])
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                                launcher.current = n ? (launcher.current + 1) % n : 0
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                                launcher.current = n ? (launcher.current - 1 + n) % n : 0
                            else return
                            event.accepted = true
                        }
                    }
                }

                Rectangle {
                    id: divider
                    anchors { top: search.bottom; topMargin: 13; left: parent.left; right: parent.right; leftMargin: card.padding; rightMargin: card.padding }
                    height: 1
                    color: launcher.shell.bgAlt
                }

                Text {
                    id: logoutNotice
                    anchors { top: divider.bottom; left: divider.left; right: divider.right; topMargin: 10 }
                    visible: launcher.logoutMessage !== ""
                    height: visible ? implicitHeight : 0
                    text: launcher.logoutMessage
                    textFormat: Text.PlainText
                    wrapMode: Text.WordWrap
                    color: launcher.shell.yellow
                    font { family: launcher.shell.font; pixelSize: 13 }
                }

                // ----- the rows -----
                Item {
                    id: results
                    anchors { top: divider.bottom; topMargin: 10 + card.noticeHeight; left: parent.left; right: parent.right }
                    height: card.rowsHeight
                    ListView {
                        id: list
                        anchors.fill: parent
                        clip: true
                        spacing: card.rowGap
                        model: launcher.rows
                        currentIndex: launcher.current
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: 160
                        highlightMoveVelocity: -1
                        highlightResizeDuration: 0
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        // Defer until the new model/layout settles, including when the index was already zero.
                        function resetScroll() { Qt.callLater(() => list.positionViewAtBeginning()) }
                        Connections {
                            target: launcher
                            function onOpenChanged() { list.resetScroll() }
                            function onQueryChanged() { list.resetScroll() }
                            function onStackChanged() { list.resetScroll() }
                        }

                        // the selected row: a warm dark plate with a mint edge, gliding between rows
                        highlight: Item {
                            width: list.width
                            height: card.rowH
                            Rectangle {
                                x: card.padding + 4
                                width: parent.width - x - card.padding
                                height: parent.height
                                radius: 14
                                color: launcher.shell.hoverStrong
                            }
                            Rectangle {
                                x: card.padding - 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 24
                                radius: 1.5
                                color: launcher.shell.accent
                            }
                        }

                        delegate: Item {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool selected: index === launcher.current
                            readonly property var r: modelData
                            readonly property string sub: r.sub || r.parent || ""
                            width: list.width
                            height: card.rowH

                            // rows slide in a little when the list opens or changes
                            opacity: 0
                            transform: Translate { id: slideIn; y: 6 }
                            // (only right after opening, staggered; typing just swaps the rows)
                            Component.onCompleted: {
                                if (launcher.justOpened && index < card.visibleRows) appear.start()
                                else { opacity = 1; slideIn.y = 0 }
                            }
                            SequentialAnimation {
                                id: appear
                                PauseAnimation { duration: row.index * 15 }
                                ParallelAnimation {
                                    NumberAnimation { target: row; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: slideIn; property: "y"; to: 0; duration: 180; easing.type: Easing.OutCubic }
                                }
                            }

                            Rectangle {   // hover (the selected one has the highlight instead)
                                x: card.padding + 4
                                width: parent.width - x - card.padding
                                height: parent.height
                                radius: 14
                                color: launcher.shell.hover
                                opacity: rowMouse.containsMouse && !row.selected ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                            }

                            Rectangle {
                                id: iconTile
                                x: card.padding + 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 34; height: 34
                                radius: 10
                                color: "#121110"
                                border { color: Qt.alpha(launcher.shell.fg, 0.06); width: 1 }
                                Image {
                                    id: appIcon
                                    visible: !!row.r.image && status !== Image.Error
                                    anchors.centerIn: parent
                                    width: 22; height: 22
                                    source: row.r.image || ""
                                    sourceSize.width: width * Screen.devicePixelRatio
                                    sourceSize.height: height * Screen.devicePixelRatio
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }
                                Text {
                                    visible: !row.r.image || appIcon.status === Image.Error
                                    anchors.centerIn: parent
                                    text: launcher.shell.icon(row.r.glyph || 0xF08C6)
                                    color: row.r.danger ? launcher.shell.red : launcher.shell.accent
                                    font { family: launcher.shell.iconFont; pixelSize: 18 }
                                }
                            }
                            Column {
                                anchors { left: iconTile.right; leftMargin: 12; right: trail.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: row.r.label
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: row.r.danger ? launcher.shell.red : launcher.shell.fg
                                    font { family: launcher.shell.font; pixelSize: 15; weight: Font.DemiBold }
                                }
                                Text {
                                    width: parent.width
                                    visible: row.sub !== ""
                                    text: row.sub
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: launcher.shell.dim
                                    font { family: launcher.shell.font; pixelSize: 12 }
                                }
                            }
                            Text {
                                id: trail
                                anchors { right: parent.right; rightMargin: card.padding + 14; verticalCenter: parent.verticalCenter }
                                width: 14
                                text: row.r.check ? "✓" : (row.r.children && !row.r.confirm ? "›" : "")
                                color: row.r.check ? launcher.shell.accent : launcher.shell.dim
                                font { family: launcher.shell.font; pixelSize: 18 }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { launcher.current = row.index; launcher.activate(row.r) }
                            }
                        }
                    }
                    // soft edges instead of a scrollbar
                    Rectangle {
                        anchors { top: parent.top; left: parent.left; right: parent.right }
                        height: 24
                        opacity: list.contentHeight > list.height ? Math.max(0, Math.min(1, (list.contentY - list.originY) / height)) : 0
                        gradient: Gradient {
                            GradientStop { position: 0; color: card.color }
                            GradientStop { position: 1; color: Qt.alpha(card.color, 0) }
                        }
                    }
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                        height: 24
                        opacity: list.contentHeight > list.height
                            ? Math.max(0, Math.min(1, (list.originY + list.contentHeight - list.height - list.contentY) / height)) : 0
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.alpha(card.color, 0) }
                            GradientStop { position: 1; color: card.color }
                        }
                    }
                    Text {
                        anchors.fill: parent
                        visible: launcher.rows.length === 0
                        text: launcher.query ? "No matches for “" + launcher.query + "”" : "Nothing here yet"
                        textFormat: Text.PlainText
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        wrapMode: Text.Wrap
                        color: launcher.shell.dim
                        font { family: launcher.shell.font; pixelSize: 14 }
                    }
                }
            }
        }
    }
}
