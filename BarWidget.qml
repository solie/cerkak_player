import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// BarWidget for Cerkak Player (Javanese Short Stories & YouTube Audio)
//
// Left-click: Open / toggle player & story list panel
// Middle-click: Toggle play / pause
// Right-click: Next story
// Wheel: Adjust volume
BarWidget {
  id: root
  moduleName: "cerkak_player"

  readonly property string playerScript: Qt.resolvedUrl("cerkak-player").toString().replace(/^file:\/\//, "")
  readonly property string statusPath: Quickshell.env("XDG_RUNTIME_DIR") + "/cerkak_player/status.json"

  property var playerState: null
  readonly property bool playerRunning: playerState && playerState.running === true
  readonly property bool isPlaying: playerState && playerState.playing === true
  readonly property bool isPaused: playerState && playerState.paused === true
  readonly property string storyTitle: playerState && playerState.title ? String(playerState.title).trim() : ""
  readonly property int playerVolume: playerState && playerState.volume !== undefined ? playerState.volume : 75
  readonly property bool shuffleEnabled: playerState && playerState.shuffle === true

  function applyStatus(raw) {
    if (!raw) return
    var data = raw
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
      root.playerState = data
      if (panelLoader.item && ("applyStatus" in panelLoader.item)) {
        panelLoader.item.applyStatus(data)
      } else if (panelLoader.item && ("playerState" in panelLoader.item)) {
        panelLoader.item.playerState = data
      }
    }
  }

  function runAction(action, arg) {
    var cmd = [playerScript, action]
    if (arg !== undefined && arg !== null) {
      cmd.push(String(arg))
    }
    actionProc.command = cmd
    actionProc.running = true
  }

  function changeVolume(delta) {
    var step = delta > 0 ? 5 : -5
    var target = Math.max(0, Math.min(100, playerVolume + step))
    runAction("volume", target)
  }

  // ---- Popup / panel shape contract for Omarchy bar
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    initProc.command = [playerScript, "status"]
    initProc.running = true
    if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  function togglePanel() {
    initProc.command = [playerScript, "status"]
    initProc.running = true
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("playerScript" in target) target.playerScript = root.playerScript
    if ("playerState" in target && root.playerState) target.playerState = root.playerState
  }

  readonly property string displayText: {
    if (vertical) return isPlaying ? (isPaused ? "󰏤" : "󰐊") : "󰗃"
    if (!isPlaying) return "󰗃 Cerkak"
    var icon = isPaused ? "󰏤" : "󰐊"
    var title = storyTitle ? storyTitle : "Cerkak"
    if (title.length > 20) {
      title = title.substring(0, 19) + "…"
    }
    return icon + " " + title
  }

  readonly property var verticalLines: vertical
    ? [isPlaying ? (isPaused ? "󰏤" : "󰐊") : "󰗃", "CRK"]
    : [displayText]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Component.onCompleted: {
    // Initial status fetch
    initProc.command = [playerScript, "status"]
    initProc.running = true
  }

  FileView {
    path: root.statusPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyStatus(text())
    onFileChanged: {
      reload()
      root.applyStatus(text())
    }
  }

  Process {
    id: initProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw) {
          try {
            var data = JSON.parse(raw)
            if (data.status) root.applyStatus(JSON.stringify(data.status))
            else root.applyStatus(raw)
          } catch (e) {}
        }
      }
    }
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw) root.applyStatus(raw)
      }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "cerkak_player"

    function play(): void { root.runAction("play") }
    function pause(): void { root.runAction("pause") }
    function toggle(): void { root.runAction("play-pause") }
    function next(): void { root.runAction("next") }
    function prev(): void { root.runAction("prev") }
    function stop(): void { root.runAction("stop") }
    function shuffle(): void { root.runAction("shuffle") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function status(): string { return JSON.stringify(root.playerState || {}) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "" : root.displayText
    labelVisible: !root.vertical
    hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
    fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    verticalPadding: 8.75
    active: root.isPlaying && !root.isPaused

    tooltipText: root.isPlaying
      ? ("Cerkak Player\n"
         + (root.isPaused ? "Ngaso (Paused): " : "Memutar (Playing): ") + root.storyTitle + "\n"
         + "Durasi: " + (root.playerState ? (root.playerState.positionFormatted + " / " + root.playerState.durationFormatted) : "") + " · Volume " + root.playerVolume + "%\n"
         + "Klik ki: Buka Pemutar | Tengah: Play/Pause | Kanan: Sabanjure | Scroll: Volume")
      : ("Cerkak Player\nCerita Cekak Basa Jawa\nKlik ki: Buka Pemutar | Tengah: Putar")

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) {
        root.runAction("next")
      } else if (mouseButton === Qt.MiddleButton) {
        root.runAction("play-pause")
      } else {
        root.togglePanel()
      }
    }

    onWheelMoved: function(delta) {
      root.changeVolume(delta)
    }

    Column {
      visible: root.vertical
      anchors.fill: parent

      Repeater {
        model: root.verticalLines

        OpticalGlyph {
          required property string modelData
          width: button.width
          height: Style.bar.iconSlot
          text: modelData
          fontFamily: button.fontFamily
          fontSize: button.fontSize * 0.9
          color: button.foreground
        }
      }
    }
  }
}

