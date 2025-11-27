#import <WebKit/WebKit.h>

@interface WKWebView (BrowserHack)

-(NSDictionary*)respondToTapAndHoldAtLocation:(CGPoint)location;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
// TODO: disable night mode for now because it is unnecessary
// - (void)setEnableNightMode:(NSString *)enable;

@end
