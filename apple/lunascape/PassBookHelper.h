/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
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

