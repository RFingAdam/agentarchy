// Agentarchy SDDM greeter.
//
// Native, not vendored (upstream/VENDOR-MANIFEST). Upstream's version drew the lock, the entry field
// and the password dots as five PNGs in a single hard-coded colour, which meant the greeter could
// only ever look like one theme -- and on the five light themes it would have been light on light.
// Everything here is drawn from the palette instead, so there are no image assets to keep in step
// with 22 themes (the logo is Agentarchy's own, supplied in Phase 1).
//
// Colours arrive through theme.conf, rendered per theme by bin/oal-theme-render from
// default/themed/sddm.theme.conf.tpl. Every read falls back to a literal: a greeter is the one
// screen that must render even when its configuration is missing, because the alternative is a
// machine nobody can log into. The theme.conf that ships in this directory is the empty upstream
// one, so those fallbacks are the live path until bin/oal-refresh-sddm renders a real palette in.

import QtQuick 2.0
import SddmComponents 2.0

Rectangle {
  id: root
  width: 640
  height: 480
  color: config.background || "#1a1b26"

  readonly property color fieldColor: config.lighter_background || "#24283b"
  readonly property color textColor: config.foreground || "#a9b1d6"
  readonly property color idleBorder: config.muted || "#414868"
  readonly property color failColor: config.red || "#f7768e"

  property string currentUser: userModel.lastUser
  property bool loginFailed: false
  property int sessionIndex: {
    for (var i = 0; i < sessionModel.rowCount(); i++) {
      var name = (sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole) || "").toString()
      if (name.indexOf("uwsm") !== -1)
        return i
    }
    return sessionModel.lastIndex
  }

  Connections {
    target: sddm
    function onLoginFailed() {
      root.loginFailed = true
      password.text = ""
      password.focus = true
    }
    function onLoginSucceeded() {
      root.loginFailed = false
    }
  }

  Column {
    anchors.centerIn: parent
    spacing: 40

    // Set, not shipped. This was a white PNG: the brightest thing on an otherwise dark screen, and
    // the one element that could not follow the palette while everything around it did. Drawing it
    // as text also empties the greeter of image assets entirely -- see upstream/EXCLUDED-ASSETS.md
    // for why that is the direction of travel here.
    Text {
      id: wordmark
      anchors.horizontalCenter: parent.horizontalCenter
      text: "agentarchy"
      color: root.textColor
      font.pixelSize: Math.max(40, Math.round(root.width / 20))
      font.bold: true
      font.letterSpacing: 6
    }

    // The entry field. A failed login turns the border and the dots red; upstream swapped in a
    // second set of sprites to say the same thing.
    //
    // The border is the load-bearing part, not the fill: last-horizon and solitude define
    // lighter_background as their background, so on those two the field is outlined rather than
    // filled. test/unit/themes.bats holds the invariant that muted never equals background, which
    // is what keeps the box visible on every palette.
    Rectangle {
      id: entry
      width: 286
      height: 48
      radius: 6
      anchors.horizontalCenter: parent.horizontalCenter
      color: root.fieldColor
      border.width: 2
      border.color: root.loginFailed ? root.failColor : root.idleBorder

      Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Repeater {
          model: Math.min(password.text.length, 21)

          Rectangle {
            width: 7
            height: 7
            radius: width / 2
            color: root.loginFailed ? root.failColor : root.textColor
          }
        }
      }

      // Invisible on purpose: it takes the keystrokes, and the dots above render the length.
      // Drawing the text as well would double every character.
      TextInput {
        id: password
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        font.pixelSize: 24
        font.letterSpacing: 5
        passwordCharacter: "•"
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        cursorDelegate: Item {}
        focus: true

        onTextChanged: root.loginFailed = false

        Keys.onPressed: {
          if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            sddm.login(root.currentUser, password.text, root.sessionIndex)
            event.accepted = true
          }
        }
      }
    }
  }

  Component.onCompleted: password.forceActiveFocus()
}
