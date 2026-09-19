import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "jacob.omaspeak"
  ipcTarget: "omaspeak"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool binaryFound: false
  property bool checking: false
  property bool unitInstalled: false
  property var statusData: null
  property var voices: []
  property string sayText: ""
  property bool actionBusy: false
  property string actionError: ""
  property bool voiceMenuOpen: false
  property string configuredVoice: ""

  readonly property bool daemonRunning: Model.isDaemonRunning(statusData)
  readonly property string modelName: Model.modelName(statusData)
  readonly property string backendName: Model.backendName(statusData)

  readonly property string effectiveVoiceLabel: {
    if (root.configuredVoice === "" || root.configuredVoice === "0") return "Default"
    for (var i = 0; i < voices.length; i++) {
      if (String(voices[i].id) === root.configuredVoice) return voices[i].name
      if (voices[i].name === root.configuredVoice) return voices[i].name
    }
    return root.configuredVoice
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      refreshTimer.start()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      refreshTimer.stop()
      voiceMenuOpen = false
      sayText = ""
      actionError = ""
    }
  }

  Component.onCompleted: checkBinary()

  function checkBinary() {
    checking = true
    binaryCheck.running = true
  }

  function checkUnit() {
    if (!binaryFound) return
    unitCheck.running = true
  }

  function refreshStatus() {
    if (!binaryFound) return
    statusProc.running = true
  }

  function refreshVoices() {
    if (!binaryFound) return
    voicesProc.running = true
  }

  function refreshConfigVoice() {
    if (!binaryFound) return
    configVoiceProc.running = true
  }

  function doAction(args) {
    actionBusy = true
    actionError = ""
    actionProc.command = ["omaspeak"].concat(args)
    actionProc.running = true
  }

  function doSystemctl(args) {
    actionBusy = true
    actionError = ""
    systemctlProc.command = ["systemctl", "--user"].concat(args)
    systemctlProc.running = true
  }

  function launchTerminal(args) {
    launchProc.command = ["omarchy", "launch", "terminal"].concat(args)
    launchProc.running = true
    root.close()
  }

  function say(text) {
    if (!text || !text.trim()) return
    actionBusy = true
    actionError = ""
    sayText = ""
    sayProc.command = ["omaspeak", "say", text.trim()]
    sayProc.running = true
  }

  function setVoice(voiceName) {
    actionBusy = true
    actionError = ""
    voiceMenuOpen = false
    voiceProc.command = ["omaspeak", "config", "set", "model.voice", voiceName]
    voiceProc.running = true
  }

  function unsetVoice() {
    actionBusy = true
    actionError = ""
    voiceMenuOpen = false
    voiceProc.command = ["omaspeak", "config", "unset", "model.voice"]
    voiceProc.running = true
  }

  function refreshAfterDelay(ms) {
    delayTimer.interval = ms || 800
    delayTimer.start()
  }

  Process {
    id: binaryCheck
    command: ["sh", "-c", "command -v omaspeak"]
    running: false
    onExited: function(code) {
      binaryFound = (code === 0)
      checking = false
      if (binaryFound) {
        checkUnit()
        refreshStatus()
        refreshVoices()
        refreshConfigVoice()
      }
    }
  }

  Process {
    id: unitCheck
    command: ["systemctl", "--user", "show", "omaspeak", "--property=LoadState", "--value"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        unitInstalled = Model.parseUnitLoadState(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) unitInstalled = false
    }
  }

  Process {
    id: statusProc
    command: ["omaspeak", "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        statusData = Model.parseStatus(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) statusData = null
    }
  }

  Process {
    id: voicesProc
    command: ["omaspeak", "voices", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        voices = Model.parseVoices(text)
      }
    }
    onExited: function(code) {
      if (code !== 0) voices = []
    }
  }

  Process {
    id: configVoiceProc
    command: ["omaspeak", "config", "get", "model.voice"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "" || raw === "null" || raw === "undefined") {
          root.configuredVoice = ""
        } else {
          root.configuredVoice = raw
        }
      }
    }
    onExited: function(code) {
      if (code !== 0) root.configuredVoice = ""
    }
  }

  Process {
    id: actionProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      refreshStatus()
    }
  }

  Process {
    id: systemctlProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      checkUnit()
      refreshAfterDelay(800)
    }
  }

  Process {
    id: sayProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      if (code !== 0) actionError = "Could not speak text"
    }
  }

  Process {
    id: voiceProc
    command: []
    running: false
    onExited: function(code) {
      actionBusy = false
      if (code !== 0) actionError = "Could not change voice"
      refreshAfterDelay(300)
      refreshConfigVoice()
    }
  }

  Process {
    id: launchProc
    command: []
    running: false
  }

  // Background refresh: keeps the bar icon accurate even when panel is closed
  Timer {
    id: bgRefreshTimer
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      if (!checking) checkBinary()
    }
  }

  Timer {
    id: refreshTimer
    interval: 5000
    repeat: true
    onTriggered: {
      if (binaryFound) {
        refreshStatus()
        refreshVoices()
        refreshConfigVoice()
      }
    }
  }

  Timer {
    id: delayTimer
    interval: 800
    repeat: false
    onTriggered: {
      refreshStatus()
      refreshVoices()
      refreshConfigVoice()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf075"
    active: daemonRunning
    tooltipText: "Omaspeak" + (daemonRunning ? " · running" : " · stopped")
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        if (daemonRunning) doSystemctl(["stop", "omaspeak"])
        else root.toggle()
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentColumn.implicitHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: panelFlick.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: "Omaspeak"
            meta: checking
              ? "Checking…"
              : (binaryFound
                ? (daemonRunning ? "Running" : "Stopped")
                : "Not installed")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "\uf075"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          BorderSurface {
            visible: !binaryFound && !checking
            width: parent.width
            implicitHeight: installColumn.implicitHeight + Style.space(20)
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.08)
            borderSpec: Border.flat(Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.3), 1)
            radius: Style.cornerRadius

            Column {
              id: installColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              Text {
                width: parent.width
                text: "Omaspeak is not installed."
                textFormat: Text.PlainText
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Text.WordWrap
              }
              Text {
                width: parent.width
                text: "Install it with:  pacman -S omaspeak-bin"
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
              }
            }
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "STATUS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              width: parent.width
              spacing: Style.space(4)

              Text {
                width: parent.width
                text: "Daemon: " + (daemonRunning ? "Running" : "Stopped")
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              Text {
                visible: modelName !== ""
                width: parent.width
                text: "Model: " + modelName
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Text {
                visible: backendName !== ""
                width: parent.width
                text: "Backend: " + backendName
                textFormat: Text.PlainText
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
          }

          Row {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(6)

            Button {
              visible: !unitInstalled
              text: "Install daemon"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: launchTerminal(["omaspeak", "setup", "systemd"])
            }
            Button {
              visible: unitInstalled && !daemonRunning
              text: "Start"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doSystemctl(["start", "omaspeak"])
            }
            Button {
              visible: daemonRunning && unitInstalled
              text: "Stop"
              enabled: !actionBusy
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: doSystemctl(["stop", "omaspeak"])
            }
          }

          PanelSeparator {
            visible: binaryFound
            foreground: root.foreground
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "SPEAK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: sayField
                Layout.fillWidth: true
                foreground: root.foreground
                placeholderText: "Type text to speak"
                text: root.sayText
                onTextChanged: root.sayText = text
                Keys.onReturnPressed: root.say(root.sayText)
                Keys.onEnterPressed: root.say(root.sayText)
              }

              Button {
                text: "Say"
                enabled: !actionBusy && root.sayText.trim() !== ""
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.say(root.sayText)
              }
            }

            Text {
              visible: actionError !== ""
              width: parent.width
              text: actionError
              textFormat: Text.PlainText
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          PanelSeparator {
            visible: binaryFound && voices.length > 0
            foreground: root.foreground
          }

          Column {
            visible: binaryFound && voices.length > 0
            width: parent.width
            spacing: Style.space(10)

            PanelSectionHeader {
              text: "VOICE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            CursorSurface {
              width: parent.width
              foreground: root.foreground
              implicitHeight: voiceHeaderRow.implicitHeight + Style.space(14)

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.voiceMenuOpen = !root.voiceMenuOpen
              }

              RowLayout {
                id: voiceHeaderRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(8)

                Text {
                  text: root.effectiveVoiceLabel
                  textFormat: Text.PlainText
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  Layout.fillWidth: true
                  elide: Text.ElideRight
                }
                Text {
                  text: root.voiceMenuOpen ? "\uf077" : "\uf078"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.icon
                }
              }
            }

            BorderSurface {
              visible: root.voiceMenuOpen
              width: parent.width
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
              borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12), 1)
              radius: Style.cornerRadius
              implicitHeight: voiceListColumn.implicitHeight + Style.space(8)

              Column {
                id: voiceListColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(4)
                spacing: Style.space(1)

                VoiceRow {
                  label: "Default"
                  selected: root.configuredVoice === "" || root.configuredVoice === "0"
                  onClicked: root.unsetVoice()
                }

                Repeater {
                  model: voices
                  delegate: VoiceRow {
                    required property var modelData
                    label: modelData.name
                    selected: {
                      if (root.configuredVoice === "" || root.configuredVoice === "0") return false
                      return String(modelData.id) === root.configuredVoice || modelData.name === root.configuredVoice
                    }
                    onClicked: root.setVoice(modelData.name)
                  }
                }
              }
            }
          }

          PanelSeparator {
            visible: binaryFound
            foreground: root.foreground
          }

          Column {
            visible: binaryFound
            width: parent.width
            spacing: Style.space(6)

            Button {
              width: parent.width
              text: "Open setup"
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onClicked: launchTerminal(["omaspeak", "setup"])
            }
          }
        }
      }
    }
  }

  component VoiceRow: CursorSurface {
    property string label: ""
    property bool selected: false
    signal clicked()

    width: parent.width
    foreground: root.foreground
    implicitHeight: row.implicitHeight + Style.space(12)

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }

    RowLayout {
      id: row
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: parent.parent.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.fillWidth: true
        elide: Text.ElideRight
      }
      Text {
        text: parent.parent.selected ? "\uf00c" : ""
        color: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }
    }
  }
}
