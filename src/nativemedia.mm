// iOS native camera + photo picker.  Objective-C headers first, Qt after
// (avoids Qt keyword-macro clashes with Apple headers).
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <Foundation/Foundation.h>

#include "nativemedia.h"
#include <QGuiApplication>
#include <QWindow>
#include <QPointer>
#include <QString>

typedef void (^FMResult)(NSString *path, NSString *error);

// Redraw upright (bakes in EXIF rotation), shrink to <=1600px, save as JPEG in tmp.
static NSString *fmWriteJPEG(UIImage *img)
{
    if (!img) return nil;
    CGSize s = img.size;
    if (s.width < 1 || s.height < 1) return nil;
    CGFloat maxDim = 1600.0;
    CGFloat k = MIN(1.0, maxDim / MAX(s.width, s.height));
    CGSize ns = CGSizeMake(floor(s.width * k), floor(s.height * k));

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1.0;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:ns format:fmt];
    UIImage *norm = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [img drawInRect:CGRectMake(0, 0, ns.width, ns.height)];
    }];

    NSData *data = UIImageJPEGRepresentation(norm, 0.9);
    if (!data) return nil;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"fm_native_%@.jpg", [[NSUUID UUID] UUIDString]]];
    return [data writeToFile:path atomically:YES] ? path : nil;
}

static UIViewController *fmTopVC()
{
    UIViewController *vc = nil;
    const auto wins = QGuiApplication::topLevelWindows();
    for (QWindow *w : wins) {
        UIView *v = (__bridge UIView *)reinterpret_cast<void *>(w->winId());
        if (v && v.window.rootViewController) { vc = v.window.rootViewController; break; }
    }
    if (!vc) {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.rootViewController) { vc = w.rootViewController; break; }
        }
    }
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

@interface FMDelegate : NSObject <PHPickerViewControllerDelegate,
                                  UIImagePickerControllerDelegate,
                                  UINavigationControllerDelegate>
@property (nonatomic, copy) FMResult done;
@end

@implementation FMDelegate

- (void)finishOnMain:(NSString *)path error:(NSString *)error
{
    FMResult cb = self.done;
    dispatch_async(dispatch_get_main_queue(), ^{ if (cb) cb(path, error); });
}

// ---- photo library (PHPicker: no permission prompt needed) ----
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) { [self finishOnMain:nil error:@"cancelled"]; return; }

    NSItemProvider *p = results.firstObject.itemProvider;
    if (![p canLoadObjectOfClass:[UIImage class]]) {
        [self finishOnMain:nil error:@"This photo type is not supported."];
        return;
    }
    __weak FMDelegate *weakSelf = self;
    [p loadObjectOfClass:[UIImage class]
       completionHandler:^(__kindof id<NSItemProviderReading> obj, NSError *err) {
        UIImage *img = [obj isKindOfClass:[UIImage class]] ? (UIImage *)obj : nil;
        NSString *path = fmWriteJPEG(img);
        if (path) [weakSelf finishOnMain:path error:nil];
        else [weakSelf finishOnMain:nil error:(err ? err.localizedDescription : @"Could not read the photo.")];
    }];
}

// ---- camera (UIImagePickerController asks for camera permission itself) ----
- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info
{
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *path = fmWriteJPEG(img);
    if (path) [self finishOnMain:path error:nil];
    else [self finishOnMain:nil error:@"Could not save the photo."];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:nil];
    [self finishOnMain:nil error:@"cancelled"];
}
@end

static FMDelegate *g_delegate = nil;   // keep alive while a picker is on screen

static FMResult makeCallback(NativeMedia *nm)
{
    QPointer<NativeMedia> guard(nm);
    return ^(NSString *path, NSString *error) {
        if (!guard) return;
        if (path)
            Q_EMIT guard->imagePicked(QString::fromNSString(path));
        else if ([error isEqualToString:@"cancelled"])
            Q_EMIT guard->cancelled();
        else
            Q_EMIT guard->failed(QString::fromNSString(error ? error : @"Unknown error"));
    };
}

bool NativeMedia::available() const { return true; }

void NativeMedia::pickPhoto()
{
    UIViewController *vc = fmTopVC();
    if (!vc) { Q_EMIT failed(QStringLiteral("No window to show the picker.")); return; }

    PHPickerConfiguration *cfg = [[PHPickerConfiguration alloc] init];
    cfg.filter = [PHPickerFilter imagesFilter];
    cfg.selectionLimit = 1;

    g_delegate = [[FMDelegate alloc] init];
    g_delegate.done = makeCallback(this);

    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:cfg];
    picker.delegate = g_delegate;
    [vc presentViewController:picker animated:YES completion:nil];
}

void NativeMedia::takePhoto()
{
    UIViewController *vc = fmTopVC();
    if (!vc) { Q_EMIT failed(QStringLiteral("No window to show the camera.")); return; }
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        Q_EMIT failed(QStringLiteral("No camera available on this device."));
        return;
    }

    g_delegate = [[FMDelegate alloc] init];
    g_delegate.done = makeCallback(this);

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    picker.modalPresentationStyle = UIModalPresentationFullScreen;
    picker.delegate = g_delegate;
    [vc presentViewController:picker animated:YES completion:nil];
}
