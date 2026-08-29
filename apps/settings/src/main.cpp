#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QProcess>
#include <QVariantMap>

class SettingsBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

public:
    explicit SettingsBridge(QObject *parent = nullptr) : QObject(parent) {}

    QString lastError() const { return m_lastError; }

    Q_INVOKABLE QVariantMap dockSnapshot() {
        return snapshotFromReply(callDock({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateDockLayout(double height) {
        return snapshotFromReply(callDock({QStringLiteral("updateLayout"),
                                           QString::number(height, 'f', 2)}));
    }

    Q_INVOKABLE QVariantMap updateDockPosition(const QString &position) {
        return snapshotFromReply(callDock({QStringLiteral("updatePosition"), position}));
    }

    Q_INVOKABLE QVariantMap updateDockIconMode(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateDockIconOpacity(double opacity) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconOpacity"), QString::number(opacity, 'f', 2)}));
    }

    Q_INVOKABLE QVariantMap updateDockIconTintColor(const QString &color) {
        return snapshotFromReply(callDock({QStringLiteral("updateIconTintColor"), color}));
    }

    Q_INVOKABLE QVariantMap updateDockVisibilityMode(const QString &mode) {
        return snapshotFromReply(callDock({QStringLiteral("updateVisibilityMode"), mode}));
    }

    Q_INVOKABLE QVariantMap appearanceSnapshot() {
        return appearanceSnapshotFromReply(callAppearance({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateDockBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateDockLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateDockBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateDockBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateDockLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateDockLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBarBlurInherit(bool inherit) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarBlurInherit"),
            inherit ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateBarBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateBarLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateLauncherBlurInherit(bool inherit) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateLauncherBlurInherit"),
            inherit ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateLauncherBlurStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateLauncherBlurStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateLauncherLiquidStrength(double strength) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateLauncherLiquidStrength"),
            QString::number(strength, 'f', 3)}));
    }

    Q_INVOKABLE QVariantMap updateShellStyle(const QString &style) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateShellStyle"), style}));
    }

    Q_INVOKABLE QVariantMap updateBarIntegratedWithDock(bool enabled) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarIntegratedWithDock"),
            enabled ? QStringLiteral("true") : QStringLiteral("false")}));
    }

    Q_INVOKABLE QVariantMap updateBarVisibilityMode(const QString &mode) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarVisibilityMode"), mode}));
    }

    Q_INVOKABLE QVariantMap resetAppearanceStrengths() {
        return appearanceSnapshotFromReply(callAppearance({QStringLiteral("resetStrengths")}));
    }

    Q_INVOKABLE QVariantMap launcherSnapshot() {
        return launcherSnapshotFromReply(callLauncher({QStringLiteral("snapshot")}));
    }

    Q_INVOKABLE QVariantMap updateLauncherDisplayMode(const QString &mode) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateDisplayMode"), mode}));
    }

    Q_INVOKABLE QVariantMap updateLauncherIconSize(double size) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateIconSize"),
            QString::number(size, 'f', 1)}));
    }

    Q_INVOKABLE QVariantMap updateLauncherIconSpacing(double spacing) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateIconSpacing"),
            QString::number(spacing, 'f', 1)}));
    }

    Q_INVOKABLE QVariantMap updateLauncherFontSize(double size) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateFontSize"),
            QString::number(size, 'f', 1)}));
    }

    Q_INVOKABLE QVariantMap updateLauncherFontWeight(const QString &weight) {
        return launcherSnapshotFromReply(callLauncher({
            QStringLiteral("updateFontWeight"), weight}));
    }

    Q_INVOKABLE bool applySystemAppearance(bool dark) {
        const QString scheme = dark ? QStringLiteral("Layan")
                                   : QStringLiteral("LayanLight");
        QProcess process;
        process.start(QStringLiteral("plasma-apply-colorscheme"), {scheme});
        if (!process.waitForStarted(1500)) {
            setLastError(QStringLiteral("无法启动 KDE 色彩方案工具"));
            return false;
        }
        if (!process.waitForFinished(5000)) {
            process.kill();
            process.waitForFinished();
            setLastError(QStringLiteral("KDE 色彩方案切换超时"));
            return false;
        }
        if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
            const auto error = QString::fromUtf8(process.readAllStandardError()).trimmed();
            setLastError(error.isEmpty() ? QStringLiteral("KDE 色彩方案切换失败") : error);
            return false;
        }

        QProcess kwin;
        kwin.start(QStringLiteral("qdbus6"), {
            QStringLiteral("org.kde.KWin"),
            QStringLiteral("/KWin"),
            QStringLiteral("reconfigure")});
        if (!kwin.waitForStarted(1500) || !kwin.waitForFinished(3000)
                || kwin.exitStatus() != QProcess::NormalExit || kwin.exitCode() != 0) {
            if (kwin.state() != QProcess::NotRunning) {
                kwin.kill();
                kwin.waitForFinished();
            }
            const auto error = QString::fromUtf8(kwin.readAllStandardError()).trimmed();
            setLastError(error.isEmpty()
                ? QStringLiteral("KWin 装饰刷新失败") : error);
            return false;
        }
        setLastError({});
        return true;
    }

signals:
    void lastErrorChanged();

private:
    QVariantMap snapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的 Dock 配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if (!object.contains(QStringLiteral("baseHeight"))) {
            setLastError(QStringLiteral("桌面环境返回的 Dock 配置不完整"));
            return {};
        }

        setLastError({});
        return {
            {QStringLiteral("baseHeight"), object.value(QStringLiteral("baseHeight")).toDouble()},
            {QStringLiteral("position"), object.value(QStringLiteral("position")).toString()},
            {QStringLiteral("iconMode"), object.value(QStringLiteral("iconMode")).toString()},
            {QStringLiteral("iconOpacity"), object.value(QStringLiteral("iconOpacity")).toDouble()},
            {QStringLiteral("iconTintColor"), object.value(QStringLiteral("iconTintColor")).toString()},
            {QStringLiteral("visibilityMode"), object.value(QStringLiteral("visibilityMode")).toString()},};
    }

    QVariantMap appearanceSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的外观配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if ((!object.contains(QStringLiteral("dockBlurStrength"))
                    && !object.contains(QStringLiteral("blurStrength")))
                || (!object.contains(QStringLiteral("dockLiquidStrength"))
                    && !object.contains(QStringLiteral("liquidStrength")))
                || !object.contains(QStringLiteral("shellStyle"))
                || !object.contains(QStringLiteral("barIntegratedWithDock"))) {
            setLastError(QStringLiteral("桌面环境返回的外观配置不完整"));
            return {};
        }

        const double dockBlur = object.contains(QStringLiteral("dockBlurStrength"))
            ? object.value(QStringLiteral("dockBlurStrength")).toDouble()
            : object.value(QStringLiteral("blurStrength")).toDouble();
        const double dockLiquid = object.contains(QStringLiteral("dockLiquidStrength"))
            ? object.value(QStringLiteral("dockLiquidStrength")).toDouble()
            : object.value(QStringLiteral("liquidStrength")).toDouble();
        const bool barInherit = object.value(QStringLiteral("barBlurInheritDock")).toBool(true);
        const double barBlur = object.value(QStringLiteral("barBlurStrength")).toDouble(0.42);
        const double barLiquid = object.value(QStringLiteral("barLiquidStrength")).toDouble(1.0);
        const bool launcherInherit = object.value(QStringLiteral("launcherBlurInheritDock")).toBool(true);
        const double launcherBlur = object.value(QStringLiteral("launcherBlurStrength")).toDouble(0.42);
        const double launcherLiquid = object.value(QStringLiteral("launcherLiquidStrength")).toDouble(1.0);

        const QString barVisibility = object.value(QStringLiteral("barVisibilityMode")).toString(QStringLiteral("always"));

        setLastError({});
        return {
            {QStringLiteral("dockBlurStrength"), dockBlur},
            {QStringLiteral("dockLiquidStrength"), dockLiquid},
            {QStringLiteral("barBlurInheritDock"), barInherit},
            {QStringLiteral("barBlurStrength"), barBlur},
            {QStringLiteral("barLiquidStrength"), barLiquid},
            {QStringLiteral("launcherBlurInheritDock"), launcherInherit},
            {QStringLiteral("launcherBlurStrength"), launcherBlur},
            {QStringLiteral("launcherLiquidStrength"), launcherLiquid},
            {QStringLiteral("effectiveDockBlur"), object.value(QStringLiteral("effectiveDockBlur")).toDouble(dockBlur)},
            {QStringLiteral("effectiveDockLiquid"), object.value(QStringLiteral("effectiveDockLiquid")).toDouble(dockLiquid)},
            {QStringLiteral("effectiveBarBlur"), object.value(QStringLiteral("effectiveBarBlur")).toDouble(barInherit ? dockBlur : barBlur)},
            {QStringLiteral("effectiveBarLiquid"), object.value(QStringLiteral("effectiveBarLiquid")).toDouble(barInherit ? dockLiquid : barLiquid)},
            {QStringLiteral("effectiveLauncherBlur"), object.value(QStringLiteral("effectiveLauncherBlur")).toDouble(launcherInherit ? dockBlur : launcherBlur)},
            {QStringLiteral("effectiveLauncherLiquid"), object.value(QStringLiteral("effectiveLauncherLiquid")).toDouble(launcherInherit ? dockLiquid : launcherLiquid)},
            {QStringLiteral("blurStrength"), dockBlur},
            {QStringLiteral("liquidStrength"), dockLiquid},
            {QStringLiteral("shellStyle"), object.value(QStringLiteral("shellStyle")).toString()},
            {QStringLiteral("barIntegratedWithDock"),
                object.value(QStringLiteral("barIntegratedWithDock")).toBool()},
            {QStringLiteral("barVisibilityMode"),
                barVisibility.isEmpty() ? QStringLiteral("always") : barVisibility},
            {QStringLiteral("tokenVersion"), object.value(QStringLiteral("tokenVersion")).toInt()},
        };
    }

    QVariantMap launcherSnapshotFromReply(const QString &payload) {
        if (payload.isEmpty())
            return {};

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(payload.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            setLastError(QStringLiteral("桌面环境返回了无效的启动台配置"));
            return {};
        }

        const QJsonObject object = document.object();
        if (!object.contains(QStringLiteral("displayMode"))) {
            setLastError(QStringLiteral("桌面环境返回的启动台配置不完整"));
            return {};
        }

        setLastError({});
        return {
            {QStringLiteral("displayMode"), object.value(QStringLiteral("displayMode")).toString()},
            {QStringLiteral("iconSize"), object.value(QStringLiteral("iconSize")).toDouble()},
            {QStringLiteral("iconSpacing"), object.value(QStringLiteral("iconSpacing")).toDouble()},
        };
    }

    QString callDock(const QStringList &arguments) {
        return callShell(QStringLiteral("dock-settings"), arguments,
                         QStringLiteral("Dock 设置请求失败"));
    }

    QString callAppearance(const QStringList &arguments) {
        return callShell(QStringLiteral("appearance-settings"), arguments,
                         QStringLiteral("外观设置请求失败"));
    }

    QString callLauncher(const QStringList &arguments) {
        return callShell(QStringLiteral("applauncher-settings"), arguments,
                         QStringLiteral("启动台设置请求失败"));
    }

    QString callShell(const QString &target, const QStringList &arguments,
                      const QString &fallbackError) {
        QProcess process;
        QStringList command{QStringLiteral("--path"), QStringLiteral(SETTINGS_SHELL_DIR),
                            QStringLiteral("ipc"), QStringLiteral("call"),
                            target};
        command.append(arguments);
        process.start(QStringLiteral("quickshell"), command);
        if (!process.waitForStarted(1500)) {
            setLastError(QStringLiteral("无法连接桌面环境"));
            return {};
        }
        if (!process.waitForFinished(2500)) {
            process.kill();
            process.waitForFinished();
            setLastError(QStringLiteral("桌面环境没有响应"));
            return {};
        }
        if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) {
            const auto error = QString::fromUtf8(process.readAllStandardError()).trimmed();
            setLastError(error.isEmpty() ? fallbackError : error);
            return {};
        }
        return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
    }

    void setLastError(const QString &error) {
        if (m_lastError == error)
            return;
        m_lastError = error;
        emit lastErrorChanged();
    }

    QString m_lastError;
};

int main(int argc, char *argv[]) {
    QGuiApplication application(argc, argv);
    // Keep this window out of the Shell's KWin rules. This must match the
    // installed desktop entry basename: kos-settings.desktop.
    application.setApplicationName(QStringLiteral("kos-settings"));
    application.setApplicationDisplayName(QStringLiteral(""));
    application.setDesktopFileName(QStringLiteral("kos-settings"));
    application.setOrganizationName(QStringLiteral("Quickshell"));

    SettingsBridge bridge;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("settingsBridge"), &bridge);
    const QUrl entrypoint = QUrl::fromLocalFile(
        QStringLiteral(SETTINGS_QML_DIR "/main.qml"));
    engine.load(entrypoint);
    if (engine.rootObjects().isEmpty())
        return 1;
    return application.exec();
}

#include "main.moc"
