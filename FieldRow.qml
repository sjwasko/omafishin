import QtQuick
import qs.Commons
import qs.Ui

// A label with a single-line text input on the right. The panel's key
// catcher must be blocked while `editing` is true, or vim-style navigation
// keys (h/j/k/l/x) would steer the panel instead of reaching the input.
Item {
  id: root

  property string icon: ""
  property string label: ""
  property alias text: input.text
  property alias placeholderText: input.placeholderText
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool hasCursor: false
  property real fieldWidth: Style.space(140)
  readonly property bool editing: input.activeFocus

  // Enter pressed in the input.
  signal accepted(string text)
  // Focus left the input (Enter, Escape, Tab or a click elsewhere).
  signal finished(string text)
  // Escape pressed: the panel should take keyboard focus back.
  signal cancelled()

  function edit() {
    input.forceActiveFocus()
    input.selectAll()
  }

  readonly property bool hot: rowHover.hovered || root.hasCursor

  implicitHeight: Style.space(30)
  height: implicitHeight

  HoverHandler { id: rowHover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Style.space(6)
    anchors.rightMargin: -Style.space(6)
    radius: Style.cornerRadius
    color: root.hot && !root.editing
           ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
           : "transparent"
  }

  Text {
    id: iconText
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: root.icon !== "" ? Style.space(22) : 0
    text: root.icon
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    anchors.left: iconText.right
    anchors.right: input.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  TextField {
    id: input
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: root.fieldWidth
    foreground: root.foreground
    accent: root.accent
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    verticalPadding: Style.space(3)
    hasCursor: root.hasCursor
    onAccepted: root.accepted(text)
    onActiveFocusChanged: if (!activeFocus) root.finished(text)
    Keys.onEscapePressed: function(event) {
      event.accepted = true
      root.cancelled()
    }
  }
}
