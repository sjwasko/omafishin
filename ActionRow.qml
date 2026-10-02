import QtQuick
import qs.Commons

// One clickable row in the Quick page: an icon and label on the left, a dim
// hint (the fishin command it runs) on the right. Same height and hover
// treatment as the Options rows so both pages share one rhythm.
Item {
  id: root

  property string icon: ""
  property string label: ""
  property string hint: ""
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property string fontFamily: Style.font.family
  property bool hasCursor: false

  signal clicked()

  readonly property bool hot: mouse.containsMouse || root.hasCursor

  implicitHeight: Style.space(26)
  height: implicitHeight

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
    anchors.right: hintText.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    text: root.label
    textFormat: Text.PlainText
    elide: Text.ElideRight
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
  }

  Text {
    id: hintText
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    text: root.hint
    textFormat: Text.PlainText
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
