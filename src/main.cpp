#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QStringList>
#include "appcontroller.h"
#include "ai_service.h"
#include "pantry_db.h"
#include "nativemedia.h"

int main(int argc, char *argv[])
{
#ifdef Q_OS_IOS
    // Use Apple's own media backend (the FFmpeg one is not shipped for iOS).
    qputenv("QT_MEDIA_BACKEND", "darwin");
#endif
    QGuiApplication app(argc, argv);
    app.setApplicationName("FreshMate");
    app.setOrganizationName("FreshMate");

    PantryDb db;
    AiService ai;
    AppController controller(&db, &ai);
    NativeMedia nativeMedia;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("appController", &controller);
    engine.rootContext()->setContextProperty("aiService", &ai);
    engine.rootContext()->setContextProperty("nativeMedia", &nativeMedia);

    // Diagnostic build: collect any QML warnings/errors instead of exiting
    // silently. This is what makes a real problem in Main.qml show up as
    // readable text on the phone screen instead of a flash-and-close.
    QStringList qmlErrors;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings,
                      [&qmlErrors](const QList<QQmlError> &warnings) {
        for (const QQmlError &e : warnings)
            qmlErrors << e.toString();
    });

    const QUrl url(QStringLiteral("qrc:/qt/qml/FreshMate/qml/Main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        // Main.qml failed to load. Show the error(s) on screen instead of
        // exiting, so it can be read directly on the phone -- no adb needed.
        QString msg = qmlErrors.isEmpty()
            ? QStringLiteral("Main.qml failed to load, but no QML warnings were reported.\n"
                              "This usually means a missing/incompatible QML module or a C++\n"
                              "type registration problem.")
            : qmlErrors.join(QStringLiteral("\n\n"));

        QString escaped = msg;
        escaped.replace(QStringLiteral("\\"), QStringLiteral("\\\\"));
        escaped.replace(QStringLiteral("\""), QStringLiteral("\\\""));
        escaped.replace(QStringLiteral("\n"), QStringLiteral("\\n"));

        const QString fallbackQml = QStringLiteral(
            "import QtQuick\n"
            "import QtQuick.Controls\n"
            "ApplicationWindow {\n"
            "    visible: true\n"
            "    width: 420; height: 820\n"
            "    title: \"FreshMate - QML Error\"\n"
            "    color: \"#1a0000\"\n"
            "    Flickable {\n"
            "        anchors.fill: parent\n"
            "        anchors.margins: 16\n"
            "        contentWidth: width\n"
            "        contentHeight: errText.implicitHeight\n"
            "        Text {\n"
            "            id: errText\n"
            "            width: parent.width\n"
            "            wrapMode: Text.Wrap\n"
            "            color: \"#ffb4b4\"\n"
            "            font.pixelSize: 14\n"
            "            text: \"QML FAILED TO LOAD:\\n\\n%1\"\n"
            "        }\n"
            "    }\n"
            "}\n"
        ).arg(escaped);

        engine.loadData(fallbackQml.toUtf8());
    }

    return app.exec();
}
