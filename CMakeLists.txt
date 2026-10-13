cmake_minimum_required(VERSION 3.21)
project(FreshMate VERSION 2.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(IOS)
    enable_language(OBJCXX)
    set(CMAKE_OBJCXX_STANDARD 17)
endif()
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS
    Core Gui Quick QuickControls2 Network Multimedia Sql)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(FreshMate
    src/main.cpp
    src/appcontroller.cpp  src/appcontroller.h
    src/ai_service.cpp     src/ai_service.h
    src/pantry_db.cpp      src/pantry_db.h
    src/nativemedia.h
)

if(IOS)
    target_sources(FreshMate PRIVATE src/nativemedia.mm)
    set_source_files_properties(src/nativemedia.mm PROPERTIES COMPILE_FLAGS "-fobjc-arc")
else()
    target_sources(FreshMate PRIVATE src/nativemedia.cpp)
endif()

qt_add_qml_module(FreshMate
    URI FreshMate
    VERSION 1.0
    QML_FILES qml/Main.qml
    RESOURCES android/qtquickcontrols2.conf
)

target_link_libraries(FreshMate PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::QuickControls2
    Qt6::Network Qt6::Multimedia Qt6::Sql)

if(ANDROID)
set_target_properties(FreshMate PROPERTIES
    QT_ANDROID_PACKAGE_NAME         "com.freshmate.app"
    QT_ANDROID_APP_NAME             "FreshMate"
    QT_ANDROID_MIN_SDK_VERSION      28
    QT_ANDROID_TARGET_SDK_VERSION   34
    QT_ANDROID_COMPILE_SDK_VERSION  35
    QT_ANDROID_PACKAGE_SOURCE_DIR   "${CMAKE_CURRENT_SOURCE_DIR}/android"
    QT_ANDROID_ABIS                 "arm64-v8a"
    # OpenSSL 3 is NOT bundled with Qt. Without these two libs every HTTPS call
    # (Groq AI) fails on the phone even though the web version works.
    QT_ANDROID_EXTRA_LIBS
        "${CMAKE_CURRENT_SOURCE_DIR}/android/libs/arm64-v8a/libssl_3.so;${CMAKE_CURRENT_SOURCE_DIR}/android/libs/arm64-v8a/libcrypto_3.so"
)
endif()

if(IOS)
    set_target_properties(FreshMate PROPERTIES
        MACOSX_BUNDLE_GUI_IDENTIFIER        "com.freshmate.app"
        MACOSX_BUNDLE_BUNDLE_NAME           "FreshMate"
        MACOSX_BUNDLE_BUNDLE_VERSION        "1"
        MACOSX_BUNDLE_SHORT_VERSION_STRING  "${PROJECT_VERSION}"
        MACOSX_BUNDLE_INFO_PLIST            "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY        "1,2"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET    "16.0"
    )

    # Native camera / photo picker
    target_link_libraries(FreshMate PRIVATE "-framework UIKit" "-framework PhotosUI")

    # Use Apple's built-in media backend; the FFmpeg backend can't link here.
    qt_import_plugins(FreshMate
        INCLUDE Qt6::QDarwinMediaPlugin
        EXCLUDE Qt6::QFFmpegMediaPlugin
    )
endif()
