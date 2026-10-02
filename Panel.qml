import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Omafishin': a fish in the bar that opens the fishin' forecast.
//
// Left-click runs your default view straight away. Right-click opens a small
// panel with two pages: Quick (pick a view, a date or a one-off city) and
// Options (what left-click shows, location, data sources, window behaviour).
//
// Options are stored in this widget's entry in ~/.config/omarchy/shell.json
// via bar.shell.updateEntryInline, the same mechanism the btop plugin uses.
// The location itself stays owned by fishin (~/.config/fishin/config.toml)
// unless "custom" is chosen, so other platforms keep the same default.
Panel {
  id: root

  moduleName: "swasko.omafishin"
  ipcTarget: "swasko.omafishin"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string viewer: Qt.resolvedUrl("omafishin-view").toString().replace("file://", "")

  // --- settings --------------------------------------------------------------

  readonly property var viewOrder: ["today", "days", "best", "month"]
  readonly property int minDays: 1
  // open-meteo forecasts ~16 days and fishin requests N+1, so 16+ days
  // loses weather for the whole view. Keep list/best views within range.
  readonly property int maxDays: 15

  readonly property string defaultView: viewOrder.indexOf(String(setting("defaultView", "today"))) >= 0
                                        ? String(setting("defaultView", "today")) : "today"
  readonly property int days: clampDays(setting("days", 7))
  readonly property string locationSource: String(setting("locationSource", "saved")) === "custom" ? "custom" : "saved"
  readonly property string city: String(setting("city", "")).trim()
  readonly property string displayName: String(setting("displayName", "")).trim()
  readonly property bool tides: setting("tides", true) !== false
  readonly property bool weather: setting("weather", true) !== false
  readonly property string windowMode: String(setting("windowMode", "floating")) === "tiled" ? "tiled" : "floating"
  readonly property bool holdOpen: setting("holdOpen", true) !== false

  readonly property bool usingCustomCity: locationSource === "custom" && city !== ""

  function clampDays(value) {
    var n = parseInt(value)
    if (isNaN(n)) n = 7
    return Math.max(minDays, Math.min(maxDays, n))
  }

  function persist(name, value) {
    var entry = { id: root.moduleName }
    for (var key in root.settings)
      if (key !== "id") entry[key] = root.settings[key]
    entry[name] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function cycle(list, current, direction) {
    var i = list.indexOf(current)
    if (i < 0) i = 0
    return list[(i + direction + list.length) % list.length]
  }

  // fishin's saved location, shown in the tooltip and panel header.
  property string savedLocation: ""

  FileView {
    path: Quickshell.env("HOME") + "/.config/fishin/config.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      var m = /^\s*location\s*=\s*"([^"]*)"/m.exec(text())
      root.savedLocation = m ? m[1] : ""
    }
    onLoadFailed: root.savedLocation = ""
  }

  readonly property string locationLabel: {
    if (usingCustomCity) return displayName !== "" ? displayName : city
    if (displayName !== "") return displayName
    return savedLocation !== "" ? savedLocation : "saved location"
  }

  // --- launching fishin ----------------------------------------------------------

  function viewLabel(view) {
    switch (view) {
    case "days": return "Next " + root.days + " days"
    case "best": return "Best of next " + root.days
    case "month": return "Month"
    default: return "Today"
    }
  }

  function viewArgs(view) {
    switch (view) {
    case "days": return [String(root.days)]
    case "best": return ["best", String(root.days)]
    case "month": return ["month"]
    default: return []
    }
  }

  // Flags shared by every view. A one-off city (from the Quick page) wins
  // over the configured location without changing it.
  function commonArgs(oneOffCity) {
    var args = []
    var place = oneOffCity !== undefined && oneOffCity !== "" ? oneOffCity
              : (root.usingCustomCity ? root.city : "")
    if (place !== "") args.push("--city", place)
    if (root.displayName !== "" && (oneOffCity === undefined || oneOffCity === ""))
      args.push("--location", root.displayName)
    if (!root.tides) args.push("--no-tides")
    if (!root.weather) args.push("--no-weather")
    return args
  }

  // The terminal (e.g. Ghostty's -e) re-joins and re-splits arguments on
  // whitespace, so "key west fl" would arrive as three words. Percent-encode
  // every fishin argument; omafishin-view decodes them again.
  function encodeArg(value) {
    return encodeURIComponent(String(value)).replace(/[!'()*~]/g, function(c) {
      return "%" + c.charCodeAt(0).toString(16).toUpperCase()
    })
  }

  function launch(fishinArgs) {
    var appId = root.windowMode === "tiled" ? "--app-id=org.omarchy.omafishin" : "--app-id=TUI.float"
    var command = ["omarchy-launch-tui", appId, "bash", root.viewer,
                   root.holdOpen ? "--hold" : "--no-hold", "--encoded"].concat(fishinArgs.map(encodeArg))
    Quickshell.execDetached(command)
    root.close()
  }

  function runView(view) { launch(viewArgs(view).concat(commonArgs())) }

  function dateProblem(text) {
    var value = String(text).trim()
    if (value === "") return ""
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return "Use YYYY-MM-DD, e.g. " + todayIso()
    if (!isValidDate(value)) return value + " isn't a real date"
    return ""
  }

  function runDate(text) {
    var value = String(text).trim()
    root.dateError = value === "" ? "Enter a date as YYYY-MM-DD" : dateProblem(value)
    if (root.dateError !== "") return
    launch(["--date", value].concat(commonArgs()))
  }

  function runCity(text) {
    var value = String(text).trim()
    if (value === "") return
    launch(commonArgs(value))
  }

  function todayIso() {
    var d = new Date()
    function pad(n) { return n < 10 ? "0" + n : String(n) }
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
  }

  function isValidDate(value) {
    var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value)
    if (!m) return false
    var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]))
    return d.getFullYear() === Number(m[1]) && d.getMonth() === Number(m[2]) - 1 && d.getDate() === Number(m[3])
  }

  // --- panel state ------------------------------------------------------------

  property string page: "quick"
  property int cursor: -1
  property string dateError: ""

  readonly property var quickRows: ["today", "days", "best", "month", "date", "city", "options"]
  readonly property var optionRows: {
    var rows = ["back", "defaultView", "days", "locationSource"]
    if (root.locationSource === "custom") rows.push("city")
    rows.push("displayName", "tides", "weather", "windowMode", "holdOpen")
    return rows
  }
  readonly property var rows: page === "options" ? optionRows : quickRows
  readonly property string cursorRow: cursor >= 0 && cursor < rows.length ? rows[cursor] : ""
  readonly property bool editing: dateRow.editing || cityOnceRow.editing || cityRow.editing || nameRow.editing

  onOpenedChanged: {
    if (opened) {
      root.page = "quick"
      root.cursor = -1
      root.dateError = ""
      dateRow.text = root.todayIso()
      cityOnceRow.text = ""
    }
  }

  onPageChanged: {
    root.cursor = -1
    keyCatcher.forceActiveFocus()
  }

  function moveCursor(dy) {
    if (root.cursor < 0) root.cursor = dy > 0 ? 0 : rows.length - 1
    else root.cursor = (root.cursor + dy + rows.length) % rows.length
  }

  function stepOption(row, direction) {
    switch (row) {
    case "defaultView": persist("defaultView", cycle(viewOrder, root.defaultView, direction)); break
    case "days": persist("days", clampDays(root.days + direction)); break
    case "locationSource": persist("locationSource", root.locationSource === "saved" ? "custom" : "saved"); break
    case "tides": persist("tides", !root.tides); break
    case "weather": persist("weather", !root.weather); break
    case "windowMode": persist("windowMode", root.windowMode === "floating" ? "tiled" : "floating"); break
    case "holdOpen": persist("holdOpen", !root.holdOpen); break
    }
  }

  function activate(row) {
    switch (row) {
    case "today": case "days": case "best": case "month": runView(row); break
    case "date": dateRow.edit(); break
    case "city": if (root.page === "quick") cityOnceRow.edit(); else cityRow.edit(); break
    case "options": root.page = "options"; break
    case "back": root.page = "quick"; break
    case "displayName": nameRow.edit(); break
    default: stepOption(row, 1)
    }
  }

  function endEditing() { keyCatcher.forceActiveFocus() }

  // --- bar icon ------------------------------------------------------------------

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰈺"
    slotSize: Style.bar.statusSlot
    tooltipText: root.opened ? ""
                 : "Omafishin' · " + root.locationLabel + " · " + root.viewLabel(root.defaultView)
                   + "\nRight-click for more views and options"
    onPressed: function(b) {
      if (b === Qt.RightButton) root.toggle()
      else if (b === Qt.LeftButton) root.runView(root.defaultView)
    }
  }

  // --- panel -----------------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher

    readonly property int desiredWidth: Style.space(320)
    contentWidth: Math.min(desiredWidth, panel.availableCardWidth > 0 ? panel.availableCardWidth : desiredWidth)
    contentHeight: panel.fittedContentHeight(root.page === "options" ? optionsColumn.implicitHeight
                                                                      : quickColumn.implicitHeight,
                                             Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        else if (root.page === "options") root.stepOption(root.cursorRow, dx)
      }
      onActivateRequested: if (root.cursorRow !== "") root.activate(root.cursorRow)
      onCloseRequested: {
        if (root.page === "options") root.page = "quick"
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }

      // --- Quick page ---------------------------------------------------------------

      Column {
        id: quickColumn
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.page === "quick"
        spacing: 0

        Item {
          width: parent.width
          height: Style.space(24)

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Omafishin'"
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width * 0.6)
            horizontalAlignment: Text.AlignRight
            text: root.locationLabel
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        ActionRow {
          width: parent.width
          icon: "󰃭"
          label: "Today"
          hint: "full panel"
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "today"
          onClicked: root.runView("today")
        }
        ActionRow {
          width: parent.width
          icon: "󰸗"
          label: root.viewLabel("days")
          hint: "fishin " + root.days
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "days"
          onClicked: root.runView("days")
        }
        ActionRow {
          width: parent.width
          icon: "󰓎"
          label: root.viewLabel("best")
          hint: "fishin best " + root.days
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "best"
          onClicked: root.runView("best")
        }
        ActionRow {
          width: parent.width
          icon: "󰸘"
          label: "Month"
          hint: "fishin month"
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "month"
          onClicked: root.runView("month")
        }

        FieldRow {
          id: dateRow
          width: parent.width
          icon: "󰃮"
          label: "Pick a date"
          placeholderText: "YYYY-MM-DD"
          fieldWidth: Style.space(110)
          foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "date"
          onAccepted: function(text) { root.runDate(text) }
          onCancelled: root.endEditing()
          // Check as you type, but only once a full-length date is entered,
          // so the error doesn't flash while typing.
          onTextChanged: root.dateError = text.trim().length >= 10 ? root.dateProblem(text) : ""
        }

        Text {
          width: parent.width
          visible: root.dateError !== ""
          leftPadding: Style.space(22)
          bottomPadding: Style.space(4)
          text: root.dateError
          textFormat: Text.PlainText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        FieldRow {
          id: cityOnceRow
          width: parent.width
          icon: "󰍎"
          label: "Other location"
          placeholderText: "city, e.g. key west fl"
          foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "city"
          onAccepted: function(text) { root.runCity(text) }
          onCancelled: root.endEditing()
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        ActionRow {
          width: parent.width
          icon: "󰒓"
          label: "Options…"
          hint: "left-click: " + root.viewLabel(root.defaultView)
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "options"
          onClicked: root.page = "options"
        }
      }

      // --- Options page ----------------------------------------------------------------

      Column {
        id: optionsColumn
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.page === "options"
        spacing: 0

        ActionRow {
          width: parent.width
          icon: "‹"
          label: "Options"
          hint: "changes save automatically"
          foreground: root.foreground; dim: root.dim; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "back"
          onClicked: root.page = "quick"
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        OptionRow {
          width: parent.width
          label: "Default view (left-click)"
          value: root.viewLabel(root.defaultView)
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "defaultView"
          onStep: function(direction) { root.stepOption("defaultView", direction) }
        }
        OptionRow {
          width: parent.width
          label: "Days (list / best)"
          value: String(root.days)
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "days"
          onStep: function(direction) { root.stepOption("days", direction) }
        }
        OptionRow {
          width: parent.width
          label: "Location"
          value: root.locationSource === "custom" ? "Custom city" : "fishin saved"
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "locationSource"
          onStep: function(direction) { root.stepOption("locationSource", direction) }
        }
        FieldRow {
          id: cityRow
          width: parent.width
          visible: root.locationSource === "custom"
          height: visible ? implicitHeight : 0
          label: "Custom city"
          placeholderText: "e.g. key west fl"
          text: root.city
          foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "city"
          onAccepted: root.endEditing()
          onFinished: function(text) { if (text.trim() !== root.city) root.persist("city", text.trim()) }
          onCancelled: { text = root.city; root.endEditing() }
        }
        FieldRow {
          id: nameRow
          width: parent.width
          label: "Display name"
          placeholderText: "optional"
          text: root.displayName
          foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "displayName"
          onAccepted: root.endEditing()
          onFinished: function(text) { if (text.trim() !== root.displayName) root.persist("displayName", text.trim()) }
          onCancelled: { text = root.displayName; root.endEditing() }
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        OptionRow {
          width: parent.width
          label: "Include tides"
          isToggle: true
          checked: root.tides
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "tides"
          onStep: root.stepOption("tides", 1)
        }
        OptionRow {
          width: parent.width
          label: "Include weather"
          isToggle: true
          checked: root.weather
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "weather"
          onStep: root.stepOption("weather", 1)
        }

        PanelSeparator { width: parent.width; foreground: root.foreground }

        OptionRow {
          width: parent.width
          label: "Window mode"
          value: root.windowMode === "tiled" ? "Tiled" : "Floating"
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "windowMode"
          onStep: function(direction) { root.stepOption("windowMode", direction) }
        }
        OptionRow {
          width: parent.width
          label: "Keep open until keypress"
          isToggle: true
          checked: root.holdOpen
          foreground: root.foreground; dim: root.dim; accent: root.accent; fontFamily: root.fontFamily
          hasCursor: root.cursorRow === "holdOpen"
          onStep: root.stepOption("holdOpen", 1)
        }
      }
    }
  }
}
