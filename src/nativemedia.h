#pragma once
#include <QObject>
#include <QString>

// Native camera + photo-library picker.
//  * iOS     : real implementation (nativemedia.mm) using UIImagePickerController
//              (camera) and PHPickerViewController (photo library). Always returns
//              an upright JPEG file path, so HEIC / rotation problems disappear.
//  * others  : stub (available == false) -> QML keeps using Qt Multimedia / FileDialog.
class NativeMedia : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
public:
    explicit NativeMedia(QObject *parent = nullptr) : QObject(parent) {}
    bool available() const;
    Q_INVOKABLE void takePhoto();
    Q_INVOKABLE void pickPhoto();

Q_SIGNALS:
    void imagePicked(const QString &path);
    void cancelled();
    void failed(const QString &message);
};
