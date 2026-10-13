#include "ai_service.h"
#include "proxy_config.h"
#include <QNetworkRequest>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>

AIService::AIService(QObject *parent) : QObject(parent) {
    m_networkManager = new QNetworkAccessManager(this);
}

void AIService::sendMessage(const QString &userMessage) {
    // Sử dụng trực tiếp chuỗi URL từ file proxy_config.h để tránh lỗi biên dịch vĩ lệnh (macro expansion)
    QString urlStr = QString(FRESHMATE_PROXY_URL);
    QUrl proxyUrl(urlStr);
    
    QNetworkRequest request(proxyUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // Thêm token bảo mật nếu có
    QString appToken = QString(FRESHMATE_APP_TOKEN);
    if (!appToken.isEmpty()) {
        request.setRawHeader("x-app-token", appToken.toUtf8());
    }

    // Đóng gói JSON payload
    QJsonObject payload;
    payload["model"] = "openai/gpt-oss-20b"; // Hoặc model tương ứng trên proxy

    QJsonArray messagesArray;
    QJsonObject messageObj;
    messageObj["role"] = "user";
    messageObj["content"] = userMessage;
    messagesArray.append(messageObj);

    payload["messages"] = messagesArray;

    QJsonDocument doc(payload);
    
    // Gửi request POST tới Render Proxy
    QNetworkReply *reply = m_networkManager->post(request, doc.toJson());

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        if (reply->error() == QNetworkReply::NoError) {
            QByteArray responseData = reply->readAll();
            QJsonDocument jsonResponse = QJsonDocument::fromJson(responseData);
            QJsonObject obj = jsonResponse.object();

            if (obj.contains("choices") && obj["choices"].toArray().size() > 0) {
                QString replyText = obj["choices"].toArray()[0].toObject()["message"].toObject()["content"].toString();
                emit messageReceived(replyText);
            } else if (obj.contains("error")) {
                emit errorOccurred("Proxy Lỗi: " + obj["error"].toString());
            }
        } else {
            qDebug() << "Lỗi kết nối:" << reply->errorString();
            emit errorOccurred("Không thể kết nối đến máy chủ Proxy.");
        }
        reply->deleteLater();
    });
}