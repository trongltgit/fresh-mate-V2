#include "nativemedia.h"

// Non-iOS builds: no native picker, QML falls back to Qt Multimedia / FileDialog.
bool NativeMedia::available() const { return false; }
void NativeMedia::takePhoto() { Q_EMIT failed(QStringLiteral("Native camera not available")); }
void NativeMedia::pickPhoto() { Q_EMIT failed(QStringLiteral("Native picker not available")); }
