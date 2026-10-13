#include "ai_service.h"
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
    // 1. URL chính thức dịch vụ Render Proxy của bạn
    QUrl proxyUrl("https://freshmate-proxy.onrender.com"); // Thay URL Render của bạn vào đây
    
    QNetworkRequest request(proxyUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // 2. Thêm token xác thực nếu trên Render bạn cấu hình APP_TOKEN (có thể bỏ dòng này nếu không dùng APP_TOKEN)
    // request.setRawHeader("x-app-token", "your_app_token_here");

    // 3. Đóng gói dữ liệu JSON gửi lên Proxy
    QJsonObject payload;
    payload["model"] = "qwen/qwen3.8-27b"; // Hoặc model được cho phép trong file server.js

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