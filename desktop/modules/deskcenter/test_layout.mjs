import {
    WIDGET_COLUMNS,
    configuredWidgets,
    defaultLayout,
    normalizeLayout,
    packWidgets,
} from "./DeskCenterLayout.mjs"

let failures = 0
function expect(condition, message) {
    if (!condition) {
        failures += 1
        console.log("FAIL:", message)
    }
}

const defaults = configuredWidgets(defaultLayout())
const defaultPlacements = packWidgets(defaults, WIDGET_COLUMNS, 4)
expect(defaultPlacements.length === 6, "all default widgets fit")
expect(defaultPlacements.find(item => item.id === "weather")?.column === 1,
    "weather keeps its default column")
expect(defaultPlacements.find(item => item.id === "music")?.row === 2,
    "music keeps its default row")

const disabled = defaultLayout()
disabled.widgets.weather.enabled = false
expect(packWidgets(configuredWidgets(disabled), WIDGET_COLUMNS, 4).length === 5,
    "disabled widgets are excluded")

const malformed = normalizeLayout({
    order: ["music", "unknown", "music"],
    widgets: { music: { columns: 99, rows: -4, column: 99, row: -1 } },
})
expect(malformed.order[0] === "music" && malformed.order.length === 6,
    "order is deduplicated and completed")
expect(malformed.widgets.music.columns === 4 && malformed.widgets.music.rows === 1,
    "widget sizes are clamped")
expect(malformed.widgets.music.column === 0 && malformed.widgets.music.row === 0,
    "widget positions are clamped")

const conflict = defaultLayout()
conflict.widgets.weather.column = 0
conflict.widgets.weather.row = 0
const conflictPlacements = packWidgets(configuredWidgets(conflict), WIDGET_COLUMNS, 4)
expect(conflictPlacements.length === 6, "conflicting manual positions fall back to free slots")
expect(conflictPlacements.find(item => item.id === "weather")?.column !== 0,
    "conflicting weather widget is repacked")

console.log(failures ? `\n${failures} FAILED` : "\nDeskCenter layout tests passed")
process.exit(failures ? 1 : 0)
