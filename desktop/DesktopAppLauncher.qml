pragma Singleton
import QtQuick
import Quickshell

// Starts standalone Qt Quick applications without importing their UI into, or
// tying their lifetime to, the Shell process.
QtObject {
    id: launcher

    readonly property string settingsEntrypoint:
        Quickshell.shellDir + "/apps/settings/main.qml"
    readonly property string settingsBinary:
        Quickshell.shellDir + "/apps/settings/build/kos-settings"

    function openSettings(page) {
        Quickshell.execDetached([
            "sh", "-c",
            "primary=\"$1\"; secondary=\"$2\"; qml=\"$3\"; page=\"$4\"; set --; "
            + "if [ -n \"$page\" ]; then set -- --page \"$page\"; fi; "
            + "if [ -x \"$primary\" ]; then exec \"$primary\" \"$@\"; fi; "
            + "if [ -x \"$secondary\" ]; then exec \"$secondary\" \"$@\"; fi; "
            + "if command -v kos-settings >/dev/null 2>&1; then exec kos-settings \"$@\"; fi; "
            + "if [ -x \"$HOME/.local/bin/kos-settings\" ]; then exec \"$HOME/.local/bin/kos-settings\" \"$@\"; fi; "
            + "if command -v qml6 >/dev/null 2>&1; then exec qml6 \"$qml\" \"$@\"; fi",
            "kos-settings-launch",
            launcher.settingsBinary,
            Quickshell.shellDir + "/.build/apps/settings/kos-settings",
            launcher.settingsEntrypoint,
            String(page ?? "")
        ])
    }
}
