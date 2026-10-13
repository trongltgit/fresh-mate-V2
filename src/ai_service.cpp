#include "ai_service.h"
#include "proxy_config.h"
#include <QFile>
#include <QImage>
#include <QBuffer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QSettings>
#include <QDate>
#include <QDebug>
#include <QSslSocket>
#include <QUrl>

// Fix #7: correct Groq model IDs
static const char *kVisionModel = "qwen/qwen3.8-27b";
static const char *kChatModel   = "openai/gpt-oss-20b";
static const QUrl  kGroqUrl("https://api.groq.com/openai/v1/chat/completions");

static const QString kProxyUrl = QStringLiteral(FRESHMATE_PROXY_URL);
static const QString kAppToken = QStringLiteral(FRESHMATE_APP_TOKEN);

bool AiService::usingProxy() const { return !kProxyUrl.isEmpty(); }

// Build the request: via your proxy (no Groq key on the phone) or direct to Groq.
static QNetworkRequest makeRequest(const QString &key)
{
    const bool proxy = !kProxyUrl.isEmpty();
    QNetworkRequest req(proxy ? QUrl(kProxyUrl) : kGroqUrl);
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(90000);   // free hosts may need ~60s to wake up
    if (proxy) req.setRawHeader("X-App-Token", kAppToken.toUtf8());
    else       req.setRawHeader("Authorization", ("Bearer " + key).toUtf8());
    return req;
}

AiService::AiService(QObject *parent) : QObject(parent)
{
    QSettings s;
    m_key = s.value(QStringLiteral("groq_api_key")).toString();
}

void AiService::setApiKey(const QString &v)
{
    if (m_key == v) return;
    m_key = v;
    QSettings s;
    s.setValue(QStringLiteral("groq_api_key"), v);
    emit apiKeyChanged();
}

// Compress photo to JPEG base64, max 1024 px (plenty for vision, keeps payload small)
static QString b64File(const QString &path)
{
    // Read bytes via QFile so both normal paths and Android content:// URIs work
    QFile f(path);
    QImage img;
    if (f.open(QIODevice::ReadOnly))
        img.loadFromData(f.readAll());
    if (img.isNull()) {
        qWarning() << "b64File: cannot load" << path;
        return {};
    }
    img = img.scaled(1024, 1024, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QByteArray b;
    QBuffer    buf(&b);
    buf.open(QIODevice::WriteOnly);
    img.save(&buf, "JPEG", 85);
    return QString::fromLatin1(b.toBase64());
}


// Human-readable error: HTTP status + server message (so we can tell 401/404/502 apart)
static QString describeError(QNetworkReply *reply, const QByteArray &raw)
{
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QString body = QString::fromUtf8(raw).left(300);
    const auto obj = QJsonDocument::fromJson(raw).object();
    if (obj.contains(QStringLiteral("error"))) {
        const auto e = obj.value(QStringLiteral("error"));
        body = e.isObject() ? e.toObject().value(QStringLiteral("message")).toString()
                            : e.toString();
    }
    QString hint;
    switch (status) {
    case 401: hint = QStringLiteral(" (token mismatch: FRESHMATE_APP_TOKEN must equal APP_TOKEN on Render)"); break;
    case 404: hint = QStringLiteral(" (wrong URL or the Render service is not running server.js)"); break;
    case 429: hint = QStringLiteral(" (rate limit, wait a minute)"); break;
    case 502: case 503: case 504:
              hint = QStringLiteral(" (server waking up or Groq unreachable, try again in 60s)"); break;
    default: break;
    }
    if (status == 0)
        return QStringLiteral("No connection: ") + reply->errorString();
    return QStringLiteral("HTTP %1%2: %3")
               .arg(status)
               .arg(hint)
               .arg(body.isEmpty() ? reply->errorString() : body);
}

// Parse the Groq response body and emit the right signal
void AiService::postVision(const QJsonObject &body)
{
    if (!usingProxy() && m_key.trimmed().isEmpty()) {
        m_error = QStringLiteral("Please enter your Groq API key (key button).");
        emit errorChanged();
        return;
    }
    if (!QSslSocket::supportsSsl()) {
        m_error = QStringLiteral("HTTPS unavailable: OpenSSL libs missing from APK (libssl_3.so / libcrypto_3.so).");
        emit errorChanged();
        return;
    }
    m_busy = true; m_error.clear(); emit busyChanged();

    QNetworkRequest req = makeRequest(m_key);

    auto *reply = m_net.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_busy = false; emit busyChanged();
        const QByteArray raw = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            m_error = describeError(reply, raw);
            emit errorChanged();
            reply->deleteLater();
            return;
        }
        const auto doc  = QJsonDocument::fromJson(raw);
        const QString content = doc.object()
            .value(QStringLiteral("choices")).toArray().at(0).toObject()
            .value(QStringLiteral("message")).toObject()
            .value(QStringLiteral("content")).toString();

        if (content.isEmpty()) {
            m_error = QStringLiteral("AI returned no content. Check the API key / proxy settings.");
            emit errorChanged();
        } else {
            // Extract JSON object from content (AI may wrap in markdown fences)
            QString c = content;
            const int a = c.indexOf('{'), z = c.lastIndexOf('}');
            if (a >= 0 && z > a) {
                auto obj = QJsonDocument::fromJson(c.mid(a, z - a + 1).toUtf8()).object();
                emit analysisReady(obj.toVariantMap());
            } else {
                m_error = QStringLiteral("AI did not return valid food JSON. Try again.");
                emit errorChanged();
            }
        }
        reply->deleteLater();
    });
}

void AiService::postChat(const QJsonObject &body)
{
    if (!usingProxy() && m_key.trimmed().isEmpty()) {
        m_error = QStringLiteral("Please enter your Groq API key (key button).");
        emit errorChanged();
        return;
    }
    if (!QSslSocket::supportsSsl()) {
        m_error = QStringLiteral("HTTPS unavailable: OpenSSL libs missing from APK (libssl_3.so / libcrypto_3.so).");
        emit errorChanged();
        return;
    }
    m_busy = true; m_error.clear(); emit busyChanged();

    QNetworkRequest req = makeRequest(m_key);

    auto *reply = m_net.post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_busy = false; emit busyChanged();
        const QByteArray raw = reply->readAll();
        if (reply->error() != QNetworkReply::NoError) {
            m_error = describeError(reply, raw);
            emit errorChanged();
            reply->deleteLater();
            return;
        }
        const auto doc = QJsonDocument::fromJson(raw);
        const QString content = doc.object()
            .value(QStringLiteral("choices")).toArray().at(0).toObject()
            .value(QStringLiteral("message")).toObject()
            .value(QStringLiteral("content")).toString();

        if (content.isEmpty()) {
            m_error = QStringLiteral("AI returned no content.");
            emit errorChanged();
        } else {
            emit textReady(content);
        }
        reply->deleteLater();
    });
}

void AiService::analyzeImage(const QString &filePath)
{
    // Strip file:// prefix if QML passed it with that prefix
    QString path = filePath;
    if (path.startsWith(QStringLiteral("file://")))
        path = QUrl(path).toLocalFile();

    const QString b64 = b64File(path);
    if (b64.isEmpty()) {
        m_error = QStringLiteral("Could not read the photo file.");
        emit errorChanged();
        return;
    }

    const QString today = QDate::currentDate().toString(Qt::ISODate);

    QJsonObject textPart;
    textPart[QStringLiteral("type")] = QStringLiteral("text");
    textPart[QStringLiteral("text")] =
        QStringLiteral("Today is %1. Identify the food in this photo. "
                       "Return ONLY a JSON object with these keys: "
                       "name, category, quantity, expiryDate (YYYY-MM-DD, estimate if not visible), icon (one emoji). "
                       "No markdown, no explanation, just the JSON object.").arg(today);

    QJsonObject imgPart;
    imgPart[QStringLiteral("type")] = QStringLiteral("image_url");
    imgPart[QStringLiteral("image_url")] = QJsonObject{
        { QStringLiteral("url"), QStringLiteral("data:image/jpeg;base64,") + b64 }
    };

    QJsonObject msg;
    msg[QStringLiteral("role")]    = QStringLiteral("user");
    msg[QStringLiteral("content")] = QJsonArray{ textPart, imgPart };

    // Fix #7: use the vision model
    QJsonObject body;
    body[QStringLiteral("model")]       = QLatin1String(kVisionModel);
    body[QStringLiteral("messages")]    = QJsonArray{ msg };
    body[QStringLiteral("temperature")] = 0.1;
    body[QStringLiteral("max_tokens")]  = 300;

    postVision(body);
}

void AiService::generateRecipes(const QString &pantryJson)
{
    QJsonObject msg;
    msg[QStringLiteral("role")]    = QStringLiteral("user");
    msg[QStringLiteral("content")] =
        QStringLiteral("Create 3 practical recipes from these pantry items. "
                       "Prioritise foods expiring soonest. "
                       "Give each recipe a title, a short ingredient list, and numbered steps. "
                       "Pantry (JSON): ") + pantryJson;

    // Fix #7: use the chat model for text-only
    QJsonObject body;
    body[QStringLiteral("model")]       = QLatin1String(kChatModel);
    body[QStringLiteral("messages")]    = QJsonArray{ msg };
    body[QStringLiteral("temperature")] = 0.4;
    body[QStringLiteral("max_tokens")]  = 1200;

    postChat(body);
}

void AiService::chat(const QString &historyJson, const QString &message)
{
    QJsonArray msgs;
    msgs.append(QJsonObject{
        { QStringLiteral("role"),    QStringLiteral("system") },
        { QStringLiteral("content"), QStringLiteral("You are FreshMate, a practical food and pantry assistant. Be concise and helpful.") }
    });

    const auto history = QJsonDocument::fromJson(historyJson.toUtf8()).array();
    for (const auto &v : history) msgs.append(v);

    msgs.append(QJsonObject{
        { QStringLiteral("role"),    QStringLiteral("user") },
        { QStringLiteral("content"), message }
    });

    QJsonObject body;
    body[QStringLiteral("model")]       = QLatin1String(kChatModel);
    body[QStringLiteral("messages")]    = msgs;
    body[QStringLiteral("temperature")] = 0.4;
    body[QStringLiteral("max_tokens")]  = 800;

    postChat(body);
}

