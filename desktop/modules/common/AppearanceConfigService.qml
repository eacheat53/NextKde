pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global appearance settings shared by shell surfaces. Keep these values out
// of DockConfigService: glass material is a shell-wide concern, while pinned
// items, Dock geometry and visibility remain Dock-owned state.
QtObject {
    id: service

    readonly property string configDir: Quickshell.stateDir + "/appearance"
    readonly property string configPath: configDir + "/config.json"

    // Defaults preserve the material that existed before these controls:
    // LiquidGlassControl used a 10px blur (10 / 24 ~= 0.42), while large
    // surfaces rendered their liquid layers at full strength.
    property real dockBlurStrength: 0.42
    property real dockLiquidStrength: 1.0

    // Bar blur settings: either inherits dock baseline or uses independent values.
    property bool barBlurInheritDock: true
    property real barBlurStrength: 0.42
    property real barLiquidStrength: 1.0

    // Launcher blur settings: either inherits dock baseline or uses independent values.
    property bool launcherBlurInheritDock: true
    property real launcherBlurStrength: 0.42
    property real launcherLiquidStrength: 1.0

    // Backward compatibility aliases for Dock/global baseline:
    property real blurStrength: dockBlurStrength
    property real liquidStrength: dockLiquidStrength

    // Effective reactive properties for consumers:
    readonly property real effectiveDockBlur: dockBlurStrength
    readonly property real effectiveDockLiquid: dockLiquidStrength
    readonly property real effectiveBarBlur: barBlurInheritDock
        ? dockBlurStrength : barBlurStrength
    readonly property real effectiveBarLiquid: barBlurInheritDock
        ? dockLiquidStrength : barLiquidStrength
    readonly property real effectiveLauncherBlur: launcherBlurInheritDock
        ? dockBlurStrength : launcherBlurStrength
    readonly property real effectiveLauncherLiquid: launcherBlurInheritDock
        ? dockLiquidStrength : launcherLiquidStrength

    // "macos" matches the shell geometry that predates selectable styles,
    // so upgrading an existing installation does not unexpectedly reshape it.
    property string shellStyle: "macos"
    property bool barIntegratedWithDock: false
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"
    property string barLayoutMode: "full" // "full" | "floating"
    property bool ready: false

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material"
    }

    function isValidBarVisibilityMode(value) {
        return value === "always" || value === "smart"
            || value === "persistent"
    }

    function isValidBarLayoutMode(value) {
        return value === "full" || value === "floating"
    }

    function _normalized(value) {
        const number = Number(value)
        return Number.isFinite(number)
            ? Math.max(0.0, Math.min(1.0, number)) : NaN
    }

    function _toBool(value) {
        return value === true || value === 1
            || String(value).toLowerCase() === "true"
    }

    function updateDockBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(dockBlurStrength - value) <= 0.001)
            return false
        dockBlurStrength = value
        blurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateDockLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(dockLiquidStrength - value) <= 0.001)
            return false
        dockLiquidStrength = value
        liquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    // Backward compatibility aliases
    function updateBlurStrength(rawValue) {
        return updateDockBlurStrength(rawValue)
    }

    function updateLiquidStrength(rawValue) {
        return updateDockLiquidStrength(rawValue)
    }

    function updateBarBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (barBlurInheritDock === value)
            return false
        barBlurInheritDock = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateBarBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(barBlurStrength - value) <= 0.001)
            return false
        barBlurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateBarLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(barLiquidStrength - value) <= 0.001)
            return false
        barLiquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLauncherBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (launcherBlurInheritDock === value)
            return false
        launcherBlurInheritDock = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLauncherBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherBlurStrength - value) <= 0.001)
            return false
        launcherBlurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLauncherLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherLiquidStrength - value) <= 0.001)
            return false
        launcherLiquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateShellStyle(rawStyle) {
        const style = String(rawStyle)
        if (!isValidShellStyle(style) || shellStyle === style)
            return false
        shellStyle = style
        saveTimer.restart()
        return true
    }

    function updateBarIntegratedWithDock(rawValue) {
        const value = _toBool(rawValue)
        if (barIntegratedWithDock === value)
            return false
        barIntegratedWithDock = value
        saveTimer.restart()
        return true
    }

    function updateBarVisibilityMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidBarVisibilityMode(mode) || barVisibilityMode === mode)
            return false
        barVisibilityMode = mode
        saveTimer.restart()
        return true
    }

    function updateBarLayoutMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidBarLayoutMode(mode) || barLayoutMode === mode)
            return false
        barLayoutMode = mode
        saveTimer.restart()
        return true
    }

    function resetStrengths() {
        const dockBlurChanged = Math.abs(dockBlurStrength - 0.42) > 0.001
        const dockLiquidChanged = Math.abs(dockLiquidStrength - 1.0) > 0.001
        const barInheritChanged = !barBlurInheritDock
        const barBlurChanged = Math.abs(barBlurStrength - 0.42) > 0.001
        const barLiquidChanged = Math.abs(barLiquidStrength - 1.0) > 0.001
        const launcherInheritChanged = !launcherBlurInheritDock
        const launcherBlurChanged = Math.abs(launcherBlurStrength - 0.42) > 0.001
        const launcherLiquidChanged = Math.abs(launcherLiquidStrength - 1.0) > 0.001

        dockBlurStrength = 0.42
        dockLiquidStrength = 1.0
        blurStrength = 0.42
        liquidStrength = 1.0
        barBlurInheritDock = true
        barBlurStrength = 0.42
        barLiquidStrength = 1.0
        launcherBlurInheritDock = true
        launcherBlurStrength = 0.42
        launcherLiquidStrength = 1.0

        const changed = dockBlurChanged || dockLiquidChanged || barInheritChanged
            || barBlurChanged || barLiquidChanged || launcherInheritChanged
            || launcherBlurChanged || launcherLiquidChanged

        if (changed) {
            saveTimer.restart()
            effectSyncTimer.restart()
        }
        return changed
    }

    property Timer saveTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: service._save()
    }

    // The compositor plugin owns the real backdrop blur/refraction for Dock
    // and other BackgroundEffect regions. Quickshell can publish the region,
    // but Wayland exposes no per-surface strength field, so synchronize the
    // two user-facing values with the custom Glass effect's own settings.
    // This deliberately does not touch KDE's stock [Effect-blur] group.
    property Timer effectSyncTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: service._syncGlassEffect()
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
            console.warn("[AppearanceConfig] cannot create process: " + error)
        }
        return null
    }

    function _save() {
        const payload = JSON.stringify({
            version: 5,
            dockBlurStrength: service.dockBlurStrength,
            dockLiquidStrength: service.dockLiquidStrength,
            barBlurInheritDock: service.barBlurInheritDock,
            barBlurStrength: service.barBlurStrength,
            barLiquidStrength: service.barLiquidStrength,
            launcherBlurInheritDock: service.launcherBlurInheritDock,
            launcherBlurStrength: service.launcherBlurStrength,
            launcherLiquidStrength: service.launcherLiquidStrength,
            // Backwards compatibility fields for external tools
            blurStrength: service.dockBlurStrength,
            liquidStrength: service.dockLiquidStrength,
            shellStyle: service.shellStyle,
            barIntegratedWithDock: service.barIntegratedWithDock,
            barVisibilityMode: service.barVisibilityMode,
            barLayoutMode: service.barLayoutMode,
        }, null, 2)
        const process = _makeProcess([
            "sh", "-c",
            "mkdir -p \"$1\" && printf %s \"$2\" > \"$1/config.json.tmp\" && mv \"$1/config.json.tmp\" \"$1/config.json\"",
            "appearance-config-save",
            service.configDir,
            payload,
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] save failed code=" + code
                    + " stderr=" + (process.stderr?.text ?? ""))
            }
        })
        process.running = true
    }

    function _syncGlassEffect() {
        const dockBlurLevel = Math.round(1 + service.effectiveDockBlur * 14)
        const contentBlurLevel = Math.round(1 + (service.launcherBlurInheritDock ? service.effectiveDockBlur : service.effectiveLauncherBlur) * 14)
        const refractionLevel = Math.round(service.effectiveDockLiquid * 20)
        const process = _makeProcess([
            "sh", "-c",
            "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BlurStrength \"$1\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength \"$2\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength \"$3\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength \"$1\" && "
                + "if [ \"$(qdbus6 org.kde.KWin /Effects org.kde.KWin.Effects.isEffectLoaded glass 2>/dev/null)\" != \"true\" ]; then "
                + "  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect blur 2>/dev/null; "
                + "  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect glass 2>/dev/null; "
                + "fi; "
                + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass 2>/dev/null || "
                + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect blur 2>/dev/null",
            "appearance-glass-sync",
            String(contentBlurLevel),
            String(dockBlurLevel),
            String(refractionLevel),
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] Glass effect sync failed code="
                    + code + " stderr=" + (process.stderr?.text ?? ""))
            } else {
                console.log("[AppearanceConfig] Glass effect dockBlur=" + dockBlurLevel
                    + " contentBlur=" + contentBlurLevel + " liquid=" + refractionLevel)
            }
            process.destroy()
        })
        process.running = true
    }

    function _load() {
        const process = _makeProcess([
            "sh", "-c", "cat \"$1\"", "appearance-config-load",
            service.configPath,
        ])
        if (!process) {
            ready = true
            return
        }
        process.exited.connect(function(code) {
            if (code === 0 && process.stdout?.text) {
                try {
                    const object = JSON.parse(process.stdout.text)
                    const dockBlur = service._normalized(object.dockBlurStrength ?? object.blurStrength)
                    const dockLiquid = service._normalized(object.dockLiquidStrength ?? object.liquidStrength)
                    const hasBarInherit = typeof object.barBlurInheritDock === "boolean"
                    const barBlur = service._normalized(object.barBlurStrength)
                    const barLiquid = service._normalized(object.barLiquidStrength)
                    const hasLauncherInherit = typeof object.launcherBlurInheritDock === "boolean"
                    const launcherBlur = service._normalized(object.launcherBlurStrength)
                    const launcherLiquid = service._normalized(object.launcherLiquidStrength)
                    const style = String(object.shellStyle ?? "")
                    const hasBarIntegration = typeof object.barIntegratedWithDock === "boolean"
                    const barVisibility = String(object.barVisibilityMode ?? "")
                    const barLayout = String(object.barLayoutMode ?? "")

                    if (Number.isFinite(dockBlur)) {
                        service.dockBlurStrength = dockBlur
                        service.blurStrength = dockBlur
                    }
                    if (Number.isFinite(dockLiquid)) {
                        service.dockLiquidStrength = dockLiquid
                        service.liquidStrength = dockLiquid
                    }
                    if (hasBarInherit)
                        service.barBlurInheritDock = object.barBlurInheritDock
                    if (Number.isFinite(barBlur))
                        service.barBlurStrength = barBlur
                    if (Number.isFinite(barLiquid))
                        service.barLiquidStrength = barLiquid
                    if (hasLauncherInherit)
                        service.launcherBlurInheritDock = object.launcherBlurInheritDock
                    if (Number.isFinite(launcherBlur))
                        service.launcherBlurStrength = launcherBlur
                    if (Number.isFinite(launcherLiquid))
                        service.launcherLiquidStrength = launcherLiquid
                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (hasBarIntegration)
                        service.barIntegratedWithDock = object.barIntegratedWithDock
                    if (service.isValidBarVisibilityMode(barVisibility))
                        service.barVisibilityMode = barVisibility
                    if (service.isValidBarLayoutMode(barLayout))
                        service.barLayoutMode = barLayout

                    if (Number(object.version) !== 5
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration
                            || !service.isValidBarVisibilityMode(barVisibility)
                            || !service.isValidBarLayoutMode(barLayout)
                            || !hasBarInherit
                            || !hasLauncherInherit)
                        service.saveTimer.restart()
                } catch (error) {
                    console.warn("[AppearanceConfig] parse error: " + error)
                }
            }
            service.ready = true
            service.effectSyncTimer.restart()
            process.destroy()
        })
        process.running = true
    }

    Component.onCompleted: _load()
}
