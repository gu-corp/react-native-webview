#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BlobDownloadHandler : NSObject <WKDownloadDelegate>

- (instancetype)initWithPresenter:(UIViewController *)presenter
                       onComplete:(void (^_Nullable)(BlobDownloadHandler *handler))onComplete;

@end

NS_ASSUME_NONNULL_END
