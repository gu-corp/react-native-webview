#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Base64DownloadHandler : NSObject <UIPopoverPresentationControllerDelegate, UIAdaptivePresentationControllerDelegate>

- (instancetype)initWithPresenter:(UIViewController *)presenter
                       onComplete:(void (^_Nullable)(Base64DownloadHandler *handler))onComplete;

/**
 Presents an action sheet to download a data: URL (base64 only).
 Calls:
 - onProceed(): when user taps Download (navigation should be cancelled)
 - onCancel(): when user cancels/dismisses (navigation should be allowed)
 */
- (void)presentForDataURL:(NSURL *)dataURL
                 fromView:(UIView *)view
               onProceed:(void(^)(void))onProceed
                onCancel:(void(^)(void))onCancel;

@end

NS_ASSUME_NONNULL_END