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
    // 1. Sử dụng URL lấy từ file proxy_config.h
    QUrl proxyUrl(FRESHMATE_PROXY_URL);
    
    QNetworkRequest request(proxyUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // 2. Thêm token xác thực nếu có cấu hình trong proxy_config.h
    QString appToken = FRESHMATE_APP_TOKEN;
    if (!appToken.isEmpty()) {
        request.setRawHeader("x-app-token", appToken.toUtf8());
    }

    // 3. Đóng gói dữ liệu JSON gửi lên Proxy (khớp với allowed models trên server)
    QJsonObject payload;
    payload["model"] = "openai/gpt-oss-20b"; // Hoặc qwen/qwen3.8-27b

    QJsonArray messagesArray;
    QJsonObject messageObj;
    messageObj["role"] = "user";
    messageObj["content"] = userMessage;
    messagesArray.append(messageObj);

    payload["messages"] = messagesArray;

    QJsonDocument doc(payload);
    
    // 4. Thực thi gửi request
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