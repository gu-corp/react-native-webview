#import <WebKit/WebKit.h>

@interface WKWebView (Capture)

- (void)contentScrollCapture:(void(^)(UIImage *))completionHandler;
- (void)contentFrameCapture:(void(^)(UIImage *))completionHandler;

@end
