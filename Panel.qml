import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Panel for Cerkak Player
// Complete playback controls, interactive progress seeker, volume slider,
// searchable list of all 230+ stories, and custom YouTube playlist manager.
Panel {
  id: root
  moduleName: "cerkak_player"
  ipcTarget: "cerkak_player"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property string playerScript: Qt.resolvedUrl("cerkak-player").toString().replace(/^file:\/\//, "")

  property var localPlayerState: null
  property var playerState: (hostWidget && hostWidget.playerState) ? hostWidget.playerState : localPlayerState
  property var playlistData: null
  property var allStories: playlistData && Array.isArray(playlistData.items) ? playlistData.items : []
  property string searchQuery: ""
  property var filteredStories: Model.filterStories(allStories, searchQuery)

  property bool showNowPlayer: setting("showNowPlayer", false)
  property bool customPlaylistOpen: false
  property string customUrlInput: ""
  property string statusFeedback: ""
  property bool isFetchingPlaylist: false

  readonly property bool isPlaying: playerState && playerState.playing === true
  readonly property bool isPaused: playerState && playerState.paused === true
  readonly property int currentIndex: playerState && playerState.index !== undefined ? playerState.index : 0
  readonly property string currentTitle: playerState && playerState.title ? playerState.title : "Cerkak Basa Jawa"
  readonly property string currentFullTitle: playerState && playerState.fullTitle ? playerState.fullTitle : ""
  readonly property string currentReader: playerState && playerState.reader ? playerState.reader : "Slamet Prasojo"
  readonly property string currentThumbnail: playerState && playerState.thumbnail ? playerState.thumbnail : ""
  readonly property real currentPosition: playerState && playerState.position !== undefined ? playerState.position : 0.0
  readonly property real currentDuration: playerState && playerState.duration !== undefined ? playerState.duration : 0.0
  readonly property string currentPosFormatted: playerState && playerState.positionFormatted ? playerState.positionFormatted : Model.formatTime(currentPosition)
  readonly property string currentDurFormatted: playerState && playerState.durationFormatted ? playerState.durationFormatted : Model.formatTime(currentDuration)
  readonly property real currentProgress: playerState && playerState.progress !== undefined ? playerState.progress : (currentDuration > 0 ? (currentPosition / currentDuration) : 0.0)
  readonly property int currentVolume: playerState && playerState.volume !== undefined ? playerState.volume : 75
  readonly property bool shuffleEnabled: playerState && playerState.shuffle === true
  readonly property bool isDefaultPlaylist: playerState ? (playerState.isDefaultPlaylist !== false) : true
  readonly property string playlistTitle: playerState && playerState.playlistTitle ? playerState.playlistTitle : "Cerita Cekak Basa Jawa - Slamet Prasojo"

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function applyStatus(data) {
    if (!data) return
    if (typeof data === "string") {
      try {
        data = JSON.parse(data)
      } catch (e) {
        return
      }
    }
    if (data && typeof data === "object") {
      if (data.status && typeof data.status === "object") {
        data = data.status
      }
      root.localPlayerState = data
      if (root.hostWidget && ("playerState" in root.hostWidget)) {
        root.hostWidget.playerState = data
      }
    }
  }

  function refreshStatus() {
    if (statusProc.running) return
    statusProc.command = [playerScript, "status"]
    statusProc.running = true
  }

  function open() {
    refreshStatus()
    refreshList()
    statusPollTimer.restart()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function") {
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    }
    return false
  }

  function runCmd(action, arg) {
    var cmd = [playerScript, action]
    if (arg !== undefined && arg !== null) {
      cmd.push(String(arg))
    }
    actionProc.command = cmd
    actionProc.running = true
  }

  function playIndex(idx) {
    runCmd("play", idx)
  }

  function togglePlayPause() {
    runCmd("play-pause")
  }

  function nextTrack() {
    runCmd("next")
  }

  function prevTrack() {
    runCmd("prev")
  }

  function stopTrack() {
    runCmd("stop")
  }

  function toggleShuffle() {
    runCmd("shuffle")
  }

  function seekTo(seconds) {
    runCmd("seek", seconds)
  }

  function setVolume(vol) {
    runCmd("volume", vol)
  }

  function refreshList() {
    if (listProc.running) return
    listProc.command = [playerScript, "list"]
    listProc.running = true
  }

  function submitCustomPlaylist() {
    var url = String(customUrlInput).trim()
    if (!url) return
    root.isFetchingPlaylist = true
    root.statusFeedback = "Mengunduh playlist YouTube..."
    playlistProc.command = [playerScript, "playlist", url]
    playlistProc.running = true
  }

  function resetToDefaultPlaylist() {
    root.isFetchingPlaylist = true
    root.statusFeedback = "Mengembalikan ke playlist default..."
    playlistProc.command = [playerScript, "reset-playlist"]
    playlistProc.running = true
  }

  Component.onCompleted: {
    refreshStatus()
    refreshList()
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw) root.applyStatus(raw)
        else root.refreshStatus()
      }
    }
  }

  Process {
    id: statusProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw) root.applyStatus(raw)
      }
    }
  }

  Timer {
    id: statusPollTimer
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: root.refreshStatus()
  }

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/cerkak_player/status.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyStatus(text())
    onFileChanged: {
      reload()
      root.applyStatus(text())
    }
  }

  Process {
    id: listProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (!raw) return
        try {
          var parsed = JSON.parse(raw)
          if (parsed && parsed.items) {
            root.playlistData = parsed
          }
        } catch (e) {}
      }
    }
  }

  Process {
    id: playlistProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isFetchingPlaylist = false
        var raw = String(text || "").trim()
        if (raw) {
          try {
            var res = JSON.parse(raw)
            if (res.ok) {
              root.statusFeedback = res.message || "Playlist berhasil diperbarui!"
              root.customPlaylistOpen = false
              root.customUrlInput = ""
              root.refreshList()
            } else {
              root.statusFeedback = "Gagal: " + (res.error || "Terjadi kesalahan")
            }
          } catch (e) {
            root.statusFeedback = "Selesai memperbarui."
            root.refreshList()
          }
        }
        feedbackTimer.restart()
      }
    }
  }

  Timer {
    id: feedbackTimer
    interval: 4000
    onTriggered: root.statusFeedback = ""
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(Style.space(root.showNowPlayer ? (root.customPlaylistOpen ? 700 : 620) : (root.customPlaylistOpen ? 530 : 450)))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === " ") root.togglePlayPause()
        else if (t === "n" || t === "N") root.nextTrack()
        else if (t === "p" || t === "P") root.prevTrack()
        else if (t === "s" || t === "S") root.toggleShuffle()
        else if (t === "m" || t === "M") root.showNowPlayer = !root.showNowPlayer
        else if (t === "x" || t === "X") root.stopTrack()
        else if (t === "[") root.seekTo(Math.max(0, root.currentPosition - 10))
        else if (t === "]") root.seekTo(Math.min(root.currentDuration, root.currentPosition + 10))
      }

      Column {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: Style.space(14)
        spacing: Style.space(12)

        // ==================== 1. HEADER ====================
        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰗃"
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.title * 1.3)
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(Style.space(180), parent.width - headerActions.width - Style.space(42))
            spacing: Style.space(2)

            Text {
              text: "Cerkak Player"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Math.round(Style.font.title * 0.95)
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.isPlaying
                ? ((root.isPaused ? "Ngaso: " : "Memutar: ") + root.currentTitle)
                : ("Cerita Cekak Basa Jawa · " + root.currentReader)
              color: root.isPlaying ? Color.accent : Style.normalBorderFor(root.contentForeground, Color.dim)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.small
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Row {
            id: headerActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            // Toggle Player Card button
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: playerToggleRow.implicitWidth + Style.space(12)
              height: Style.space(24)
              radius: Style.space(12)
              color: root.showNowPlayer ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.08)
              border.color: root.showNowPlayer ? Color.accent : Qt.rgba(1, 1, 1, 0.15)
              border.width: 1

              Row {
                id: playerToggleRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.showNowPlayer ? "󰅖" : "󰐊"
                  color: root.showNowPlayer ? Color.accent : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.showNowPlayer ? "Tutup Pemutar" : "Pemutar"
                  color: root.showNowPlayer ? Color.accent : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.small * 0.9)
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.showNowPlayer = !root.showNowPlayer
              }
            }

            // Play / Pause button & indicator
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: statusRow.implicitWidth + Style.space(14)
              height: Style.space(24)

              Rectangle {
                anchors.fill: parent
                radius: Style.space(12)
                color: root.isPlaying
                  ? (root.isPaused ? Qt.rgba(1, 0.7, 0, 0.15) : Qt.rgba(0.2, 0.8, 0.3, 0.15))
                  : Qt.rgba(1, 1, 1, 0.08)
                border.color: root.isPlaying
                  ? (root.isPaused ? Qt.rgba(1, 0.7, 0, 0.4) : Qt.rgba(0.2, 0.8, 0.3, 0.4))
                  : Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
              }

              Row {
                id: statusRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.isPlaying ? (root.isPaused ? "󰐊" : "󰏤") : "󰐊"
                  color: root.isPlaying ? (root.isPaused ? "#e0af68" : "#9ece6a") : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.isPlaying ? (root.isPaused ? "Ngaso" : "Memutar") : "Putar"
                  color: root.isPlaying ? (root.isPaused ? "#e0af68" : "#9ece6a") : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.small * 0.95)
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePlayPause()
              }
            }
          }
        }

        // ==================== 2. NOW PLAYING CARD ====================
        BorderSurface {
          id: nowPlayingCard
          width: parent.width
          visible: root.showNowPlayer
          height: root.showNowPlayer ? (nowPlayingCol.implicitHeight + Style.space(18)) : 0
          implicitHeight: height
          clip: true
          radius: Style.spacing.labelGap

          Column {
            id: nowPlayingCol
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Style.space(10)
            spacing: Style.space(8)
            visible: root.showNowPlayer

            // Progress bar and seek slider
            Column {
              width: parent.width
              spacing: Style.space(4)

              Item {
                id: progressTrack
                width: parent.width
                height: Style.space(12)

                Rectangle {
                  id: bgBar
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: Style.space(4)
                  radius: Style.space(2)
                  color: Qt.rgba(1, 1, 1, 0.12)
                }

                Rectangle {
                  id: fillBar
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: bgBar.left
                  width: Math.max(0, Math.min(bgBar.width, bgBar.width * root.currentProgress))
                  height: Style.space(4)
                  radius: Style.space(2)
                  color: Color.accent
                }

                Rectangle {
                  id: handle
                  anchors.verticalCenter: parent.verticalCenter
                  x: Math.max(0, Math.min(progressTrack.width - width, fillBar.width - width / 2))
                  width: Style.space(10)
                  height: Style.space(10)
                  radius: Style.space(5)
                  color: Color.accent
                  visible: seekMouse.containsMouse || seekMouse.pressed
                }

                MouseArea {
                  id: seekMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    if (root.currentDuration > 0) {
                      var ratio = Math.max(0.0, Math.min(1.0, mouse.x / progressTrack.width))
                      root.seekTo(ratio * root.currentDuration)
                    }
                  }
                }
              }

              Row {
                width: parent.width
                Item {
                  width: parent.width / 2
                  height: posText.implicitHeight
                  Text {
                    id: posText
                    anchors.left: parent.left
                    text: root.currentPosFormatted
                    color: Style.normalBorderFor(root.contentForeground, Color.dim)
                    font.family: root.contentFontFamily
                    font.pixelSize: Math.round(Style.font.small * 0.9)
                  }
                }

                Item {
                  width: parent.width / 2
                  height: durText.implicitHeight
                  Text {
                    id: durText
                    anchors.right: parent.right
                    text: root.currentDurFormatted
                    color: Style.normalBorderFor(root.contentForeground, Color.dim)
                    font.family: root.contentFontFamily
                    font.pixelSize: Math.round(Style.font.small * 0.9)
                  }
                }
              }
            }

            // Main Playback Controls
            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(18)

              // Shuffle button
              Item {
                width: Style.space(36)
                height: Style.space(36)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  anchors.fill: parent
                  radius: Style.space(18)
                  color: root.shuffleEnabled ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : "transparent"
                  border.color: root.shuffleEnabled ? Color.accent : "transparent"
                  border.width: 1
                }

                Text {
                  anchors.centerIn: parent
                  text: "󰒞"
                  color: root.shuffleEnabled ? Color.accent : Style.normalBorderFor(root.contentForeground, Color.dim)
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.title * 0.95)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleShuffle()
                }
              }

              // Previous button
              Item {
                width: Style.space(36)
                height: Style.space(36)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "󰒮"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.title * 1.1)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.prevTrack()
                }
              }

              // Play / Pause prominent circular button
              Item {
                width: Style.space(46)
                height: Style.space(46)
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                  anchors.fill: parent
                  radius: width / 2
                  color: Color.accent
                }

                Text {
                  anchors.centerIn: parent
                  text: root.isPlaying && !root.isPaused ? "󰏤" : "󰐊"
                  color: Color.background
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.title * 1.2)
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.togglePlayPause()
                }
              }

              // Stop button
              Item {
                width: Style.space(36)
                height: Style.space(36)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "󰓛"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.title * 0.95)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.stopTrack()
                }
              }

              // Next button
              Item {
                width: Style.space(36)
                height: Style.space(36)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "󰒭"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.title * 1.1)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.nextTrack()
                }
              }
            }

            // Volume Row
            Row {
              width: parent.width
              spacing: Style.space(10)
              anchors.horizontalCenter: parent.horizontalCenter

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Model.volumeIcon(root.currentVolume, false)
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              Item {
                id: volTrack
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(80)
                height: Style.space(12)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  height: Style.space(3)
                  radius: Style.space(2)
                  color: Qt.rgba(1, 1, 1, 0.12)
                }

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(0, Math.min(parent.width, parent.width * (root.currentVolume / 100.0)))
                  height: Style.space(3)
                  radius: Style.space(2)
                  color: Style.normalBorderFor(root.contentForeground, Color.accent)
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: function(mouse) {
                    var v = Math.round(Math.max(0, Math.min(100, (mouse.x / volTrack.width) * 100)))
                    root.setVolume(v)
                  }
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.currentVolume + "%"
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Math.round(Style.font.small * 0.95)
                width: Style.space(32)
                horizontalAlignment: Text.AlignRight
              }
            }
          }
        }

        // ==================== 3. PLAYLIST SOURCE & SEARCH ====================
        Column {
          width: parent.width
          spacing: Style.space(6)

          // Header row with story count & Playlist toggle
          Row {
            width: parent.width

            Row {
              id: leftTitleRow
              spacing: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                text: "Daftar Cerkak"
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }

              Text {
                text: "(" + root.filteredStories.length + (root.filteredStories.length !== root.allStories.length ? " / " + root.allStories.length : "") + ")"
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.small
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Item {
              width: Math.max(Style.space(8), parent.width - leftTitleRow.implicitWidth - playlistToggleBtn.width)
              height: 1
            }

            // Playlist URL toggle button
            Rectangle {
              id: playlistToggleBtn
              anchors.verticalCenter: parent.verticalCenter
              width: playlistBtnRow.implicitWidth + Style.space(12)
              height: Style.space(24)
              radius: Style.space(4)
              color: root.customPlaylistOpen ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2) : Qt.rgba(1, 1, 1, 0.08)
              border.color: root.customPlaylistOpen ? Color.accent : Qt.rgba(1, 1, 1, 0.15)
              border.width: 1

              Row {
                id: playlistBtnRow
                anchors.centerIn: parent
                spacing: Style.space(4)

                Text {
                  text: "󰑐"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                }
                Text {
                  text: root.customPlaylistOpen ? "Tutup URL" : "Ganti Playlist"
                  color: root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.small * 0.9)
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.customPlaylistOpen = !root.customPlaylistOpen
              }
            }
          }

          // Collapsible Custom Playlist URL Drawer
          BorderSurface {
            width: parent.width
            height: customDrawerCol.implicitHeight + Style.space(16)
            visible: root.customPlaylistOpen
            radius: Style.spacing.labelGap

            Column {
              id: customDrawerCol
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: "Ketik utawa tempel URL Playlist YouTube:"
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.small
              }

              Row {
                width: parent.width
                spacing: Style.space(6)

                Rectangle {
                  width: parent.width - Style.space(150)
                  height: Style.space(30)
                  radius: Style.space(4)
                  color: Qt.rgba(0, 0, 0, 0.3)
                  border.color: Qt.rgba(1, 1, 1, 0.15)
                  border.width: 1

                  TextInput {
                    id: customUrlField
                    anchors.fill: parent
                    anchors.margins: Style.space(6)
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.small
                    clip: true
                    selectByMouse: true
                    text: root.customUrlInput
                    onTextChanged: root.customUrlInput = text
                    onAccepted: root.submitCustomPlaylist()

                    Text {
                      visible: !customUrlField.text
                      text: "https://youtube.com/playlist?list=..."
                      color: Qt.rgba(1, 1, 1, 0.3)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.small
                    }
                  }
                }

                // Submit Button
                Rectangle {
                  width: Style.space(68)
                  height: Style.space(30)
                  radius: Style.space(4)
                  color: Color.accent

                  Text {
                    anchors.centerIn: parent
                    text: "Muat"
                    color: Color.background
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.small
                    font.bold: true
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.submitCustomPlaylist()
                  }
                }

                // Reset Button
                Rectangle {
                  width: Style.space(70)
                  height: Style.space(30)
                  radius: Style.space(4)
                  color: Qt.rgba(1, 1, 1, 0.1)
                  border.color: Qt.rgba(1, 1, 1, 0.2)
                  border.width: 1

                  Text {
                    anchors.centerIn: parent
                    text: "Default"
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.small
                  }

                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetToDefaultPlaylist()
                  }
                }
              }

              Text {
                visible: root.statusFeedback !== ""
                text: root.statusFeedback
                color: root.statusFeedback.indexOf("Gagal") !== -1 ? "#f7768e" : "#9ece6a"
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.small
              }
            }
          }

          // Search Filter Input Box
          Rectangle {
            width: parent.width
            height: Style.space(32)
            radius: Style.space(6)
            color: Qt.rgba(0, 0, 0, 0.25)
            border.color: Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.body
              }

              TextInput {
                id: searchInput
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(48)
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.small
                clip: true
                selectByMouse: true
                text: root.searchQuery
                onTextChanged: root.searchQuery = text

                Text {
                  visible: !searchInput.text
                  text: "Golek cerkak (irah-irahan)..."
                  color: Qt.rgba(1, 1, 1, 0.35)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                visible: root.searchQuery !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: "󰅖"
                color: Style.normalBorderFor(root.contentForeground, Color.dim)
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.small

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.searchQuery = ""
                    searchInput.text = ""
                  }
                }
              }
            }
          }
        }

        // ==================== 4. STORIES LISTVIEW ====================
        Item {
          width: parent.width
          height: Style.space(260)
          clip: true

          ListView {
            id: storiesView
            anchors.fill: parent
            model: root.filteredStories
            spacing: Style.space(4)
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
              policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
              required property var modelData
              required property int index

              readonly property bool isCurrentTrack: {
                if (!root.allStories || root.allStories.length === 0) return false
                var cur = root.allStories[root.currentIndex]
                return cur && modelData && cur.id === modelData.id
              }

              width: storiesView.width
              height: Style.space(36)
              radius: Style.space(6)
              color: isCurrentTrack
                ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.2)
                : (itemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
              border.color: isCurrentTrack ? Color.accent : "transparent"
              border.width: isCurrentTrack ? 1 : 0

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(8)

                // Track number or playing icon
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(28)
                  text: isCurrentTrack ? (root.isPlaying && !root.isPaused ? "󰐊" : "󰏤") : ("#" + (index + 1))
                  color: isCurrentTrack ? Color.accent : Style.normalBorderFor(root.contentForeground, Color.dim)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                  font.bold: isCurrentTrack
                  horizontalAlignment: Text.AlignLeft
                }

                // Title
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(90)
                  text: modelData.title || modelData.fullTitle
                  color: isCurrentTrack ? Color.accent : root.contentForeground
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.small
                  font.bold: isCurrentTrack
                  elide: Text.ElideRight
                }

                // Duration
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: modelData.durationFormatted || Model.formatTime(modelData.duration)
                  color: Style.normalBorderFor(root.contentForeground, Color.dim)
                  font.family: root.contentFontFamily
                  font.pixelSize: Math.round(Style.font.small * 0.9)
                  horizontalAlignment: Text.AlignRight
                  width: Style.space(46)
                }
              }

              MouseArea {
                id: itemMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  // Find original index in allStories
                  for (var i = 0; i < root.allStories.length; i++) {
                    if (root.allStories[i].id === modelData.id) {
                      root.playIndex(i)
                      break
                    }
                  }
                }
              }
            }
          }
        }

        // ==================== 5. FOOTER SHORTCUTS ====================
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(12)

          Text {
            text: "Spasi: Play/Pause  ·  n: Sabanjure  ·  p: Sadurunge  ·  m: Pemutar  ·  Esc: Tutup"
            color: Style.normalBorderFor(root.contentForeground, Color.dim)
            font.family: root.contentFontFamily
            font.pixelSize: Math.round(Style.font.small * 0.85)
          }
        }
      }
    }
  }
}
