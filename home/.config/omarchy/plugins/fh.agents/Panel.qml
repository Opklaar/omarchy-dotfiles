import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// DeepSeek quick access: type a question in the bar dropdown, get a one-shot
// flash-vision answer shown inline. The "Open app" button launches full
// OpenCode (with its own model) for anything bigger.
Panel {
  id: root
  moduleName: "omarchy.agents"
  ipcTarget: "omarchy.agents"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string model: setting("model", "deepseek/deepseek-v4-flash-vision-exp")

  property string answer: ""
  property bool busy: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function launch() {
    if (root.bar) root.bar.run("omarchy-agent")
    root.close()
  }

  function cleanAnswer(raw) {
    var text = String(raw || "")
    text = text.replace(/\u001b\[[0-9;]*[A-Za-z]/g, "")
    text = text.replace(/^> .*$/gm, "")
    text = text.replace(/^\s+|\s+$/g, "")
    return text
  }

  function ask() {
    var prompt = String(promptField.text || "").trim()
    if (prompt === "" || root.busy) return
    root.answer = ""
    root.busy = true
    promptField.enabled = false
    var full = "Reply with only the direct answer, no preamble, no I'll statements, no explanation.\n\nQuestion: " + prompt
    askProcess.command = ["bash", "-c", "opencode run -m \"$1\" \"$2\" </dev/null", "opencode", root.model, full]
    askProcess.running = true
  }

  function onAnswer(raw) {
    var text = cleanAnswer(raw)
    root.answer = text !== "" ? text : "(no response)"
    root.busy = false
    promptField.enabled = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱚣"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) root.launch()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: promptField
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: promptField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        Text {
          width: parent.width
          text: "DeepSeek"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.model
          color: Qt.darker(root.foreground, 1.5)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Flickable {
          width: parent.width
          height: Math.min(answerText.implicitHeight, Style.space(300))
          contentHeight: answerText.implicitHeight
          clip: true
          interactive: contentHeight > height
          visible: root.busy || root.answer !== ""

          Text {
            id: answerText
            width: parent.width
            text: root.busy ? "Thinking…" : root.answer
            color: root.busy ? Qt.darker(root.foreground, 1.5) : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }

        TextField {
          id: promptField
          width: parent.width
          placeholderText: "Ask DeepSeek…"
          foreground: root.foreground
          font.family: root.fontFamily
          onAccepted: root.ask()
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.close()
              event.accepted = true
            }
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: "Ask"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.ask()
          }

          Button {
            text: "Open app"
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.launch()
          }
        }
      }
    }
  }

  Process {
    id: askProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onAnswer(text)
    }
  }
}
