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
    // Gán trực tiếp URL Render của bạn tại đây để tránh mọi lỗi vĩ lệnh (macro) của Xcode
    QUrl proxyUrl("https://fresh-mate-v2.onrender.com/ai");
    
    QNetworkRequest request(proxyUrl);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");

    // Đóng gói JSON payload chuẩn theo định dạng proxy yêu cầu
    QJsonObject payload;
    payload["model"] = "openai/gpt-oss-20b"; // Khớp với ALLOWED_MODELS trên server Node.js

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