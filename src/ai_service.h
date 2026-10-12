#pragma once
#include <QObject>
#include <QNetworkAccessManager>

class AiService : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString apiKey READ apiKey WRITE setApiKey NOTIFY apiKeyChanged)
    Q_PROPERTY(bool    busy   READ busy                   NOTIFY busyChanged)
    Q_PROPERTY(bool    usingProxy READ usingProxy         CONSTANT)
    Q_PROPERTY(QString error  READ error                  NOTIFY errorChanged)

public:
    explicit AiService(QObject *parent = nullptr);

    QString apiKey() const { return m_key; }
    void    setApiKey(const QString &v);

    bool    usingProxy() const;
    bool    busy()  const { return m_busy; }
    QString error() const { return m_error; }

    // Fix #7: three distinct invokable methods — vision uses a vision model,
    //         text methods use the chat model.
    Q_INVOKABLE void analyzeImage(const QString &filePath);
    Q_INVOKABLE void generateRecipes(const QString &pantryJson);
    Q_INVOKABLE void chat(const QString &historyJson, const QString &message);

signals:
    void apiKeyChanged();
    void busyChanged();
    void errorChanged();
    void analysisReady(const QVariantMap &result);
    void textReady(const QString &text);

private:
    void postVision(const QJsonObject &body);
    void postChat(const QJsonObject &body);

    QNetworkAccessManager m_net;
    QString m_key;
    bool    m_busy  = false;
    QString m_error;
    QString m_mode;
};
