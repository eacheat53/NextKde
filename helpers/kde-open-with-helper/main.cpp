#include <QCoreApplication>
#include <QDateTime>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QMimeDatabase>
#include <QProcess>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>
#include <QVariantMap>

// Bridge to the KDE portal's application chooser.  This is the modern icon
// grid used by KDE's portal integration, unlike KOpenWithDialog's older tree
// UI.  The portal also owns launching the app and persisting its choice.
int main(int argc, char *argv[])
{
    if (argc != 2)
        return 2;

    QCoreApplication application(argc, argv);
    const QString filePath = QString::fromLocal8Bit(argv[1]);
    const QUrl fileUrl = QUrl::fromLocalFile(filePath);
    // Match by suffix intentionally.  An empty project.md otherwise becomes
    // application/x-zerosize and KDE cannot offer Markdown editors first.
    const QString mimeType = QMimeDatabase().mimeTypeForFile(
        filePath, QMimeDatabase::MatchExtension).name();

    QDBusInterface portal(QStringLiteral("org.freedesktop.impl.portal.desktop.kde"),
                           QStringLiteral("/org/freedesktop/portal/desktop"),
                           QStringLiteral("org.freedesktop.impl.portal.AppChooser"),
                           QDBusConnection::sessionBus());
    if (!portal.isValid())
        return 1;

    QVariantMap options;
    options.insert(QStringLiteral("content_type"), mimeType);
    options.insert(QStringLiteral("uri"), fileUrl.toString());
    options.insert(QStringLiteral("filename"), fileUrl.fileName());
    options.insert(QStringLiteral("modal"), true);
    const auto reply = portal.call(QStringLiteral("ChooseApplication"),
        QVariant::fromValue(QDBusObjectPath(
            QStringLiteral("/org/freedesktop/portal/desktop/request/quickshell/open_with"))),
        QString(), QString(), QStringList(), options);
    if (reply.type() == QDBusMessage::ErrorMessage || reply.arguments().size() < 2
        || reply.arguments().at(0).toUInt() != 0)
        return 1;

    const QVariantMap result = reply.arguments().at(1).toMap();
    const QString applicationId = result.value(QStringLiteral("choice")).toString();
    if (applicationId.isEmpty())
        return 0;
    const QString desktopFile = QStandardPaths::locate(
        QStandardPaths::ApplicationsLocation, applicationId);
    if (desktopFile.isEmpty())
        return 1;
    // The helper itself is spawned by, and inherits the cgroup of, the
    // quickshell autostart unit.  A detached child keeps that cgroup, so the
    // chosen application is started through its own transient systemd user
    // scope — the same scheme KDE's and GNOME's launchers use — to keep it
    // out of the shell's cgroup (and alive across a shell restart).
    QString appId = applicationId;
    if (appId.endsWith(QLatin1String(".desktop")))
        appId.chop(8);
    appId.remove(QRegularExpression(QStringLiteral("[^A-Za-z0-9.:_-]")));
    const QString unitName = QStringLiteral("app-%1-%2.scope").arg(
        appId.isEmpty() ? QStringLiteral("app") : appId,
        QString::number(QDateTime::currentMSecsSinceEpoch(), 36)
            + QString::number(QRandomGenerator::global()->generate() % 1000000, 36));
    const QStringList gioArgs = {QStringLiteral("launch"), desktopFile, filePath};
    QStringList runArgs = {QStringLiteral("--user"), QStringLiteral("--scope"),
                           QStringLiteral("--quiet"), QStringLiteral("--collect"),
                           QStringLiteral("--unit"), unitName,
                           QStringLiteral("gio")};
    runArgs.append(gioArgs);
    return QProcess::startDetached(QStringLiteral("systemd-run"), runArgs)
           || QProcess::startDetached(QStringLiteral("gio"), gioArgs) ? 0 : 1;
}
