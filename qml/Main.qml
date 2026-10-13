import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 390
    height: 844
    title: qsTr("FreshMate")

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        anchors.margins: 15

        // Area hiển thị danh sách tin nhắn Chat
        ListView {
            id: chatView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: chatModel
            delegate: ItemDelegate {
                width: chatView.width
                text: model.sender + ": " + model.text
            }
        }

        // Ô nhập tin nhắn và nút Gửi
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            TextField {
                id: messageInput
                Layout.fillWidth: true
                placeholderText: "Hỏi FreshMate..."
                onAccepted: sendButton.clicked()
            }

            Button {
                id: sendButton
                text: "Gửi"
                onClicked: {
                    if (messageInput.text.trim() !== "") {
                        var text = messageInput.text;
                        chatModel.append({"sender": "Tôi", "text": text});
                        
                        // Bỏ qua bước kiểm tra API Key -> Thực thi gọi thẳng AI Service
                        aiService.sendMessage(text);
                        
                        messageInput.text = "";
                    }
                }
            }
        }
    }

    ListModel {
        id: chatModel
    }

    // Nhận phản hồi từ AI Service C++
    Connections {
        target: aiService
        function onMessageReceived(reply) {
            chatModel.append({"sender": "FreshMate", "text": reply});
        }
        function onErrorOccurred(errorMsg) {
            chatModel.append({"sender": "Hệ thống", "text": errorMsg});
        }
    }
}