import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.dock
import qs.desktop.modules.common
import qs.desktop.modules.applauncher

// One concrete top Bar surface. Its content is shared with the optional
// unified Dock host; this file owns layer-shell geometry and auto-hide.
PanelWindow {
    id: root

    property bool barEnabled: true

    WlrLayershell.namespace: "quickshell-bar"
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: ConfigService.barHeight

    // ── Auto-hide controller ──
    BarAutoHideController {
        id: hide
        mode: AppearanceConfigService.barVisibilityMode
        configReady: AppearanceConfigService.ready
        windowDataReady: WindowService.providerReady
        targetScreen: root.screen
        barHeight: root.implicitHeight
        edgeMargin: 15
        pointerInsideBar: contentHoverHandler.hovered
        popupOpen: barContentLoader.item?.statusArea?.anyPanelOpen ?? false
        launcherOpen: AppLauncherService.open
    }

    // Only "always" mode reserves a permanent top workspace strip.
    // In "smart" or "persistent" modes, exclusiveZone stays at 0 so
    // maximised windows extend to the top of the screen.
    exclusiveZone: (AppearanceConfigService.barVisibilityMode === "always" && root.barEnabled)
        ? implicitHeight : 0
    visible: root.barEnabled

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 0
        left: 15
        right: 15
    }

    // ── Visual Bar content ──
    Item {
        id: barWrapper
        x: 0
        y: hide.offsetY
        width: root.width
        height: root.height
        opacity: hide.barOpacity
        visible: root.barEnabled && hide.revealProgress > 0.001

        HoverHandler {
            id: contentHoverHandler
        }

        Loader {
            id: barContentLoader
            anchors.fill: parent
            active: root.barEnabled
            sourceComponent: Component {
                Item {
                    id: barContentItem
                    readonly property alias statusArea: barStatusArea

                    BarDateStatus {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }
                    }

                    BarStatusArea {
                        id: barStatusArea
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }
    }

    // ── Touch-top invisible trigger ──
    // A 8px hit area at the screen top to reveal Bar when hovered in hide modes.
    Item {
        id: topTriggerArea
        x: 0
        y: 0
        width: root.width
        height: hide.handleActive ? 8 : 0
        visible: hide.handleActive

        HoverHandler {
            id: topHoverHandler
            enabled: hide.handleActive
            onHoveredChanged: {
                if (hovered) {
                    hide.handleEntered()
                } else {
                    hide.handleExited()
                }
            }
        }

        TapHandler {
            enabled: hide.handleActive
            onTapped: hide.handleClicked()
        }
    }

    // Input mask mirror for visual content and top trigger.
    Item {
        id: barHitRegion
        x: 0
        y: hide.offsetY
        width: root.width
        height: root.height
        visible: false
    }

    Item {
        id: topHitRegion
        x: 0
        y: 0
        width: root.width
        height: hide.handleActive ? 8 : 0
        visible: false
    }

    // Shape the input region so transparent background passes clicks through.
    mask: Region {
        Region { item: barHitRegion }
        Region { item: topHitRegion }
    }
}
