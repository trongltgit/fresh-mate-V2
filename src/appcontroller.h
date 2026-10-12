#pragma once
#include <QObject>
#include <QVariantList>
#include <QPermissions>
#include <QGuiApplication>
#include <QFile>
#include <QDir>
#include <QUrl>
#include <QUuid>
#include <QImage>
#include <QImageReader>
#include <QStandardPaths>
#include "pantry_db.h"
#include "ai_service.h"
#include <QDebug>

class AppController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList products READ products NOTIFY productsChanged)

public:
    explicit AppController(PantryDb *db, AiService *ai, QObject *parent = nullptr)
        : QObject(parent), m_db(db), m_ai(ai)
    {
        refresh();
        connect(m_ai, &AiService::analysisReady, this, &AppController::onAnalysis);
    }

    QVariantList products() const { return m_products; }

    Q_INVOKABLE void refresh()
    {
        m_products = m_db->all();
        emit productsChanged();
    }

    Q_INVOKABLE bool saveProduct(const QVariantMap &m)
    {
        bool ok = m_db->add(m);
        if (ok) refresh();
        return ok;
    }

    Q_INVOKABLE bool deleteProduct(int id)
    {
        bool ok = m_db->remove(id);
        if (ok) refresh();
        return ok;
    }

    // Folder where camera shots are written before processing (always exists)
    Q_INVOKABLE QString cacheDir()
    {
        const QString d = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
        QDir().mkpath(d);
        return d;
    }

    // Takes ANY image location (plain path, file:// URL, or Android content://
    // URI returned by the gallery picker), reads it through QFile (which
    // understands content:// on Android), fixes EXIF rotation, shrinks it and
    // stores a JPEG copy in app storage. Returns the local file path, or ""
    // on failure. Used for BOTH camera and gallery photos.
    Q_INVOKABLE QString prepareImage(const QString &src)
    {
        QString s = src;
        if (s.startsWith(QLatin1String("file:")))
            s = QUrl(s).toLocalFile();

        QFile f(s);
        if (!f.open(QIODevice::ReadOnly)) {
            qWarning() << "prepareImage: cannot open" << src << f.errorString();
            return {};
        }
        QImageReader reader(&f);
        reader.setAutoTransform(true);
        QImage img = reader.read();
        if (img.isNull()) {
            qWarning() << "prepareImage: cannot decode" << src << reader.errorString();
            return {};
        }
        if (img.width() > 1600 || img.height() > 1600)
            img = img.scaled(1600, 1600, Qt::KeepAspectRatio, Qt::SmoothTransformation);

        const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
                            + QStringLiteral("/photos");
        QDir().mkpath(dir);
        const QString out = dir + QLatin1Char('/')
                            + QUuid::createUuid().toString(QUuid::WithoutBraces)
                            + QStringLiteral(".jpg");
        if (!img.save(out, "JPEG", 88)) {
            qWarning() << "prepareImage: cannot save" << out;
            return {};
        }
        // remove the raw camera temp file, keep the processed copy
        if (s.startsWith(cacheDir())) QFile::remove(s);
        return out;
    }

    // Camera permission is requested from C++ (QCameraPermission is not a QML type)
    Q_INVOKABLE void requestCameraPermission()
    {
        QCameraPermission perm;
        switch (qApp->checkPermission(perm)) {
        case Qt::PermissionStatus::Undetermined:
            qApp->requestPermission(perm, this, [this](const QPermission &p) {
                if (p.status() == Qt::PermissionStatus::Granted)
                    emit cameraPermissionGranted();
                else
                    emit cameraPermissionDenied();
            });
            return;
        case Qt::PermissionStatus::Denied:
            emit cameraPermissionDenied();
            return;
        case Qt::PermissionStatus::Granted:
            emit cameraPermissionGranted();
            return;
        }
    }

signals:
    void productsChanged();
    void analysisFilled(QVariantMap result);
    void cameraPermissionGranted();
    void cameraPermissionDenied();

private slots:
    void onAnalysis(QVariantMap r) { emit analysisFilled(r); }

private:
    PantryDb  *m_db;
    AiService *m_ai;
    QVariantList m_products;
};
