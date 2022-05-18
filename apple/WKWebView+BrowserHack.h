#import <WebKit/WebKit.h>

@interface WKWebView (BrowserHack)

-(NSDictionary*)respondToTapAndHoldAtLocation:(CGPoint)location;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;

@end
