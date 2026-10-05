// tmux sessions — Omarchy shell plugin (kind: "menu").
//
// A layer-shell overlay listing the live tmux sessions. Enter resumes the
// selected one through bin/tmux-sessions (focusing the terminal where it is
// already attached, or opening a new one); Ctrl+K kills it.
//
// Lifecycle: the host calls open(payloadJson) after
//   omarchy-shell shell summon io.github.cache21.tmux-sessions '{}'
// and close() on hide. `opened` is read by the host to implement `toggle`.
//
// Shortcuts: ↑/↓ move · Enter resume · Ctrl+K kill · Ctrl+P preview · Esc

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  // ---- injected by omarchy-shell ----
  property var shell: null
  property var manifest: null

  // ---- state ----
  property bool opened: false
  property string filter: ""
  property int selIndex: 0
  property var sessions: []
  property bool loadedOnce: false

  // Preview
  property bool previewOn: true
  property string currentPreview: ""
  property string previewFor: ""

  // transient status line
  property string note: ""

  readonly property string home: Quickshell.env("HOME")
  // Absolute path to the bundled backend script, resolved next to this file.
  readonly property string scriptPath: {
    var u = Qt.resolvedUrl("bin/tmux-sessions").toString()
    return u.replace(/^file:\/\//, "")
  }
  readonly property int rowH: Math.max(Style.space(48), Style.font.body + Style.font.caption + Style.space(18))
  readonly property int headerH: Math.max(Style.space(34), Style.font.subtitle + Style.space(18))
  readonly property int pad: Style.spacing.panelPadding
  readonly property int maxRows: 9
  readonly property int leftW: Math.min(Style.space(480), win.width - Style.space(80))
  readonly property int previewW: Style.space(520)
  readonly property bool previewShown: previewOn && win.width > (leftW + previewW + Style.space(120))

  // ---- lifecycle hooks (called by the host) ----
  function open(payloadJson) {
    root.filter = ""
    root.selIndex = 0
    root.note = ""
    root.currentPreview = ""
    root.previewFor = ""
    root.loadedOnce = false
    rowsModel.clear()
    searchInput.text = ""
    root.opened = true
    listProc.running = true
    Qt.callLater(function () { searchInput.forceActiveFocus() })
  }
  function close() { root.opened = false }
  function refresh() { if (root.opened) listProc.running = true; return "ok" }
  function ping() { return "ok" }

  // ---- data plumbing ----
  function applyList(text) {
    root.sessions = Model.parseSessions(text)
    root.loadedOnce = true
    rebuild()
  }

  // keepSel (default true): keep the highlight on the same session across
  // refreshes. Passed false while typing, where it snaps back to the top.
  function rebuild(keepSel) {
    var keep = (keepSel === false) ? "" : (root.currentRow() ? root.currentRow().name : "")
    var sorted = Model.sortSessions(root.sessions, root.filter)
    var nowSec = Math.floor(Date.now() / 1000)
    rowsModel.clear()
    for (var i = 0; i < sorted.length; i++) {
      var s = sorted[i]
      rowsModel.append({
        name: s.name,
        detail: Model.detailLine(s, root.home, nowSec),
        attached: s.clients > 0
      })
    }
    var restored = -1
    if (keep) {
      for (var j = 0; j < rowsModel.count; j++) {
        if (rowsModel.get(j).name === keep) { restored = j; break }
      }
    }
    if (restored >= 0) root.selIndex = restored
    else if (root.selIndex >= rowsModel.count) root.selIndex = Math.max(0, rowsModel.count - 1)
    listView.positionViewAtIndex(root.selIndex, ListView.Contain)
    root.schedulePreview()
  }

  function move(d) {
    if (rowsModel.count === 0) return
    root.selIndex = Math.max(0, Math.min(rowsModel.count - 1, root.selIndex + d))
    listView.positionViewAtIndex(root.selIndex, ListView.Contain)
    root.schedulePreview()
  }

  function currentRow() {
    return (root.selIndex >= 0 && root.selIndex < rowsModel.count) ? rowsModel.get(root.selIndex) : null
  }

  function activate(i) {
    var row = (i >= 0 && i < rowsModel.count) ? rowsModel.get(i) : null
    if (!row) return
    Quickshell.execDetached([root.scriptPath, "attach", row.name])
    root.close()
  }

  function killSelected() {
    var row = root.currentRow()
    if (!row) return
    // Snapshot before rebuild(): rowsModel.get() returns a live reference.
    var name = row.name
    // Optimistically drop the row; listProc in killProc.onExited confirms.
    root.sessions = root.sessions.filter(function (s) { return s.name !== name })
    root.rebuild()
    killProc.command = [root.scriptPath, "kill", name]
    killProc.running = true
    root.showNote("Sesión terminada: " + name)
  }

  function showNote(t) { root.note = t; noteTimer.restart() }

  function schedulePreview() { previewTimer.restart() }

  function loadPreview() {
    if (!root.previewShown) return
    var row = root.currentRow()
    if (!row) { root.currentPreview = ""; root.previewFor = ""; return }
    if (previewProc.running) { previewTimer.restart(); return }
    if (row.name !== root.previewFor) root.currentPreview = ""
    previewProc.target = row.name
    previewProc.command = [root.scriptPath, "preview", row.name]
    previewProc.running = true
  }

  // ---- processes ----
  Process {
    id: listProc
    command: [root.scriptPath, "list"]
    stdout: StdioCollector { id: listOut }
    onExited: function (code) { root.applyList(listOut.text) }
  }

  Process {
    id: killProc
    stdout: StdioCollector {}
    stderr: StdioCollector { id: killErr }
    onExited: function (code) {
      if (code !== 0) root.showNote(killErr.text.trim() || "No se pudo matar la sesión")
      listProc.running = true
    }
  }

  Process {
    id: previewProc
    property string target: ""
    stdout: StdioCollector { id: previewOut }
    onExited: function (code) {
      var row = root.currentRow()
      if (row && row.name === previewProc.target) {
        root.currentPreview = previewOut.text
        root.previewFor = previewProc.target
      }
    }
  }

  Timer { id: previewTimer; interval: 150; onTriggered: root.loadPreview() }
  Timer { id: noteTimer; interval: 2200; onTriggered: root.note = "" }
  // Keep the list (attached state, activity) and the preview fresh while open.
  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onTriggered: { if (!listProc.running) listProc.running = true }
  }

  ListModel { id: rowsModel }

  IpcHandler {
    target: "io.github.cache21.tmux-sessions"
    function toggle(): string { if (root.opened) root.close(); else root.open("{}"); return "ok" }
    function summon(): string { root.open("{}"); return "ok" }
    function dismiss(): string { root.close(); return "ok" }
    function reload(): string { root.refresh(); return "ok" }
  }

  // ---- overlay UI ----
  PanelWindow {
    id: win
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-tmux-sessions"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
      id: card
      width: root.pad * 2 + root.leftW + (root.previewShown ? root.pad + 1 + root.previewW : 0)
      height: Math.min(
                root.pad * 2 + root.headerH + Style.space(6)
                  + Math.max(1, Math.min(rowsModel.count, root.maxRows)) * (root.rowH + listView.spacing)
                  + Style.space(30),
                win.height * 0.74)
      anchors.centerIn: parent
      color: Color.menu.background
      border.color: Color.menu.border
      border.width: Math.max(1, Style.normalBorderWidth)
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Row {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.pad

        // ---- left: search + list ----
        Item {
          id: leftCol
          width: root.leftW
          height: parent.height

          Column {
            anchors.fill: parent
            spacing: Style.space(6)

            // search field + session count
            Rectangle {
              width: parent.width
              height: root.headerH
              color: "transparent"

              Text {
                id: countTag
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.sessions.length + (root.sessions.length === 1 ? " sesión" : " sesiones")
                color: Color.menu.text
                opacity: 0.55
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                visible: searchInput.text.length === 0
                text: "Buscar sesión tmux…"
                color: Color.menu.text
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
              }

              TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: countTag.left
                anchors.rightMargin: Style.space(10)
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Color.menu.text
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                selectByMouse: true
                selectionColor: Color.menu.selectedBackground
                focus: true
                Keys.priority: Keys.BeforeItem
                onTextChanged: { root.filter = text; root.selIndex = 0; root.rebuild(false) }
                Keys.onPressed: function (e) {
                  var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
                  if (e.key === Qt.Key_Escape) {
                    if (searchInput.text.length) searchInput.text = ""
                    else root.close()
                    e.accepted = true
                  } else if (ctrl && e.key === Qt.Key_P) {
                    root.previewOn = !root.previewOn; if (root.previewOn) root.schedulePreview(); e.accepted = true
                  } else if (ctrl && e.key === Qt.Key_K) {
                    root.killSelected(); e.accepted = true
                  } else if (e.key === Qt.Key_Down || (ctrl && e.key === Qt.Key_J)) { root.move(1); e.accepted = true }
                  else if (e.key === Qt.Key_Up) { root.move(-1); e.accepted = true }
                  else if (e.key === Qt.Key_PageDown) { root.move(6); e.accepted = true }
                  else if (e.key === Qt.Key_PageUp) { root.move(-6); e.accepted = true }
                  else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    root.activate(root.selIndex); e.accepted = true
                  }
                }
              }
            }

            Rectangle { width: parent.width; height: Style.spacing.hairline; color: Color.menu.text; opacity: 0.15 }

            // results
            Item {
              width: parent.width
              height: parent.height - root.headerH - Style.space(6) - Style.spacing.hairline
                      - Style.space(18) - parent.spacing * 3

              Text {
                anchors.centerIn: parent
                visible: rowsModel.count === 0
                text: !root.loadedOnce ? "Buscando…"
                      : (root.sessions.length === 0 ? "No hay sesiones tmux activas" : "Ninguna sesión coincide")
                color: Color.menu.text
                opacity: 0.5
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }

              ListView {
                id: listView
                anchors.fill: parent
                model: rowsModel
                clip: true
                spacing: Style.space(2)
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: root.selIndex
                highlightMoveDuration: 0

                delegate: Item {
                  id: rowItem
                  required property int index
                  required property string name
                  required property string detail
                  required property bool attached

                  width: ListView.view.width
                  height: root.rowH

                  readonly property bool selected: rowItem.index === root.selIndex
                  readonly property color fg: rowItem.selected ? Color.menu.selectedText : Color.menu.text

                  Rectangle {
                    anchors.fill: parent
                    anchors.margins: Style.space(1)
                    radius: Style.cornerRadius
                    color: rowItem.selected ? Color.menu.selectedBackground : "transparent"
                  }

                  Text {
                    id: glyphText
                    anchors.left: parent.left
                    anchors.leftMargin: Style.space(12)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Style.space(22)
                    horizontalAlignment: Text.AlignHCenter
                    text: ""  // nf-cod-terminal_tmux
                    color: rowItem.fg
                    font.family: Style.font.family
                    font.pixelSize: Style.font.iconLarge
                  }

                  Column {
                    anchors.left: glyphText.right
                    anchors.leftMargin: Style.space(10)
                    anchors.right: stateText.left
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)

                    Text {
                      width: parent.width
                      text: rowItem.name
                      color: rowItem.fg
                      font.family: Style.font.family
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: rowItem.detail
                      color: rowItem.fg
                      opacity: 0.55
                      font.family: Style.font.family
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }

                  Text {
                    id: stateText
                    anchors.right: parent.right
                    anchors.rightMargin: Style.space(14)
                    anchors.verticalCenter: parent.verticalCenter
                    text: rowItem.attached ? "● abierta" : ""
                    color: Color.menu.selectedText
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onPositionChanged: { if (root.selIndex !== rowItem.index) { root.selIndex = rowItem.index; root.schedulePreview() } }
                    onClicked: function (m) {
                      if (m.button === Qt.MiddleButton) { root.selIndex = rowItem.index; root.killSelected() }
                      else root.activate(rowItem.index)
                    }
                  }
                }
              }
            }

            // status line: transient note, or the shortcut hints
            Text {
              width: parent.width
              height: Style.space(18)
              text: root.note.length ? root.note : "Enter reanudar · Ctrl+K matar · Ctrl+P preview · Esc cerrar"
              color: root.note.length ? Color.menu.selectedText : Color.menu.text
              opacity: root.note.length ? 1 : 0.45
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        // ---- divider ----
        Rectangle {
          visible: root.previewShown
          width: 1
          height: parent.height
          color: Color.menu.text
          opacity: 0.15
        }

        // ---- right: window list on top, tail of the active pane below ----
        Item {
          visible: root.previewShown
          width: root.previewW
          height: parent.height
          clip: true

          readonly property int split: root.currentPreview.indexOf("\n\n")
          readonly property string head: split >= 0 ? root.currentPreview.slice(0, split) : root.currentPreview
          readonly property string body: split >= 0 ? root.currentPreview.slice(split + 2) : ""

          Text {
            id: previewHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            text: parent.head.length ? parent.head : (rowsModel.count ? "…" : "")
            color: Color.menu.text
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            textFormat: Text.PlainText
          }

          Rectangle {
            id: previewRule
            anchors.top: previewHead.bottom
            anchors.topMargin: Style.space(6)
            width: parent.width
            height: Style.spacing.hairline
            color: Color.menu.text
            opacity: 0.15
            visible: parent.body.length > 0
          }

          // Bottom-anchored so the newest output (the prompt) stays visible.
          Item {
            anchors.top: previewRule.bottom
            anchors.topMargin: Style.space(6)
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true

            Text {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              text: parent.parent.body
              color: Color.menu.text
              opacity: 0.7
              wrapMode: Text.NoWrap
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
              textFormat: Text.PlainText
            }
          }
        }
      }
    }
  }
}
