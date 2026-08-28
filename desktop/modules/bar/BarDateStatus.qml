import Quickshell
import QtQuick
import qs.desktop.modules.dock

// Reusable date/time cluster shared by the standalone top Bar and the
// bottom unified Dock host. It owns no layer-shell geometry.
Item {
    id: root

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7

        Text {
            id: timeText
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "h:mm")
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                family: "SF Pro Display"
                pixelSize: 14
                weight: Font.Bold
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "M月d日 dddd")
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                family: "Noto Sans CJK SC"
                pixelSize: 14
                weight: Font.Bold
            }
        }
    }
}
