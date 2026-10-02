import QtQuick
import qs.Commons

// One setting on the Options page: label on the left, the current value on
// the right as "‹ value ›". Clicking the arrows (or Left/Right on the
// keyboard, handled by the panel) steps through the choices; clicking the
// value steps forward. Boolean settings show [✓] / [ ] instead.
Item {
  id: root

  property string label: ""
  property string value: ""
  property bool isToggle: false
  property bool checked: false
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool hasCursor: false

  // +1 or -1
  signal step(int direction)

  readonly property bool hot: rowHover.hovered || root.hasCursor

  implicitHeight: Style.space(26)
  height: implicitHeight

  HoverHandler { id: rowHover }

  Rectangle {
    anchors.fill: parent
    anchors.leftMargin: -Style.space(6)
    anchors.rightMargin: -Style.space(6)
    radius: Style.cornerRadius
    color: root.hot
           ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
           : "transparent"
  }

  Text {
    anchors.left: parent.left
    anchors.right: valueRow.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Row {
    id: valueRow
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(6)

    Text {
      visible: !root.isToggle
      text: "‹"
      color: root.hot ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step(-1)
      }
    }

    Text {
      text: root.isToggle ? (root.checked ? "[✓]" : "[ ]") : root.value
      textFormat: Text.PlainText
      color: root.isToggle && root.checked ? root.accent : root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step(1)
      }
    }

    Text {
      visible: !root.isToggle
      text: "›"
      color: root.hot ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      MouseArea {
        anchors.fill: parent
        anchors.margins: -Style.space(4)
        cursorShape: Qt.PointingHandCursor
        onClicked: root.step(1)
      }
    }
  }
}
