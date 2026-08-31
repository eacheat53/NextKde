export const WIDGET_COLUMNS = 4

export const WIDGET_CATALOG = [
    {
        id: "clock", label: "时钟与计时器", description: "模拟时钟和倒计时",
        symbol: "◷", tint: "#ff375f", minColumns: 1, maxColumns: 2,
        minRows: 1, maxRows: 2, columns: 1, rows: 1, column: 0, row: 0,
        startColor: "#21161e", endColor: "#170f14", surface: false,
    },
    {
        id: "weather", label: "天气", description: "当前天气和短期预报",
        symbol: "☁", tint: "#5ac8fa", minColumns: 2, maxColumns: 4,
        minRows: 1, maxRows: 2, columns: 3, rows: 1, column: 1, row: 0,
        startColor: "#404f86", endColor: "#30345e", surface: false,
    },
    {
        id: "calendar", label: "日历", description: "月历和今日日期",
        symbol: "▦", tint: "#ff9500", minColumns: 2, maxColumns: 4,
        minRows: 1, maxRows: 2, columns: 2, rows: 1, column: 2, row: 1,
        startColor: "#ffffff", endColor: "#f2f2f4", surface: false,
    },
    {
        id: "system", label: "系统状态", description: "性能、存储和温度指标",
        symbol: "⌁", tint: "#30d158", minColumns: 2, maxColumns: 4,
        minRows: 1, maxRows: 2, columns: 2, rows: 1, column: 0, row: 1,
        startColor: "#f5f3f6", endColor: "#e9e6eb", surface: false,
    },
    {
        id: "activity", label: "活动记录", description: "在线时间和应用使用情况",
        symbol: "◉", tint: "#af52de", minColumns: 2, maxColumns: 4,
        minRows: 1, maxRows: 2, columns: 2, rows: 1, column: 0, row: 2,
        startColor: "#29252f", endColor: "#17151c", surface: false,
    },
    {
        id: "music", label: "音乐", description: "当前媒体和播放控制",
        symbol: "♫", tint: "#ff2d55", minColumns: 2, maxColumns: 4,
        minRows: 1, maxRows: 2, columns: 2, rows: 1, column: 2, row: 2,
        startColor: "#101010", endColor: "#101010", surface: false,
    },
]

function catalogForId(widgetId) {
    for (let index = 0; index < WIDGET_CATALOG.length; ++index) {
        if (WIDGET_CATALOG[index].id === widgetId)
            return WIDGET_CATALOG[index]
    }
    return null
}

function clampInteger(value, minimum, maximum, fallback) {
    const numeric = Math.round(Number(value))
    return Number.isFinite(numeric)
        ? Math.max(minimum, Math.min(maximum, numeric)) : fallback
}

function defaultWidgetState(widget) {
    return {
        enabled: true,
        columns: widget.columns,
        rows: widget.rows,
        automatic: false,
        column: widget.column,
        row: widget.row,
    }
}

export function defaultLayout() {
    const widgets = {}
    for (const widget of WIDGET_CATALOG)
        widgets[widget.id] = defaultWidgetState(widget)
    return {
        order: WIDGET_CATALOG.map(widget => widget.id),
        widgets,
    }
}

export function normalizeLayout(rawLayout) {
    const raw = rawLayout && typeof rawLayout === "object" ? rawLayout : {}
    const rawOrder = Array.isArray(raw.order) ? raw.order : []
    const order = []
    for (const id of rawOrder) {
        if (catalogForId(id) && !order.includes(id))
            order.push(id)
    }
    for (const widget of WIDGET_CATALOG) {
        if (!order.includes(widget.id))
            order.push(widget.id)
    }

    const widgets = {}
    const rawWidgets = raw.widgets && typeof raw.widgets === "object" ? raw.widgets : {}
    for (const widget of WIDGET_CATALOG) {
        const state = rawWidgets[widget.id] && typeof rawWidgets[widget.id] === "object"
            ? rawWidgets[widget.id] : {}
        const columns = clampInteger(state.columns, widget.minColumns,
            Math.min(widget.maxColumns, WIDGET_COLUMNS), widget.columns)
        const rows = clampInteger(state.rows, widget.minRows, widget.maxRows, widget.rows)
        widgets[widget.id] = {
            enabled: state.enabled === undefined ? true : Boolean(state.enabled),
            columns,
            rows,
            automatic: state.automatic === undefined ? false : Boolean(state.automatic),
            column: clampInteger(state.column, 0, WIDGET_COLUMNS - columns, widget.column),
            row: clampInteger(state.row, 0, 19, widget.row),
        }
    }
    return { order, widgets }
}

export function configuredWidgets(rawLayout) {
    const layout = normalizeLayout(rawLayout)
    return layout.order.map((id, orderIndex) => {
        const catalog = catalogForId(id)
        const state = layout.widgets[id]
        return Object.assign({}, catalog, state, { orderIndex })
    })
}

function fitsAt(occupied, columnCount, rowCount, column, row, columns, rows) {
    if (column < 0 || row < 0 || column + columns > columnCount || row + rows > rowCount)
        return false
    for (let y = row; y < row + rows; ++y) {
        for (let x = column; x < column + columns; ++x) {
            if (occupied[y][x])
                return false
        }
    }
    return true
}

function occupy(occupied, column, row, columns, rows) {
    for (let y = row; y < row + rows; ++y)
        for (let x = column; x < column + columns; ++x)
            occupied[y][x] = true
}

export function packWidgets(definitions, columnCount, rowCount) {
    const columns = Math.max(1, Math.round(Number(columnCount) || 1))
    const rows = Math.max(0, Math.round(Number(rowCount) || 0))
    const occupied = Array.from({ length: rows }, () => Array(columns).fill(false))
    const placements = []
    const ordered = Array.isArray(definitions)
        ? definitions.filter(widget => widget && widget.enabled !== false)
            .slice().sort((left, right) => left.orderIndex - right.orderIndex)
        : []

    for (const widget of ordered) {
        const width = Math.max(1, Math.min(columns, Math.round(widget.columns || 1)))
        const height = Math.max(1, Math.round(widget.rows || 1))
        let placement = null

        if (!widget.automatic) {
            const preferredColumn = Math.round(Number(widget.column) || 0)
            const preferredRow = Math.round(Number(widget.row) || 0)
            if (fitsAt(occupied, columns, rows, preferredColumn, preferredRow, width, height))
                placement = { column: preferredColumn, row: preferredRow }
        }

        if (!placement) {
            for (let row = 0; row <= rows - height && !placement; ++row) {
                for (let column = 0; column <= columns - width; ++column) {
                    if (fitsAt(occupied, columns, rows, column, row, width, height)) {
                        placement = { column, row }
                        break
                    }
                }
            }
        }

        if (!placement)
            continue
        occupy(occupied, placement.column, placement.row, width, height)
        placements.push({
            id: widget.id,
            column: placement.column,
            row: placement.row,
            columns: width,
            rows: height,
        })
    }
    return placements
}
