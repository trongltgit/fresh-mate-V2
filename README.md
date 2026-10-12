# FreshMate — Native C++ / Qt 6 for Android (Fixed)

## What was broken and what was fixed

| # | File | Bug | Fix |
|---|------|-----|-----|
| 1 | Main.qml | `onFileSaved` was a dangling handler attached to `CaptureSession`, not `ImageCapture` — photos were never received | Moved `onFileSaved` / `onErrorOccurred` onto the `ImageCapture` item |
| 2 | Main.qml | `CaptureSession` was missing `imageCapture: capture` binding | Added the binding |
| 3 | Main.qml | `capture.captureToFile()` fired immediately on button click before `camera.active` warmed up — crash/blank photo | Camera activates first; a 800 ms `Timer` fires the capture after the sensor is ready |
| 4 | Main.qml | `ListView` inside `ColumnLayout` lacked `Layout.fillHeight: true` — list was invisible (zero height) | Added `Layout.fillHeight: true` on all ListViews |
| 5 | Main.qml | Reminders tab used `Column` + hard-coded pixel heights — content overflowed the TabBar | Replaced with `ColumnLayout` + `Layout.fillHeight` |
| 6 | Main.qml | Chat tab's `ScrollView` had no height — chatOut showed 0 px | Same fix: `ColumnLayout` + `Layout.fillHeight: true` on `ScrollView` |
| 7 | ai_service.cpp | Wrong Groq model IDs (`qwen/qwen3.8-27b` doesn't exist) — every AI call failed with 404 | Vision: `meta-llama/llama-4-scout-17b-16e-instruct`; Chat: `llama-3.3-70b-versatile` |
| 8 | Main.qml | `StackLayout` used `anchors.fill: parent` while `TabBar` anchored to bottom of the same window — they overlapped | Moved `TabBar` to `footer:` of `ApplicationWindow` |
| 9 | Main.qml | Search field was connected to nothing — typing did not filter the list | Added `filteredProducts` computed property; `ListView.model` bound to it |
| 10 | pantry_db.cpp | `ensure()` was marked `const` but called `db.open()` — UB / silent failures on repeated calls | Removed `const`; `all()` checks `db.isOpen()` directly |
| 11 | Main.qml | Add dialog had only camera; no gallery fallback | Camera button + warm-up timer; manual text fields always visible |
| 12 | CMakeLists.txt | No `QT_ANDROID_ABIS` — Qt tried to build all 4 ABIs by default (hours) | Set to `arm64-v8a` only |

---

## Requirements

| Tool | Version |
|------|---------|
| Qt | **6.8** with Android, Qt Multimedia, Qt Quick, Qt SQL, Qt Network |
| Qt Creator | 14+ (bundled with Qt 6.8 installer) |
| JDK | **17** (set in Qt Creator → Devices → Android → JDK path) |
| Android SDK Platform | **36** |
| Android Build Tools | **36.0.0** |
| Android NDK | **26.1.10909125** |
| Android Studio | Latest (used only for SDK Manager; build is done in Qt Creator) |

---

## Step-by-step: what to do next

### 1. Install Qt 6.8 for Android
- Go to **https://www.qt.io/download-qt-installer** and download the online installer.
- In the installer, under **Qt 6.8.x**, select:
  - ✅ Android
  - ✅ Qt Multimedia
  - ✅ Qt Network
  - ✅ Qt SQL
  - ✅ Qt Quick / Qt Quick Controls 2
- Finish the install.

### 2. Install Android Studio + SDK tools
- Download Android Studio from **https://developer.android.com/studio**.
- Open it, go to **SDK Manager** (top-right cog icon → SDK Manager) and install:
  - Android SDK Platform **36**
  - Android SDK Build-Tools **36.0.0**
  - NDK **26.1.10909125** (check "Show Package Details" to find this exact version)
  - Command-line Tools (needed by Qt)
- Note down the SDK path (e.g. `C:/Users/you/AppData/Local/Android/Sdk`).

### 3. Configure Qt Creator for Android
- Open Qt Creator → **Edit → Preferences → Devices → Android**.
- Set:
  - **JDK path**: point to your JDK 17 folder
  - **Android SDK path**: your SDK folder from step 2
  - **NDK path**: inside the SDK, usually `ndk/26.1.10909125`
- Click **Apply**. Qt Creator will validate automatically.

### 4. Open the project
- In Qt Creator, **File → Open File or Project**, select `CMakeLists.txt` from this folder.
- Qt Creator will ask you to configure. Select the kit named **Qt 6.8.x Android arm64-v8a**.
- Click **Configure Project**.

### 5. Connect your phone
- On your Android phone: **Settings → About phone → tap Build number 7 times** → enable Developer Options.
- In Developer Options: enable **USB Debugging**.
- Plug the phone into your computer with a USB cable.
- Accept the "Allow USB debugging?" prompt on the phone.
- In Qt Creator, the device dropdown (top-left) should show your phone's name.

### 6. Enter your Groq API key
- Run the app (green ▶ button in Qt Creator).
- Tap the **🔑** button in the top-right corner.
- Paste your Groq API key (get one free at https://console.groq.com → API Keys).
- Tap **OK**. The key is saved on-device.

### 7. Test the full flow
1. Tap **+ Add** in the Pantry tab.
2. Tap **📷 Camera** — your phone camera opens and takes a photo automatically after ~0.8 s.
3. The photo preview appears. Tap **🔍 Analyze with AI**.
4. Fields fill in automatically. Adjust if needed.
5. Tap **💾 Save to pantry** — item appears in the list.
6. Go to **Recipes** tab → **Generate Recipes** to get AI recipe ideas.
7. Go to **Chat** tab and ask anything about your pantry.

### 8. Build a release APK (optional, for sideloading)
- In Qt Creator: **Projects → Android (Build) → Build Steps → Build Android APK**.
- Set `Build type` to **Release**.
- Configure a signing key (or skip for unsigned debug APK).
- Click **Build**.
- The APK will be in `build-android/android-build/build/outputs/apk/`.
