pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "DeskCenterLayout.mjs" as DeskLayout

QtObject {
    id: service

    readonly property string configDir: Quickshell.stateDir + "/deskcenter"
    readonly property string configPath: configDir + "/config.json"
    readonly property int widgetColumns: DeskLayout.WIDGET_COLUMNS
    property var perScreenLayouts: ({})
    property bool ready: false

    function screenKey(rawName) {
        const name = String(rawName ?? "").trim()
        return name.length > 0 ? name : "default"
    }

    function layoutForScreen(rawName) {
        const key = screenKey(rawName)
        return DeskLayout.normalizeLayout(perScreenLayouts[key])
    }

    function widgetsForScreen(rawName) {
        return DeskLayout.configuredWidgets(layoutForScreen(rawName))
    }

    function widgetLabel(widgetId) {
        const widgets = DeskLayout.WIDGET_CATALOG
        for (let index = 0; index < widgets.length; ++index) {
            if (widgets[index].id === widgetId)
                return widgets[index].label
        }
        return widgetId
    }

    function availableScreens() {
        const result = []
        const screens = Quickshell.screens
        for (let index = 0; index < screens.length; ++index) {
            const screen = screens[index]
            const name = String(screen?.name ?? "").trim()
            if (!name)
                continue
            result.push({
                name,
                label: name + "  " + Math.round(screen.width) + "×" + Math.round(screen.height),
                width: Math.round(screen.width),
                height: Math.round(screen.height),
            })
        }
        return result
    }

    function snapshot(rawName) {
        const screen = screenKey(rawName)
        const layout = layoutForScreen(screen)
        return {
            version: 1,
            screen,
            screens: availableScreens(),
            widgetColumns,
            order: layout.order,
            widgets: DeskLayout.configuredWidgets(layout),
        }
    }

    function _commitLayout(rawName, rawLayout) {
        const key = screenKey(rawName)
        const nextLayouts = Object.assign({}, perScreenLayouts)
        nextLayouts[key] = DeskLayout.normalizeLayout(rawLayout)
        perScreenLayouts = nextLayouts
        saveTimer.restart()
        return true
    }

    function updateWidget(rawName, widgetId, enabled, columns, rows,
            column, row, automatic) {
        const layout = layoutForScreen(rawName)
        if (!layout.widgets[widgetId])
            return false
        layout.widgets[widgetId] = {
            enabled: Boolean(enabled),
            columns: Number(columns),
            rows: Number(rows),
            column: Number(column),
            row: Number(row),
            automatic: Boolean(automatic),
        }
        return _commitLayout(rawName, layout)
    }

    function updateWidgetEnabled(rawName, widgetId, enabled) {
        const layout = layoutForScreen(rawName)
        const state = layout.widgets[widgetId]
        if (!state || state.enabled === Boolean(enabled))
            return false
        state.enabled = Boolean(enabled)
        return _commitLayout(rawName, layout)
    }

    function moveWidget(rawName, widgetId, offset) {
        const layout = layoutForScreen(rawName)
        const from = layout.order.indexOf(widgetId)
        const to = Math.max(0, Math.min(layout.order.length - 1,
            from + Math.round(Number(offset))))
        if (from < 0 || from === to)
            return false
        layout.order.splice(from, 1)
        layout.order.splice(to, 0, widgetId)
        return _commitLayout(rawName, layout)
    }

    function resetScreen(rawName) {
        const key = screenKey(rawName)
        const nextLayouts = Object.assign({}, perScreenLayouts)
        delete nextLayouts[key]
        perScreenLayouts = nextLayouts
        saveTimer.restart()
        return true
    }

    function copyLayoutToAllScreens(rawName) {
        const source = layoutForScreen(rawName)
        const nextLayouts = Object.assign({}, perScreenLayouts)
        const screens = availableScreens()
        for (let index = 0; index < screens.length; ++index)
            nextLayouts[screenKey(screens[index].name)] = DeskLayout.normalizeLayout(source)
        perScreenLayouts = nextLayouts
        saveTimer.restart()
        return true
    }

    function resetAll() {
        perScreenLayouts = ({})
        saveTimer.restart()
        return true
    }

    property Timer saveTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: service._save()
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    function _makeProcess(command) {
        try {
            return processFactory.createObject(service, { command })
        } catch (error) {
            console.warn("[DeskCenterConfig] cannot create process: " + error)
        }
        return null
    }

    function _save() {
        const payload = JSON.stringify({
            version: 1,
            perScreenLayouts: service.perScreenLayouts,
        }, null, 2)
        const process = _makeProcess([
            "sh", "-c",
            "mkdir -p \"$1\" && printf %s \"$2\" > \"$1/config.json.tmp\" && mv \"$1/config.json.tmp\" \"$1/config.json\"",
            "deskcenter-config-save", service.configDir, payload,
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[DeskCenterConfig] save failed code=" + code
                    + " stderr=" + (process.stderr?.text ?? ""))
            }
            process.destroy()
        })
        process.running = true
    }

    function _load() {
        const process = _makeProcess([
            "sh", "-c", "cat \"$1\"", "deskcenter-config-load", service.configPath,
        ])
        if (!process) {
            ready = true
            return
        }
        process.exited.connect(function(code) {
            if (code === 0 && process.stdout?.text) {
                try {
                    const object = JSON.parse(process.stdout.text)
                    if (object.perScreenLayouts && typeof object.perScreenLayouts === "object") {
                        const normalized = {}
                        for (const key of Object.keys(object.perScreenLayouts))
                            normalized[screenKey(key)] = DeskLayout.normalizeLayout(object.perScreenLayouts[key])
                        service.perScreenLayouts = normalized
                    }
                    if (Number(object.version) !== 1)
                        saveTimer.restart()
                } catch (error) {
                    console.warn("[DeskCenterConfig] parse error: " + error)
                }
            }
            service.ready = true
            process.destroy()
        })
        process.running = true
    }

    Component.onCompleted: _load()
}
