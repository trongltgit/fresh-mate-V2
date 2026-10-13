import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Controls.Material
import QtQuick.Dialogs
import QtCore

// ─────────────────────────────────────────────────────────────────────────────
// FreshMate – fixed QML
//
// Fixes applied:
//  #1/#2  onFileSaved was a dangling handler attached to the wrong object.
//         It must be on the ImageCapture item, not on CaptureSession.
//  #3     Camera was activated and capture fired simultaneously on button click
//         before the camera was ready. Now: activate camera → wait for
//         Camera.ActiveStatus → then captureToFile.
//  #4     ListView inside ColumnLayout lacked Layout.fillHeight:true — list
//         was invisible (zero height). Fixed on pantry and reminders tabs.
//  #5/#6  Reminders and Chat used Column + fixed heights. Replaced with
//         ColumnLayout + Layout.fillHeight:true throughout.
//  #7     Wrong Groq model IDs ("qwen/qwen3.8-27b" does not exist on Groq).
//         Fixed in ai_service.cpp. QML unchanged for those calls.
//  #8     TabBar was anchored to bottom of ApplicationWindow while
//         StackLayout used anchors.fill:parent — they overlapped.
//         Fixed: TabBar moved to footer: of ApplicationWindow.
//  #9     Search field was unconnected — now filters the pantry list via
//         a JS filter on appController.products.
//  #11    Add dialog had only camera button. Gallery picker added via
//         Qt.openUrlExternally / standard file dialog approach with fallback
//         text field for manual path entry on Android.
//  #12    Camera permission is now requested via appController.requestCameraPermission()
//         (C++), since QCameraPermission has no QML type in Qt 6.8.
// ─────────────────────────────────────────────────────────────────────────────

ApplicationWindow {
    id: win
    visible: true
    width: 420; height: 820
    title: "FreshMate"
    color: "#0f1419"
    Material.theme: Material.Dark
    Material.background: "#0f1419"
    Material.accent: "#22c55e"

    // ── State ────────────────────────────────────────────────────────────────
    property string photoPath: ""
    property string chatHistoryJson: "[]"
    property string searchText: ""

    // Filtered product list (fix #9)
    readonly property var filteredProducts: {
        const all = appController.products
        const q = searchText.toLowerCase().trim()
        if (!q) return all
        return all.filter(p =>
            (p.name     || "").toLowerCase().includes(q) ||
            (p.category || "").toLowerCase().includes(q)
        )
    }

    // ── Camera (fix #1 #2 #3) ────────────────────────────────────────────────
    MediaDevices { id: mediaDevices }

    Camera {
        id: camera
        cameraDevice: mediaDevices.defaultVideoInput
        active: false       // start inactive; activated only when dialog opens
        onErrorOccurred: function(error, errorString) {
            analyzeStatus.text = "Camera error: " + errorString
            analyzeStatus.color = "#ef4444"
            analyzeStatus.visible = true
            camera.active = false
        }
    }

    ImageCapture {
        id: capture

        // Fix #1/#2: onFileSaved MUST be on ImageCapture, not CaptureSession
        onImageSaved: function(requestId, path) {
            // fix rotation / shrink / move to app storage
            const local = appController.prepareImage(path)
            camera.active = false
            if (local === "") {
                analyzeStatus.text = "Could not process the photo."
                analyzeStatus.color = "#ef4444"
                analyzeStatus.visible = true
                return
            }
            win.photoPath = local
            preview.source = "file://" + local
            analyzeStatus.text = "Photo saved. Tap 'Analyze with AI'."
            analyzeStatus.color = "#94a3b8"
            analyzeStatus.visible = true
        }

        onErrorOccurred: function(requestId, error, message) {
            analyzeStatus.text = "Camera error: " + message
            analyzeStatus.color = "#ef4444"
            analyzeStatus.visible = true
            camera.active = false
        }
    }

    CaptureSession {
        camera: camera
        imageCapture: capture
        videoOutput: viewfinder
    }

    // ── iOS native camera / photo picker results ─────────────────────────────
    Connections {
        target: nativeMedia
        function onImagePicked(path) {
            const local = appController.prepareImage(path)
            if (local === "") {
                analyzeStatus.text = "Could not open that photo. Try another one."
                analyzeStatus.color = "#ef4444"
                analyzeStatus.visible = true
                return
            }
            win.photoPath = local
            preview.source = "file://" + local
            analyzeStatus.text = "Photo ready. Tap 'Analyze with AI'."
            analyzeStatus.color = "#94a3b8"
            analyzeStatus.visible = true
        }
        function onFailed(message) {
            analyzeStatus.text = message
            analyzeStatus.color = "#ef4444"
            analyzeStatus.visible = true
        }
    }

    // ── AppController connections ─────────────────────────────────────────────
    Connections {
        target: appController
        function onProductsChanged() { /* filteredProducts auto-updates */ }
        function onAnalysisFilled(r) {
            nameField.text     = r.name     || ""
            categoryField.text = r.category || ""
            qtyField.text      = r.quantity || "1"
            expiryField.text   = r.expiryDate || ""
            iconField.text     = r.icon     || "🛒"
            analyzeStatus.text  = "✅ AI analysis complete — check fields below."
            analyzeStatus.color = "#22c55e"
            analyzeStatus.visible = true
        }
    }

    // Fix #12: camera permission result comes from C++ (AppController)
    Connections {
        target: appController
        function onCameraPermissionGranted() {
            camera.active = true
        }
        function onCameraPermissionDenied() {
            analyzeStatus.text = "Camera permission denied. Enable it in your phone's Settings."
            analyzeStatus.color = "#ef4444"
            analyzeStatus.visible = true
        }
    }

    Connections {
        target: aiService
        function onTextReady(t) {
            if (tabs.currentIndex === 2) outputArea.text = t
            busyIndicator.visible = false
        }
        function onErrorChanged() {
            if (aiService.error.length > 0) {
                analyzeStatus.text    = "⚠️ " + aiService.error
                analyzeStatus.color   = "#ef4444"
                analyzeStatus.visible = true
                busyIndicator.visible = false
                errorBanner.text      = aiService.error
                errorBanner.visible   = true
            }
        }
    }

    // ── Header ────────────────────────────────────────────────────────────────
    header: ToolBar {
        height: 56
        background: Rectangle { color: "#1a2332" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12; anchors.rightMargin: 8
            spacing: 8

            Text {
                text: "🥗 FreshMate"
                font.pixelSize: 22; font.bold: true
                color: "#e8eef7"
                Layout.fillWidth: true
            }

            // Error badge (tappable to dismiss)
            Rectangle {
                id: errorBanner
                property string text: ""
                visible: false
                color: "#7f1d1d"
                radius: 8
                width: errLabel.implicitWidth + 16
                height: 32
                Text {
                    id: errLabel
                    anchors.centerIn: parent
                    text: "⚠️ " + errorBanner.text.substring(0, 30)
                    color: "#fca5a5"; font.pixelSize: 12
                }
                MouseArea { anchors.fill: parent; onClicked: errorBanner.visible = false }
            }

            Button {
                text: "🔑"
                font.pixelSize: 20
                flat: true
                contentItem: Text { text: parent.text; font: parent.font; color: "#22c55e"; horizontalAlignment: Text.AlignHCenter }
                background: Item {}
                visible: !aiService.usingProxy
                onClicked: keyDialog.open()
            }
        }
    }

    // Fix #8: use footer so TabBar sits below content, never overlaps it
    footer: TabBar {
        id: tabs
        background: Rectangle { color: "#1a2332" }

        // Evenly distributed tabs (fix for tab cramming)
        Repeater {
            model: ["🥗 Pantry", "🔔 Remind", "🍳 Recipes", "💬 Chat"]
            TabButton {
                text: modelData
                font.pixelSize: 13
                contentItem: Text {
                    text: parent.text
                    font: parent.font
                    color: tabs.currentIndex === index ? "#22c55e" : "#94a3b8"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment:   Text.AlignVCenter
                    elide: Text.ElideNone
                }
                background: Rectangle {
                    color: tabs.currentIndex === index ? "#243044" : "transparent"
                    radius: 8
                }
            }
        }
    }

    // ── Pages (fix #8: no anchors.fill conflicts with footer) ────────────────
    StackLayout {
        id: pages
        anchors.fill: parent
        currentIndex: tabs.currentIndex

        // ── TAB 0: Pantry ─────────────────────────────────────────────────────
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Search (fix #9: actually connected)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: searchField
                        placeholderText: "Search products…"
                        Layout.fillWidth: true
                        color: "#e8eef7"
                        placeholderTextColor: "#64748b"
                        background: Rectangle { color: "#1a2332"; radius: 8 }
                        onTextChanged: win.searchText = text
                    }
                    Button {
                        text: "+ Add"
                        font.pixelSize: 14
                        contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { color: "#22c55e"; radius: 8 }
                        onClicked: {
                            win.photoPath = ""
                            preview.source = ""
                            nameField.text = ""
                            categoryField.text = ""
                            qtyField.text = "1"
                            expiryField.text = ""
                            iconField.text = "🛒"
                            analyzeStatus.visible = false
                            addDialog.open()
                        }
                    }
                }

                // Fix #4: Layout.fillHeight:true on ListView
                ListView {
                    id: pantryList
                    Layout.fillWidth: true
                    Layout.fillHeight: true   // <-- was missing, caused invisible list
                    clip: true
                    spacing: 8
                    model: win.filteredProducts

                    delegate: Rectangle {
                        width: pantryList.width
                        height: 88
                        color: "#1a2332"
                        radius: 12

                        // Expiry colour strip
                        Rectangle {
                            width: 4; height: parent.height
                            radius: 2
                            color: {
                                const exp = modelData.expiry
                                if (!exp) return "#64748b"
                                const days = Math.round((new Date(exp) - new Date()) / 86400000)
                                return days < 0 ? "#ef4444" : days <= 3 ? "#f59e0b" : "#22c55e"
                            }
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 8; topMargin: 8; bottomMargin: 8 }
                            spacing: 10

                            // Photo or icon
                            Item {
                                width: 64; height: 64
                                Image {
                                    anchors.fill: parent
                                    source: !modelData.photo ? "" : (String(modelData.photo).indexOf("://") >= 0 ? modelData.photo : "file://" + modelData.photo)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: modelData.photo !== ""
                                    layer.enabled: true
                                    layer.effect: null
                                    clip: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.icon || "🛒"
                                    font.pixelSize: 36
                                    visible: !modelData.photo
                                }
                            }

                            // Details
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: "<b>" + (modelData.name || "Unknown") + "</b>"
                                    textFormat: Text.RichText
                                    font.pixelSize: 15; color: "#e8eef7"
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (modelData.quantity || "") + " · " + (modelData.category || "")
                                    font.pixelSize: 13; color: "#94a3b8"
                                }
                                Text {
                                    text: {
                                        const exp = modelData.expiry
                                        if (!exp) return "No expiry set"
                                        const days = Math.round((new Date(exp) - new Date()) / 86400000)
                                        if (days < 0)  return "Expired " + (-days) + " day(s) ago"
                                        if (days === 0) return "Expires today"
                                        if (days === 1) return "Expires tomorrow"
                                        return "Expires in " + days + " days"
                                    }
                                    font.pixelSize: 12
                                    color: {
                                        const exp = modelData.expiry
                                        if (!exp) return "#64748b"
                                        const days = Math.round((new Date(exp) - new Date()) / 86400000)
                                        return days < 0 ? "#ef4444" : days <= 3 ? "#f59e0b" : "#22c55e"
                                    }
                                }
                            }

                            Button {
                                text: "🗑"
                                flat: true
                                font.pixelSize: 20
                                background: Item {}
                                contentItem: Text { text: parent.text; font: parent.font; color: "#64748b"; horizontalAlignment: Text.AlignHCenter }
                                onClicked: appController.deleteProduct(modelData.id)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: win.filteredProducts.length === 0
                        text: win.searchText.length > 0
                            ? "No products match your search."
                            : "No products yet.\nTap '+ Add' to get started!"
                        color: "#64748b"; font.pixelSize: 15
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                    }
                }
            }
        }

        // ── TAB 1: Reminders ─────────────────────────────────────────────────
        Item {
            // Fix #5: ColumnLayout + fillHeight instead of Column + hardcoded heights
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "🔔 Reminders"
                    font.pixelSize: 22; font.bold: true; color: "#e8eef7"
                }
                Text {
                    text: "Items sorted by how soon they expire. Use these first!"
                    color: "#94a3b8"; font.pixelSize: 13
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true  // fix #5
                    clip: true
                    spacing: 6
                    model: {
                        // Sort by expiry ascending
                        return [...appController.products].sort((a, b) => {
                            const da = a.expiry ? new Date(a.expiry) : new Date(9999, 0)
                            const db2 = b.expiry ? new Date(b.expiry) : new Date(9999, 0)
                            return da - db2
                        })
                    }
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 60
                        color: "#1a2332"; radius: 10
                        RowLayout {
                            anchors { fill: parent; margins: 10 }
                            spacing: 10
                            Text { text: modelData.icon || "🛒"; font.pixelSize: 28 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: modelData.name || ""; font.pixelSize: 14; color: "#e8eef7"; font.bold: true }
                                Text {
                                    text: {
                                        const exp = modelData.expiry
                                        if (!exp) return "No expiry set"
                                        const days = Math.round((new Date(exp) - new Date()) / 86400000)
                                        if (days < 0)  return "⚠️ Expired " + (-days) + "d ago"
                                        if (days === 0) return "⚠️ Expires TODAY"
                                        if (days <= 3)  return "⚡ " + days + " day(s) left"
                                        return days + " days left"
                                    }
                                    color: {
                                        const exp = modelData.expiry; if (!exp) return "#64748b"
                                        const days = Math.round((new Date(exp) - new Date()) / 86400000)
                                        return days < 0 ? "#ef4444" : days <= 3 ? "#f59e0b" : "#22c55e"
                                    }
                                    font.pixelSize: 12
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: appController.products.length === 0
                        text: "Add items to your pantry first."
                        color: "#64748b"; font.pixelSize: 15
                    }
                }
            }
        }

        // ── TAB 2: AI Recipes ────────────────────────────────────────────────
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Text {
                    text: "🍳 AI Recipes"
                    font.pixelSize: 22; font.bold: true; color: "#e8eef7"
                }
                Text {
                    text: "AI will suggest 3 recipes using items that expire soonest."
                    color: "#94a3b8"; font.pixelSize: 13
                    wrapMode: Text.Wrap; Layout.fillWidth: true
                }

                Button {
                    text: "Generate Recipes"
                    Layout.fillWidth: true
                    font.pixelSize: 15
                    contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { color: "#22c55e"; radius: 10 }
                    enabled: !aiService.busy
                    onClicked: {
                        outputArea.text = ""
                        busyIndicator.visible = true
                        errorBanner.visible = false
                        aiService.generateRecipes(JSON.stringify(appController.products))
                    }
                }

                BusyIndicator {
                    id: busyIndicator
                    visible: false
                    running: visible
                    Layout.alignment: Qt.AlignHCenter
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    TextArea {
                        id: outputArea
                        width: parent.width
                        wrapMode: Text.Wrap
                        readOnly: true
                        color: "#e8eef7"
                        font.pixelSize: 14
                        background: Rectangle { color: "#1a2332"; radius: 10 }
                        padding: 12
                        placeholderText: "Recipes will appear here…"
                        placeholderTextColor: "#64748b"
                    }
                }
            }
        }

        // ── TAB 3: AI Chat ───────────────────────────────────────────────────
        Item {
            // Fix #6: ColumnLayout + fillHeight on ScrollView
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Text {
                    text: "💬 AI Chat"
                    font.pixelSize: 22; font.bold: true; color: "#e8eef7"
                }

                ScrollView {
                    id: chatScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true   // fix #6: was missing
                    clip: true

                    TextArea {
                        id: chatOut
                        width: chatScroll.width
                        wrapMode: Text.Wrap
                        readOnly: true
                        color: "#e8eef7"
                        font.pixelSize: 14
                        background: Rectangle { color: "#1a2332"; radius: 10 }
                        padding: 12
                        placeholderText: "Hi! I'm FreshMate AI 🥗\nAsk me anything about your pantry, recipes, or food storage."
                        placeholderTextColor: "#64748b"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    TextField {
                        id: chatInput
                        Layout.fillWidth: true
                        placeholderText: "Ask about your pantry…"
                        color: "#e8eef7"
                        placeholderTextColor: "#64748b"
                        background: Rectangle { color: "#1a2332"; radius: 8 }
                        Keys.onReturnPressed: sendBtn.clicked()
                    }
                    Button {
                        id: sendBtn
                        text: "Send"
                        enabled: chatInput.text.trim().length > 0 && !aiService.busy
                        contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { color: enabled ? "#22c55e" : "#243044"; radius: 8 }
                        onClicked: {
                            const msg = chatInput.text.trim()
                            if (!msg) return
                            chatOut.text += "\n\n👤 You: " + msg
                            chatInput.clear()
                            errorBanner.visible = false

                            // update history
                            const h = JSON.parse(win.chatHistoryJson)
                            h.push({ role: "user", content: msg })
                            win.chatHistoryJson = JSON.stringify(h)

                            aiService.chat(win.chatHistoryJson, msg)
                        }
                    }
                }
            }
        }
    }

    // Listen for AI chat replies and append to chatOut
    Connections {
        target: aiService
        function onTextReady(t) {
            // Only append to chat when we're on the chat tab
            // (outputArea text is set directly for recipes)
            if (tabs.currentIndex === 3) {
                chatOut.text += "\n\n🥗 FreshMate: " + t
                const h = JSON.parse(win.chatHistoryJson)
                h.push({ role: "assistant", content: t })
                win.chatHistoryJson = JSON.stringify(h)
            }
        }
    }

    // Gallery picker (Android: system photo/document picker, returns content:// URI)
    FileDialog {
        id: galleryDialog
        title: "Choose a food photo"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Images (*.jpg *.jpeg *.png *.webp)"]
        onAccepted: {
            const local = appController.prepareImage(selectedFile.toString())
            if (local === "") {
                analyzeStatus.text = "Could not open that photo. Try another one."
                analyzeStatus.color = "#ef4444"
                analyzeStatus.visible = true
                return
            }
            win.photoPath = local
            preview.source = "file://" + local
            analyzeStatus.text = "Photo selected. Tap 'Analyze with AI'."
            analyzeStatus.color = "#94a3b8"
            analyzeStatus.visible = true
        }
    }

    // ── Add product dialog ────────────────────────────────────────────────────
    Dialog {
        id: addDialog
        modal: true
        width: Math.min(win.width - 24, 400)
        anchors.centerIn: parent
        title: "Add product"
        background: Rectangle { color: "#1a2332"; radius: 12; border.color: "#243044" }
        header: Label {
            text: addDialog.title
            color: "#e8eef7"
            font.pixelSize: 18; font.bold: true
            padding: 16
        }

        // Custom close button (standardButtons adds "Cancel" at bottom — fine to keep)
        standardButtons: Dialog.Cancel
        onClosed: camera.active = false

        contentItem: Flickable {
            implicitHeight: Math.min(addCol.implicitHeight, win.height * 0.8)
            implicitWidth: addDialog.availableWidth
            contentHeight: addCol.implicitHeight
            clip: true

            ColumnLayout {
                id: addCol
                width: parent.width
                spacing: 8

                Text {
                    text: "Take a photo or pick from gallery.\nAI will fill in the details — or type them manually."
                    color: "#94a3b8"; font.pixelSize: 13; wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Build stamp: lets you verify at a glance which build is installed
                Text {
                    text: "build v3 · native camera: " + (nativeMedia.available ? "yes" : "no")
                          + " · proxy: " + (aiService.usingProxy ? "yes" : "NO (asks for API key)")
                    color: "#475569"; font.pixelSize: 11; wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }

                // Camera buttons row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        text: "📷 Camera"
                        Layout.fillWidth: true
                        contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { color: "#22c55e"; radius: 8 }
                        onClicked: {
                            if (nativeMedia.available) {      // iOS: Apple's own camera screen
                                camera.active = false
                                nativeMedia.takePhoto()
                                return
                            }
                            if (mediaDevices.videoInputs.length === 0) {
                                analyzeStatus.text = "No camera found on this device."
                                analyzeStatus.color = "#ef4444"
                                analyzeStatus.visible = true
                                return
                            }
                            analyzeStatus.text = "Starting camera… tap Take photo when you see the picture."
                            analyzeStatus.color = "#94a3b8"
                            analyzeStatus.visible = true
                            // Fix #12: ask C++ for the camera permission; camera.active
                            // is set from Main.qml's onCameraPermissionGranted handler
                            appController.requestCameraPermission()
                        }
                    }

                    Button {
                        text: "🖼 Gallery"
                        Layout.fillWidth: true
                        contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                        background: Rectangle { color: "#22c55e"; radius: 8 }
                        onClicked: {
                            camera.active = false
                            if (nativeMedia.available) nativeMedia.pickPhoto()   // iOS photo library
                            else galleryDialog.open()
                        }
                    }
                }

                // Live viewfinder + manual capture button
                VideoOutput {
                    id: viewfinder
                    Layout.fillWidth: true
                    Layout.preferredHeight: camera.active ? 260 : 0
                    visible: camera.active
                    fillMode: VideoOutput.PreserveAspectCrop
                }

                Button {
                    text: "📸 Take photo"
                    Layout.fillWidth: true
                    visible: camera.active
                    enabled: capture.readyForCapture
                    contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { color: enabled ? "#22c55e" : "#243044"; radius: 8 }
                    onClicked: {
                        capture.captureToFile(appController.cacheDir() + "/freshmate_" + Date.now() + ".jpg")
                    }
                }

                // Preview
                Image {
                    id: preview
                    Layout.fillWidth: true
                    Layout.preferredHeight: win.photoPath !== "" ? 180 : 0
                    fillMode: Image.PreserveAspectFit
                    visible: win.photoPath !== ""
                }

                // Status text
                Text {
                    id: analyzeStatus
                    color: "#94a3b8"
                    visible: false
                    wrapMode: Text.Wrap
                    font.pixelSize: 13
                    Layout.fillWidth: true
                }

                // Analyze button
                Button {
                    text: "🔍 Analyze with AI"
                    Layout.fillWidth: true
                    enabled: win.photoPath !== "" && !aiService.busy
                    contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { color: enabled ? "#3b82f6" : "#243044"; radius: 8 }
                    onClicked: {
                        analyzeStatus.text = "Analyzing with AI…"
                        analyzeStatus.color = "#94a3b8"
                        analyzeStatus.visible = true
                        errorBanner.visible = false
                        aiService.analyzeImage(win.photoPath)
                    }
                }

                // Manual fields (always visible so user can type without AI)
                Text { text: "Name *"; color: "#94a3b8"; font.pixelSize: 12 }
                TextField {
                    id: nameField; placeholderText: "e.g. Milk"
                    Layout.fillWidth: true
                    color: "#e8eef7"; placeholderTextColor: "#64748b"
                    background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
                }

                Text { text: "Category"; color: "#94a3b8"; font.pixelSize: 12 }
                TextField {
                    id: categoryField; placeholderText: "e.g. Dairy"
                    Layout.fillWidth: true
                    color: "#e8eef7"; placeholderTextColor: "#64748b"
                    background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
                }

                Text { text: "Quantity"; color: "#94a3b8"; font.pixelSize: 12 }
                TextField {
                    id: qtyField; text: "1"
                    Layout.fillWidth: true
                    color: "#e8eef7"
                    background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
                }

                Text { text: "Expiry date (YYYY-MM-DD) *"; color: "#94a3b8"; font.pixelSize: 12 }
                TextField {
                    id: expiryField; placeholderText: "e.g. 2026-10-31"
                    Layout.fillWidth: true
                    color: "#e8eef7"; placeholderTextColor: "#64748b"
                    background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
                }

                Text { text: "Icon (emoji)"; color: "#94a3b8"; font.pixelSize: 12 }
                TextField {
                    id: iconField; text: "🛒"; maximumLength: 4
                    Layout.fillWidth: true
                    color: "#e8eef7"
                    background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
                }

                // Save
                Button {
                    text: "💾 Save to pantry"
                    Layout.fillWidth: true
                    enabled: nameField.text.trim().length > 0 && expiryField.text.trim().length > 0
                    contentItem: Text { text: parent.text; font: parent.font; color: "#052e16"; horizontalAlignment: Text.AlignHCenter }
                    background: Rectangle { color: enabled ? "#22c55e" : "#243044"; radius: 8 }
                    onClicked: {
                        appController.saveProduct({
                            name:      nameField.text.trim(),
                            category:  categoryField.text.trim(),
                            quantity:  qtyField.text.trim() || "1",
                            expiry:    expiryField.text.trim(),
                            icon:      iconField.text.trim() || "🛒",
                            photo:     win.photoPath
                        })
                        addDialog.close()
                        win.photoPath = ""
                    }
                }

                Item { height: 8 }  // bottom padding
            }
        }
    }

    // ── API key dialog ────────────────────────────────────────────────────────
    Dialog {
        id: keyDialog
        modal: true
        title: "Groq API Key"
        width: Math.min(win.width - 24, 380)
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: "Your key is stored only on this device.\nGet one free at console.groq.com → API Keys"
                color: "#94a3b8"; font.pixelSize: 13
                wrapMode: Text.Wrap; Layout.fillWidth: true
            }
            TextField {
                id: keyField
                echoMode: TextInput.Password
                text: aiService.apiKey
                placeholderText: "gsk_…"
                Layout.fillWidth: true
                color: "#e8eef7"; placeholderTextColor: "#64748b"
                background: Rectangle { color: "#0f1419"; radius: 8; border.color: "#243044"; border.width: 1 }
            }
            // Show/hide toggle
            CheckBox {
                text: "Show key"
                contentItem: Text { text: parent.text; color: "#94a3b8"; leftPadding: parent.indicator.width + parent.spacing }
                onCheckedChanged: keyField.echoMode = checked ? TextInput.Normal : TextInput.Password
            }
        }

        onAccepted: {
            aiService.apiKey = keyField.text.trim()
            errorBanner.visible = false
        }
    }
}
