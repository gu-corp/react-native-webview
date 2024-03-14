#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>
#import <WebKit/WebKit.h>

@protocol PassBookHelperDelegate <NSObject>
- (void)passBookdidCompleteWithError;
@end


@interface PassBookHelper : NSObject

@property (nonatomic, weak) id<PassBookHelperDelegate> delegate;

- (instancetype)initWithResponse:(NSURLResponse *)response
                     cookieStore:(WKHTTPCookieStore *)cookieStore
                  viewController: (UIViewController *)viewController;

+ (BOOL)canOpenPassBookWithResponse:(NSURLResponse *)response;

- (void)open;

+ (NSURLSession *)makeURLSessionWithUserAgent:(NSString *)userAgent;

+ (NSString *)clientUserAgentWithPrefix:(NSString *)prefix;
@end

