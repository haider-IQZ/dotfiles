import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

ShellRoot {
    id: root

    // Gruvbox Colors
    readonly property color bg: "#1d2021"
    readonly property color bg1: "#282828"
    readonly property color bg2: "#3c3836"
    readonly property color fg: "#ebdbb2"
    readonly property color red: "#fb4934"
    readonly property color green: "#b8bb26"
    readonly property color yellow: "#fabd2f"
    readonly property color blue: "#83a598"
    readonly property color purple: "#d3869b"
    readonly property color aqua: "#8ec07c"
    readonly property color orange: "#fe8019"
    readonly property color gray: "#928374"

    // System stats
    property int cpuPercent: 0
    property string memValue: "0G"
    property int memPercent: 0

    PanelWindow {
        id: bar
        
        anchors {
            top: true
            left: true
            right: true
        }
        
        margins {
            top: 8
            left: 20
            right: 20
        }
        
        implicitHeight: 42
        color: "transparent"
        
        // Main bar container
        Rectangle {
            anchors.fill: parent
            color: root.bg
            radius: 12
            opacity: 0.95
            
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 0
                
                // ═══════════════════════════════════════
                // LEFT - Workspaces (pill style)
                // ═══════════════════════════════════════
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: workspaceRow.width + 12
                    height: 32
                    radius: 10
                    color: root.bg1
                    
                    Row {
                        id: workspaceRow
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Repeater {
                            model: 9
                            
                            Rectangle {
                                property int wsId: index + 1
                                property bool isActive: Hyprland.focusedMonitor?.activeWorkspace?.id === wsId
                                
                                width: isActive ? 32 : 24
                                height: 24
                                radius: 8
                                color: isActive ? root.aqua : "transparent"
                                
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 150 } }
                                
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.wsId
                                    color: parent.isActive ? root.bg : root.gray
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 11
                                    font.bold: parent.isActive
                                }
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch("workspace " + parent.wsId)
                                }
                            }
                        }
                    }
                }
                
                // Spacer
                Item { Layout.fillWidth: true }
                
                // ═══════════════════════════════════════
                // CENTER - Clock
                // ═══════════════════════════════════════
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: clockContent.width + 28
                    height: 32
                    radius: 10
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.aqua }
                        GradientStop { position: 1.0; color: root.blue }
                    }
                    
                    Row {
                        id: clockContent
                        anchors.centerIn: parent
                        spacing: 10
                        
                        Text {
                            text: ""
                            color: root.bg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }
                        
                        Text {
                            id: clockText
                            text: Qt.formatTime(new Date(), "HH:mm")
                            color: root.bg
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
                
                // Spacer
                Item { Layout.fillWidth: true }
                
                // ═══════════════════════════════════════
                // RIGHT - System Stats (fancy pills)
                // ═══════════════════════════════════════
                
                // CPU with progress ring
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 90
                    height: 32
                    radius: 10
                    color: root.bg1
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        
                        // Mini progress circle
                        Item {
                            width: 20
                            height: 20
                            
                            Canvas {
                                id: cpuCanvas
                                anchors.fill: parent
                                
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    
                                    // Background circle
                                    ctx.beginPath()
                                    ctx.arc(10, 10, 8, 0, 2 * Math.PI)
                                    ctx.strokeStyle = root.bg2
                                    ctx.lineWidth = 3
                                    ctx.stroke()
                                    
                                    // Progress arc
                                    ctx.beginPath()
                                    ctx.arc(10, 10, 8, -Math.PI/2, -Math.PI/2 + (2 * Math.PI * root.cpuPercent / 100))
                                    ctx.strokeStyle = root.green
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }
                            }
                        }
                        
                        Column {
                            spacing: -2
                            
                            Text {
                                text: "CPU"
                                color: root.gray
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 8
                            }
                            Text {
                                text: root.cpuPercent + "%"
                                color: root.green
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }
                    }
                }
                
                // Memory with progress bar
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                    width: 100
                    height: 32
                    radius: 10
                    color: root.bg1
                    
                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        
                        Row {
                            spacing: 6
                            
                            Text {
                                text: ""
                                color: root.purple
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                            }
                            Text {
                                text: root.memValue
                                color: root.purple
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                        
                        // Progress bar
                        Rectangle {
                            width: 70
                            height: 4
                            radius: 2
                            color: root.bg2
                            
                            Rectangle {
                                width: parent.width * (root.memPercent / 100)
                                height: parent.height
                                radius: 2
                                
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: root.purple }
                                    GradientStop { position: 1.0; color: root.orange }
                                }
                                
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }
                
                // Network
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                    width: 42
                    height: 32
                    radius: 10
                    color: root.bg1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰖩"
                        color: root.blue
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                    }
                }
                
                // Media Control Button
                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 8
                    width: 42
                    height: 32
                    radius: 10
                    color: mediaPanel.visible ? root.orange : root.bg1
                    
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        color: mediaPanel.visible ? root.bg : root.orange
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 16
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaPanel.visible = !mediaPanel.visible
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // MEDIA CONTROL PANEL (Popup)
    // ═══════════════════════════════════════════════════════════════
    PanelWindow {
        id: mediaPanel
        visible: false
        
        anchors {
            top: true
            right: true
        }
        
        margins {
            top: 58
            right: 20
        }
        
        implicitWidth: 320
        implicitHeight: 140
        color: "transparent"
        
        Rectangle {
            anchors.fill: parent
            radius: 16
            color: root.bg
            opacity: 0.92
            
            // Blur simulation with layered rectangles
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.bg1
                opacity: 0.6
            }
        }
        
        // Content
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            
            // Song Info
            Row {
                spacing: 12
                width: parent.width
                
                // Album art placeholder
                Rectangle {
                    width: 56
                    height: 56
                    radius: 10
                    
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.purple }
                        GradientStop { position: 1.0; color: root.blue }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰎈"
                        color: root.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 24
                    }
                }
                
                Column {
                    spacing: 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 68
                    
                    Text {
                        id: songTitle
                        text: root.mediaSong || "No media playing"
                        color: root.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    
                    Text {
                        id: songArtist
                        text: root.mediaArtist || "—"
                        color: root.gray
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
            }
            
            // Controls
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                // Previous
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: root.bg1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒮"
                        color: root.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaPrev.running = true
                    }
                }
                
                // Play/Pause
                Rectangle {
                    width: 50
                    height: 50
                    radius: 25
                    
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.aqua }
                        GradientStop { position: 1.0; color: root.green }
                    }
                    
                    Text {
                        anchors.centerIn: parent
                        text: root.mediaPlaying ? "󰏤" : "󰐊"
                        color: root.bg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 22
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaToggle.running = true
                    }
                }
                
                // Next
                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: root.bg1
                    
                    Text {
                        anchors.centerIn: parent
                        text: "󰒭"
                        color: root.fg
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 18
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mediaNext.running = true
                    }
                }
            }
        }
    }
    
    // Media properties
    property string mediaSong: ""
    property string mediaArtist: ""
    property bool mediaPlaying: false
    
    // Media processes
    Process {
        id: mediaInfo
        command: ["sh", "-c", "playerctl metadata --format '{{title}}|||{{artist}}|||{{status}}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|||")
                root.mediaSong = parts[0] || ""
                root.mediaArtist = parts[1] || ""
                root.mediaPlaying = parts[2] === "Playing"
            }
        }
    }
    
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: mediaInfo.running = true
    }
    
    Process {
        id: mediaToggle
        command: ["playerctl", "play-pause"]
    }
    
    Process {
        id: mediaPrev
        command: ["playerctl", "previous"]
    }
    
    Process {
        id: mediaNext
        command: ["playerctl", "next"]
    }
    
    // Clock Timer
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clockText.text = Qt.formatTime(new Date(), "HH:mm")
    }
    
    // CPU Process
    Process {
        id: cpuProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print int($2)}'"]
        stdout: SplitParser {
            onRead: data => {
                root.cpuPercent = parseInt(data.trim()) || 0
                cpuCanvas.requestPaint()
            }
        }
    }
    
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }
    
    // Memory Process
    Process {
        id: memProc
        command: ["sh", "-c", "free | awk '/Mem:/ {printf \"%.1fG %d\", $3/1024/1024, $3*100/$2}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split(" ")
                root.memValue = parts[0] || "0G"
                root.memPercent = parseInt(parts[1]) || 0
            }
        }
    }
    
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memProc.running = true
    }
}
